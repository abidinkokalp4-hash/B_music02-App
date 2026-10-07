import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// Video thumbnails: memory LRU + JPEG files in cache/video_thumbs, so a
/// list scrolls without decoding the same frame again (also after restarts).
/// At most [parallel] thumbnails are decoded at the same time.
class ThumbnailCache {
  ThumbnailCache({this.maxEntries = 240, this.maxBytes = 48 << 20, this.parallel = 4});
  static final instance = ThumbnailCache();
  final int maxEntries, maxBytes, parallel;
  final _memory = LinkedHashMap<String, Uint8List>();
  final _pending = <String, Future<Uint8List?>>{};
  final _waiting = Queue<Completer<void>>();
  int _bytes = 0, _running = 0;
  Directory? _dir;

  static String keyFor(String id, int width, int height, int modified) => '${id}_${width}x${height}_$modified';

  Uint8List? peek(String key) {
    final hit = _memory.remove(key);
    if (hit != null) _memory[key] = hit; // most recently used
    return hit;
  }

  void put(String key, Uint8List bytes) {
    final old = _memory.remove(key);
    if (old != null) _bytes -= old.length;
    _memory[key] = bytes;
    _bytes += bytes.length;
    while (_memory.length > maxEntries || _bytes > maxBytes) {
      final first = _memory.keys.first;
      _bytes -= _memory.remove(first)!.length;
    }
  }

  void clearMemory() {
    _memory.clear();
    _bytes = 0;
  }

  int get memoryEntries => _memory.length;

  Future<Directory?> _directory() async {
    if (_dir != null) return _dir;
    try {
      final root = await getTemporaryDirectory();
      return _dir = await Directory('${root.path}/video_thumbs').create(recursive: true);
    } catch (_) {
      return null;
    }
  }

  Future<T> _slot<T>(Future<T> Function() task) async {
    if (_running >= parallel) {
      final ticket = Completer<void>();
      _waiting.add(ticket);
      await ticket.future;
    }
    _running++;
    try {
      return await task();
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeFirst().complete();
    }
  }

  /// Cached thumbnail of [asset] at [width]×[height].
  Future<Uint8List?> get(AssetEntity asset, {int width = 480, int height = 270}) {
    final key = keyFor(asset.id, width, height, asset.modifiedDateSecond ?? 0);
    final hit = peek(key);
    if (hit != null) return SynchronousFuture(hit);
    return _pending[key] ??= _load(asset, key, width, height).whenComplete(() => _pending.remove(key));
  }

  Future<Uint8List?> _load(AssetEntity asset, String key, int width, int height) async {
    final dir = await _directory();
    final file = dir == null ? null : File('${dir.path}/${key.replaceAll(RegExp(r'[^\w.-]'), '_')}.jpg');
    try {
      if (file != null && await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          put(key, bytes);
          return bytes;
        }
      }
    } catch (_) {}
    final bytes = await _slot(() => asset.thumbnailDataWithSize(ThumbnailSize(width, height), quality: 78));
    if (bytes == null || bytes.isEmpty) return null;
    put(key, bytes);
    if (file != null) unawaited(file.writeAsBytes(bytes, flush: false).then((_) {}, onError: (Object _) {}));
    return bytes;
  }
}
