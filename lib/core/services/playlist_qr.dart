import 'dart:convert';
import 'dart:io' show gzip;

import 'package:on_audio_query/on_audio_query.dart';

import 'music_catalog.dart';

/// QR ile liste paylaşımı. The QR holds a web link whose fragment is the
/// gzip+base64url playlist ({"v":1,"n":name,"s":[[title,artist],...]}), so a
/// normal camera app opens the web page and B Music's "QR okut" imports it.
class PlaylistQr {
  static const host = 'https://bmusic02-app.web.app';
  static const maxSongs = 30;

  static String _cut(String s, int max) => s.length > max ? s.substring(0, max) : s;

  static String encode(String name, List<SongModel> songs) {
    final payload = {
      'v': 1,
      'n': _cut(name.trim(), 40),
      's': [
        for (final song in songs.take(maxSongs))
          [
            _cut(song.title.trim(), 48),
            _cut(knownMetadata(song.artist, ''), 32),
          ]
      ],
    };
    final data = base64Url
        .encode(gzip.encode(utf8.encode(jsonEncode(payload))))
        .replaceAll('=', '');
    return '$host/l#$data';
  }

  /// Accepts the web link (fragment), bmusic://liste?d=... or the raw data.
  static SharedPlaylist? decode(String raw) {
    try {
      var data = raw.trim();
      final uri = Uri.tryParse(data);
      if (uri != null && uri.hasScheme) {
        if (uri.queryParameters['d'] != null) {
          data = uri.queryParameters['d']!;
        } else if (uri.fragment.isNotEmpty) {
          data = uri.fragment;
        } else {
          return null;
        }
      }
      final padded = data.padRight((data.length + 3) ~/ 4 * 4, '=');
      final json = jsonDecode(utf8.decode(gzip.decode(base64Url.decode(padded))));
      if (json is! Map || json['s'] is! List) return null;
      final songs = <(String, String)>[
        for (final row in json['s'] as List)
          if (row is List && row.isNotEmpty && row[0] is String)
            (row[0] as String, row.length > 1 && row[1] is String ? row[1] as String : '')
      ];
      final name = (json['n'] is String && (json['n'] as String).trim().isNotEmpty)
          ? (json['n'] as String).trim()
          : 'QR listesi';
      return SharedPlaylist(name, songs);
    } catch (_) {
      return null;
    }
  }

  static String _key(String s) =>
      normalizeMusicSearch(s).replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Finds the shared songs in the local library (title, preferring artist).
  static List<SongModel> match(SharedPlaylist list, List<SongModel> library) {
    final byTitle = <String, List<SongModel>>{};
    for (final song in library) {
      byTitle.putIfAbsent(_key(song.title), () => []).add(song);
    }
    final found = <SongModel>[];
    for (final (title, artist) in list.songs) {
      final candidates = byTitle[_key(title)];
      if (candidates == null || candidates.isEmpty) continue;
      final a = _key(artist);
      final best = candidates.firstWhere(
          (s) => a.isNotEmpty && _key(knownMetadata(s.artist, '')) == a,
          orElse: () => candidates.first);
      if (!found.contains(best)) found.add(best);
    }
    return found;
  }

  static String uniqueName(String name, Iterable<String> existing) {
    final taken = existing.toSet();
    if (!taken.contains(name)) return name;
    for (var i = 2;; i++) {
      final candidate = '$name ($i)';
      if (!taken.contains(candidate)) return candidate;
    }
  }
}

class SharedPlaylist {
  const SharedPlaylist(this.name, this.songs);
  final String name;
  final List<(String, String)> songs;
}
