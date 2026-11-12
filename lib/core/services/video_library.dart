import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'music_catalog.dart';
import 'video_preferences.dart';

enum VideoSort { newest, oldest, az, za, largest, smallest, longest, shortest }

const videoSortLabels = [
  'Yeni → Eski',
  'Eski → Yeni',
  'A → Z',
  'Z → A',
  'En Büyük Boyut',
  'En Küçük Boyut',
  'En Uzun Süre',
  'En Kısa Süre',
];

class LocalVideo {
  LocalVideo(this.asset, this.bytes, this.folders, {this.cachedTitle, this.cachedDuration, this.cachedCreated});
  final AssetEntity asset;
  final int? bytes;
  final Set<String> folders;
  final String? cachedTitle;
  final int? cachedDuration;
  final DateTime? cachedCreated;
  String get title => cachedTitle ?? asset.title ?? 'Video';
}


/// Combined PhotoManager + Android 13+ READ_MEDIA_VIDEO / Android 14+
/// limited-access state. A "yes" from either source is enough to treat
/// the archive as reachable — PhotoManager's getPermissionState can
/// briefly report denied after a grant, which used to flash the
/// "Video erişimine izin ver" screen again.
class VideoAccess {
  const VideoAccess({required this.allowed, required this.limited});
  final bool allowed;
  final bool limited;
}

VideoAccess mergeVideoAccess({
  required bool photoHasAccess,
  required bool photoIsAuth,
  bool? handlerGranted,
  bool? handlerLimited,
}) {
  var allowed = photoHasAccess;
  var limited = photoHasAccess && !photoIsAuth;
  if (handlerGranted == true) {
    allowed = true;
    if (handlerLimited == true) limited = true;
  } else if (handlerLimited == true) {
    allowed = true;
    limited = true;
  }
  return VideoAccess(allowed: allowed, limited: limited);
}

