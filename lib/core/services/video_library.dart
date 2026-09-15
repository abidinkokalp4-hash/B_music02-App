import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

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
  Future<void> scan({bool request = false}) =>
      _pending ??= _scan(request).whenComplete(() => _pending = null);
  Future<void> _scan(bool request) async {
    loading = true;
    error = null;
    scanned = 0;
    notifyListeners();
    try {
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
        for (var page = 0; ; page++) {
          final batch = await album.getAssetListPaged(page: page, size: 200);
          for (final asset in batch) {
            assets[asset.id] = asset;
            (folders[asset.id] ??= {}).add(album.isAll ? 'Tümü' : album.name);
          }
          scanned = assets.length;
          notifyListeners();
          if (batch.length < 200) break;
        }
      }
      final result = <LocalVideo>[];
      for (final asset in assets.values) {
        int? bytes;
        // Only read metadata for local Android files; never fetch cloud videos during scanning.
        if (Platform.isAndroid) {
          try {
            final f = await asset.file;
            if (f != null) bytes = await f.length();
          } catch (_) {
            /* unavailable file */
          }
        }
        result.add(LocalVideo(asset, bytes, folders[asset.id] ?? {}));
      }
      videos = result;
    } catch (e) {
      error = 'Videolar taranamadı. İzinleri kontrol edip tekrar deneyin.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<String> get folders =>
      (videos
          .expand((v) => v.folders)
          .where((f) => f != 'Tümü')
          .toSet()
          .toList()
        ..sort());
  List<LocalVideo> filter(String query, String folder, VideoSort sort) {
    final result = videos
        .where(
          (v) =>
              v.title.toLowerCase().contains(query.toLowerCase()) &&
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
