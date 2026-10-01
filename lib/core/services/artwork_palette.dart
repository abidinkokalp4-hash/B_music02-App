import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A small cached thumbnail keeps colour extraction off the playback path.
class ArtworkPalette {
  static final _cache = <Uri, Future<Color?>>{};
  static final Future<Color?> _empty = Future.value(null);

  static Future<Color?> forArtwork(Uri? uri) {
    if (uri == null || uri.scheme != 'file') return _empty;
    if (_cache.containsKey(uri)) return _cache[uri]!;
    if (_cache.length >= 48) _cache.remove(_cache.keys.first);
    return _cache[uri] = _read(uri);
  }

  static Future<Color?> _read(Uri uri) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      final bytes = await File.fromUri(uri).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 32, targetHeight: 32, allowUpscaling: false);
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data == null ? null : dominantArtworkColor(data.buffer.asUint8List());
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}

Color? dominantArtworkColor(Uint8List pixels) {
  final buckets = <int, List<int>>{};
  for (var i = 0; i + 3 < pixels.length; i += 4) {
    if (pixels[i + 3] < 200) continue;
    final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
    final high = [r, g, b].reduce((a, b) => a > b ? a : b);
    final low = [r, g, b].reduce((a, b) => a < b ? a : b);
    if (high < 35 || low > 225 || high - low < 20) continue;
    final key = ((r ~/ 32) << 6) | ((g ~/ 32) << 3) | (b ~/ 32);
    final bucket = buckets.putIfAbsent(key, () => [0, 0, 0, 0]);
    bucket[0]++;
    bucket[1] += r;
    bucket[2] += g;
    bucket[3] += b;
  }
  if (buckets.isEmpty) return null;
  final best = buckets.values.reduce((a, b) => a[0] >= b[0] ? a : b);
  return Color.fromARGB(255, best[1] ~/ best[0], best[2] ~/ best[0],
      best[3] ~/ best[0]);
}