class VideoLibrary extends ChangeNotifier {
  static final instance = VideoLibrary();
  static const permission = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.video,
      mediaLocation: false,
    ),
    iosAccessLevel: IosAccessLevel.readWrite,
  );
  static const _cacheName = 'video_library_cache_v1.json';
  List<LocalVideo> videos = [];
  bool loading = false, allowed = false, limited = false;
  String? error;
  int scanned = 0;
  Future<void>? _pending;
  DateTime? _lastScan;
  Timer? _changeDebounce;
  bool _watching = false;
  bool _cacheHydrated = false;

  /// True once the device archive was read in this app session.
  bool get hasScanned => _lastScan != null;

  /// Reads the device archive once per app session. Later calls reuse the
  /// cached list; [force] or a permission [request] performs a full rescan.
  /// Disk cache makes the first open after a cold start feel instant.
  Future<void> scan({bool request = false, bool force = false}) {
    if (!request && !force && _lastScan != null) return Future.value();
    return _pending ??= _scan(request, force: force).whenComplete(() => _pending = null);
  }

  /// Adds only videos that arrived after the last scan.
  Future<void> refreshNew() {
    if (_lastScan == null || !allowed) return Future.value();
    return _pending ??= _incremental().whenComplete(() => _pending = null);
  }

  void _startWatching() {
    if (_watching) return;
    _watching = true;
    try {
      PhotoManager.addChangeCallback(_mediaChanged);
      unawaited(PhotoManager.startChangeNotify().catchError((_) {}));
    } catch (_) {/* Change notifications are an optimisation only. */}
  }

  void _mediaChanged(MethodCall _) {
    _changeDebounce?.cancel();
    _changeDebounce =
        Timer(const Duration(seconds: 2), () => unawaited(refreshNew()));
  }

  Future<File?> _cacheFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$_cacheName');
    } catch (_) {
      return null;
    }
  }

  Future<void> _hydrateFromDisk() async {
    if (_cacheHydrated || videos.isNotEmpty) return;
    _cacheHydrated = true;
    try {
      final file = await _cacheFile();
      if (file == null || !await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      final items = raw['items'];
      if (items is! List || items.isEmpty) return;
      final restored = <LocalVideo>[];
      for (final item in items) {
        if (item is! Map) continue;
        final id = item['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final entity = await AssetEntity.fromId(id);
        if (entity == null) continue;
        final folders = ((item['folders'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet();
        if (folders.isEmpty) folders.add('Tümü');
        restored.add(LocalVideo(
          entity,
          (item['bytes'] as num?)?.toInt(),
          folders,
          cachedTitle: item['title']?.toString(),
          cachedDuration: (item['duration'] as num?)?.toInt(),
          cachedCreated: item['created'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  (item['created'] as num).toInt()),
        ));
      }
      if (restored.isEmpty) return;
      videos = restored;
      allowed = true;
      _lastScan = DateTime.fromMillisecondsSinceEpoch(
          (raw['scannedAt'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch);
      notifyListeners();
    } catch (_) {/* Corrupt cache: fall through to a live scan. */}
  }

  Future<void> _persist() async {
    try {
      final file = await _cacheFile();
      if (file == null) return;
      final items = [
        for (final v in videos)
          {
            'id': v.asset.id,
            'title': v.title,
            'bytes': v.bytes,
            'duration': v.cachedDuration ?? v.asset.duration,
            'created':
                (v.cachedCreated ?? v.asset.createDateTime).millisecondsSinceEpoch,
            'folders': v.folders.toList(),
          }
      ];
      await file.writeAsString(jsonEncode({
        'scannedAt': (_lastScan ?? DateTime.now()).millisecondsSinceEpoch,
        'items': items,
      }));
    } catch (_) {/* Cache is optional. */}
  }

  Future<void> _incremental() async {
    final now = DateTime.now();
    final since = _lastScan!.subtract(const Duration(seconds: 10));
    try {
      final total = await PhotoManager.getAssetCount(type: RequestType.video);
      final known = {for (final v in videos) v.asset.id};
      final added = <String, AssetEntity>{};
      final folders = <String, Set<String>>{};
      if (total > known.length) {
        final albums = await PhotoManager.getAssetPathList(
          type: RequestType.video,
          filterOption: FilterOptionGroup(
            createTimeCond: DateTimeCond(
                min: since, max: now.add(const Duration(minutes: 5))),
          ),
        );
        for (final album in albums) {
          for (var page = 0;; page++) {
            final batch = await album.getAssetListPaged(page: page, size: 200);
            for (final asset in batch) {
              if (known.contains(asset.id)) continue;
              added[asset.id] = asset;
              (folders[asset.id] ??= {}).add(album.isAll ? 'Tümü' : album.name);
            }
            if (batch.length < 200) break;
          }
        }
      }
      // Prefer pruning missing ids over a full rescan when the count drops.
      if (total < known.length) {
        final still = <LocalVideo>[];
        for (final v in videos) {
          final live = await AssetEntity.fromId(v.asset.id);
          if (live != null) still.add(v);
        }
        if (still.length != videos.length) {
          videos = still;
          _lastScan = now;
          await VideoPreferences.instance
              .observeLibrary(videos.map((v) => v.asset.id).toSet());
          notifyListeners();
          unawaited(_persist());
        }
        return;
      }
      if (total > known.length + added.length && added.isEmpty) {
        // Could not explain the growth from the date filter — one full rescan.
        await _scan(false, force: true);
        return;
      }
      _lastScan = now;
      if (added.isEmpty) {
        unawaited(_persist());
        return;
      }
      final fresh = added.values
          .map((a) => LocalVideo(a, null, folders[a.id] ?? {'Tümü'}))
          .toList()
        ..sort(
            (a, b) => b.asset.createDateTime.compareTo(a.asset.createDateTime));
      videos = [...fresh, ...videos];
      await VideoPreferences.instance
          .observeLibrary(videos.map((v) => v.asset.id).toSet());
      notifyListeners();
      unawaited(_persist());
      await _loadSizes();
    } catch (_) {/* Keep the cached list; the refresh button still rescans. */}
  }

  Future<void> _loadSizes() async {
    if (!Platform.isAndroid) return;
    try {
      final sizes = await const MethodChannel('b_music02/device')
          .invokeMapMethod<String, dynamic>('videoSizes');
      if (sizes != null) {
        videos = videos
            .map((v) => LocalVideo(v.asset,
                (sizes[v.asset.id] as num?)?.toInt() ?? v.bytes, v.folders,
                cachedTitle: v.cachedTitle,
                cachedDuration: v.cachedDuration,
                cachedCreated: v.cachedCreated))
            .toList();
        notifyListeners();
        unawaited(_persist());
      }
    } catch (_) {/* Size metadata is optional and must not block browsing. */}
  }

  Future<void> _scan(bool request, {bool force = false}) async {
    await _hydrateFromDisk();
    // After a warm cache hit, skip the full archive walk unless forced.
    if (!request && !force && _lastScan != null && videos.isNotEmpty) {
      _startWatching();
      unawaited(refreshNew());
      return;
    }
    loading = videos.isEmpty; // Keep showing cached rows while refreshing.
    error = null;
    scanned = 0;
    notifyListeners();
    try {
      await VideoPreferences.instance.load();
      final access = await resolveAccess(request: request);
      limited = access.limited;
      allowed = access.allowed;
      if (!allowed) {
        // Keep any hydrated cache visible; the permission button still shows
        // because [allowed] is false. Clearing here made a stale "denied"
        // reading look like an empty library.
        return;
      }
      final started = DateTime.now();
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );
      final assets = <String, AssetEntity>{};
      final folders = <String, Set<String>>{};
      var needAlbums = false;
      if (albums.isNotEmpty) {
        final all = albums.first;
        for (var page = 0;; page++) {
          final batch = await all.getAssetListPaged(page: page, size: page == 0 ? 60 : 400);
          for (final asset in batch) {
            assets[asset.id] = asset;
            final folder = folderOf(asset.relativePath);
            if (folder == null) needAlbums = true;
            folders[asset.id] = {'Tümü', if (folder != null) folder};
          }
          scanned = assets.length;
          videos = assets.values.map((a) => LocalVideo(a, null, folders[a.id] ?? {})).toList();
          notifyListeners();
          if (batch.length < (page == 0 ? 60 : 400)) break;
        }
      }
      if (needAlbums) {
        for (final album in await PhotoManager.getAssetPathList(type: RequestType.video)) {
          if (album.isAll) continue;
          for (var page = 0;; page++) {
            final batch = await album.getAssetListPaged(page: page, size: 400);
            for (final asset in batch) {
              (folders[asset.id] ??= {'Tümü'}).add(album.name);
            }
            if (batch.length < 400) break;
          }
        }
      }
      videos = assets.values.map((a) => LocalVideo(a, null, folders[a.id] ?? {})).toList();
      await VideoPreferences.instance.observeLibrary(assets.keys.toSet());
      _lastScan = started;
      notifyListeners();
      _startWatching();
      unawaited(_persist());
      await _loadSizes();
    } catch (e) {
      error = 'Videolar taranamadı. İzinleri kontrol edip tekrar deneyin.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }


  /// PhotoManager plus the Android 13+ videos permission, used on every
  /// scan and when the app is resumed.
  Future<VideoAccess> resolveAccess({required bool request}) async {
    PermissionState? state;
    try {
      state = request
          ? await PhotoManager.requestPermissionExtend(requestOption: permission)
          : await PhotoManager.getPermissionState(requestOption: permission);
    } catch (_) {/* PhotoManager can throw if the plugin is not ready. */}

    bool? granted, limitedHandler;
    if (Platform.isAndroid) {
      try {
        final status = request
            ? await Permission.videos.request()
            : await Permission.videos.status;
        granted = status.isGranted;
        limitedHandler = status.isLimited;
      } catch (_) {/* permission_handler is a cross-check, not required. */}
    }

    var access = mergeVideoAccess(
      photoHasAccess: state?.hasAccess ?? false,
      photoIsAuth: state?.isAuth ?? false,
      handlerGranted: granted,
      handlerLimited: limitedHandler,
    );

    // Handler says we already have access but PhotoManager's cached state
    // is stale: a silent requestPermissionExtend refreshes it and does not
    // prompt again when the OS grant is already present.
    if (access.allowed && (state == null || !state.hasAccess)) {
      try {
        final synced = await PhotoManager.requestPermissionExtend(
          requestOption: permission,
        );
        access = mergeVideoAccess(
          photoHasAccess: synced.hasAccess,
          photoIsAuth: synced.isAuth,
          handlerGranted: granted,
          handlerLimited: limitedHandler,
        );
      } catch (_) {}
    }
    return access;
  }

  /// Re-reads permission on resume so a grant made in system settings is
  /// picked up, and a limited (Android 14+) grant is treated as access.
  Future<void> recheckAccess() async {
    final access = await resolveAccess(request: false);
    final wasAllowed = allowed;
    allowed = access.allowed;
    limited = access.limited;
    if (allowed && (!wasAllowed || videos.isEmpty || _lastScan == null)) {
      await scan(request: false, force: videos.isEmpty || _lastScan == null);
    } else {
      notifyListeners();
      if (allowed) unawaited(refreshNew());
    }
  }

  /// "Movies/WhatsApp Video/" → "WhatsApp Video" (Android's album name).
  static String? folderOf(String? relativePath) {
    if (relativePath == null) return null;
    final parts = relativePath.split('/').where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.last;
  }

  Map<String, int> get folderCounts {
    final counts = <String, int>{};
    for (final video in videos) {
      for (final folder in video.folders) {
        if (folder != 'Tümü') counts[folder] = (counts[folder] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<String> get folders => (videos
      .expand((v) => v.folders)
      .where((f) => f != 'Tümü')
      .toSet()
      .toList()
    ..sort());
  List<LocalVideo> filter(String query, String folder, VideoSort sort) {
    final result = videos
        .where(
          (v) =>
              normalizeMusicSearch(v.title)
                  .contains(normalizeMusicSearch(query)) &&
              (folder == 'Tümü' || v.folders.contains(folder)),
        )
        .toList();
    result.sort((a, b) {
      final aCreated = a.cachedCreated ?? a.asset.createDateTime;
      final bCreated = b.cachedCreated ?? b.asset.createDateTime;
      final aDur = a.cachedDuration ?? a.asset.duration;
      final bDur = b.cachedDuration ?? b.asset.duration;
      final compared = switch (sort) {
        VideoSort.newest => bCreated.compareTo(aCreated),
        VideoSort.oldest => aCreated.compareTo(bCreated),
        VideoSort.az => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        VideoSort.za => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        VideoSort.largest => (b.bytes ?? -1).compareTo(a.bytes ?? -1),
        VideoSort.smallest => (a.bytes ?? 0x7fffffffffffffff).compareTo(
            b.bytes ?? 0x7fffffffffffffff,
          ),
        VideoSort.longest => bDur.compareTo(aDur),
        VideoSort.shortest => aDur.compareTo(bDur),
      };
      return compared == 0 ? a.asset.id.compareTo(b.asset.id) : compared;
    });
    return result;
  }
}
