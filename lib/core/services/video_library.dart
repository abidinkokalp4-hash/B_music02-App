
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
  LocalVideo(this.asset, this.bytes, this.folders);
  final AssetEntity asset;
  final int? bytes;
  final Set<String> folders;
  String get title => asset.title ?? 'Video';
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
  List<LocalVideo> videos = [];
  bool loading = false, allowed = false, limited = false;
  String? error;
  int scanned = 0;
  Future<void>? _pending;
  DateTime? _lastScan;
  Future<void> scan({bool request = false, bool force = false}) {
    if (!request && !force && _lastScan != null &&
        DateTime.now().difference(_lastScan!) < const Duration(seconds: 30)) {
      return Future.value();
    }
    return _pending ??= _scan(request).whenComplete(() => _pending = null);
  }
  Future<void> _scan(bool request) async {
    loading = true;
    error = null;
    scanned = 0;
    notifyListeners();
    try {
      await VideoPreferences.instance.load();
      final state = request
          ? await PhotoManager.requestPermissionExtend(
              requestOption: permission,
            )
          : await PhotoManager.getPermissionState(requestOption: permission);
      limited = state.hasAccess && !state.isAuth;
      allowed = state.hasAccess;
      if (!allowed) {
        videos = [];
        return;
      }
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );
      final assets = <String, AssetEntity>{};
      final folders = <String, Set<String>>{};
      for (final album in albums) {
        for (var page = 0;; page++) {
          final batch = await album.getAssetListPaged(page: page, size: 200);
          for (final asset in batch) {
            assets[asset.id] = asset;
            (folders[asset.id] ??= {}).add(album.isAll ? 'Tümü' : album.name);
          }
          scanned = assets.length;
          videos = assets.values.map((a) => LocalVideo(a, null, folders[a.id] ?? {})).toList();
          // Publish each page immediately; file access belongs to opening a video.
          notifyListeners();
          if (batch.length < 200) break;
        }
      }
      videos = assets.values.map((a) => LocalVideo(a, null, folders[a.id] ?? {})).toList();
      await VideoPreferences.instance.observeLibrary(assets.keys.toSet());
      _lastScan = DateTime.now();
      notifyListeners();
      if (Platform.isAndroid) {
        try {
          final sizes = await const MethodChannel('b_music02/device').invokeMapMethod<String, dynamic>('videoSizes');
          if (sizes != null) videos = videos.map((v) => LocalVideo(v.asset, (sizes[v.asset.id] as num?)?.toInt(), v.folders)).toList();
        } catch (_) { /* Size metadata is optional and must not block browsing. */ }
      }
    } catch (e) {
      error = 'Videolar taranamadı. İzinleri kontrol edip tekrar deneyin.';
    } finally {
      loading = false;
      notifyListeners();
    }
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
      final compared = switch (sort) {
        VideoSort.newest => b.asset.createDateTime.compareTo(
            a.asset.createDateTime,
          ),
        VideoSort.oldest => a.asset.createDateTime.compareTo(
            b.asset.createDateTime,
          ),
        VideoSort.az => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        VideoSort.za => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        VideoSort.largest => (b.bytes ?? -1).compareTo(a.bytes ?? -1),
        VideoSort.smallest => (a.bytes ?? 0x7fffffffffffffff).compareTo(
            b.bytes ?? 0x7fffffffffffffff,
          ),
        VideoSort.longest => b.asset.duration.compareTo(a.asset.duration),
        VideoSort.shortest => a.asset.duration.compareTo(b.asset.duration),
      };
      return compared == 0 ? a.asset.id.compareTo(b.asset.id) : compared;
    });
    return result;
  }
}
