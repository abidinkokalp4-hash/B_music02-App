import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'music_catalog.dart';

/// One timed line from an LRC file.
class LyricsLine {
  const LyricsLine(this.time, this.text);
  final Duration time;
  final String text;
}

class LyricsResult {
  const LyricsResult({
    this.plain,
    this.synced = const [],
    this.found = false,
    this.fromCache = false,
  });

  final String? plain;
  final List<LyricsLine> synced;
  final bool found;
  final bool fromCache;

  bool get isSynced => synced.isNotEmpty;
  String get displayPlain {
    if (synced.isNotEmpty) return synced.map((l) => l.text).join('\n');
    return plain ?? '';
  }

  static const notFound = LyricsResult();
}

/// Fetches lyrics from the free LRCLIB API (lrclib.net) and caches them.
class LyricsService {
  LyricsService({http.Client? client, this.cacheFile})
      : _client = client ?? http.Client();

  static final LyricsService instance = LyricsService();

  static const _endpoint = 'https://lrclib.net/api';
  static const _userAgent =
      'BMusic/1.0 (https://github.com/abidinkokalp4-hash/B_music02-App)';
  static const _maxCache = 80;

  final http.Client _client;
  final File? cacheFile;
  Map<String, dynamic>? _memory;

  static String cacheKey(String artist, String title, {int? seconds}) {
    final a = normalizeMusicSearch(artist);
    final t = normalizeMusicSearch(title);
    return seconds == null ? '$a|$t' : '$a|$t|$seconds';
  }

  /// Public LRC parser, used by the UI and by unit tests.
  static List<LyricsLine> parseLrc(String raw) {
    final stamps = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');
    final lines = <LyricsLine>[];
    for (final row in raw.split(RegExp(r'\r?\n'))) {
      final matches = stamps.allMatches(row).toList();
      if (matches.isEmpty) continue;
      final text = row.replaceAll(stamps, '').trim();
      if (text.isEmpty) continue;
      for (final m in matches) {
        final min = int.tryParse(m[1] ?? '') ?? 0;
        final sec = int.tryParse(m[2] ?? '') ?? 0;
        final frac = m[3] ?? '';
        var ms = 0;
        if (frac.isNotEmpty) {
          ms = frac.length <= 2
              ? int.parse(frac.padRight(2, '0')) * 10
              : int.parse(frac.substring(0, 3).padRight(3, '0'));
        }
        lines.add(LyricsLine(Duration(minutes: min, seconds: sec, milliseconds: ms), text));
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  /// Index of the line that should be highlighted at [position].
  static int activeIndex(List<LyricsLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    var i = 0;
    for (var n = 0; n < lines.length; n++) {
      if (lines[n].time <= position) i = n;
      else break;
    }
    return i;
  }

  Future<LyricsResult> fetch({
    required String title,
    required String artist,
    Duration? duration,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = knownMetadata(artist, '');
    if (cleanTitle.isEmpty) return LyricsResult.notFound;
    final seconds = duration == null || duration == Duration.zero
        ? null
        : duration.inSeconds;
    final key = cacheKey(cleanArtist, cleanTitle, seconds: seconds);
    final loose = cacheKey(cleanArtist, cleanTitle);
    final cached = await _read(key) ?? (seconds == null ? null : await _read(loose));
    if (cached != null) return cached;

    try {
      LyricsResult? result;
      if (seconds != null) {
        result = await _get(cleanArtist, cleanTitle, seconds);
      }
      result ??= await _search(cleanArtist, cleanTitle, seconds);
      final value = result ?? LyricsResult.notFound;
      await _write(key, value);
      if (seconds != null) await _write(loose, value);
      return value;
    } catch (_) {
      return LyricsResult.notFound;
    }
  }

  Future<LyricsResult?> _get(String artist, String title, int seconds) async {
    final uri = Uri.parse('$_endpoint/get').replace(queryParameters: {
      'artist_name': artist,
      'track_name': title,
      'duration': '$seconds',
    });
    final response = await _client.get(uri, headers: {'User-Agent': _userAgent});
    if (response.statusCode != 200) return null;
    return _decode(response.body);
  }

  Future<LyricsResult?> _search(String artist, String title, int? seconds) async {
    final uri = Uri.parse('$_endpoint/search').replace(queryParameters: {
      'track_name': title,
      if (artist.isNotEmpty) 'artist_name': artist,
    });
    final response = await _client.get(uri, headers: {'User-Agent': _userAgent});
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return null;
    Map<String, dynamic>? best;
    var bestDelta = 1 << 30;
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (seconds != null && map['duration'] != null) {
        final d = (map['duration'] is num)
            ? (map['duration'] as num).round()
            : int.tryParse('${map['duration']}') ?? 0;
        final delta = (d - seconds).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          best = map;
        }
      } else {
        best ??= map;
      }
    }
    return best == null ? null : _fromJson(best);
  }

  LyricsResult? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return _fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {}
    return null;
  }

  LyricsResult _fromJson(Map<String, dynamic> json) {
    final syncedRaw = json['syncedLyrics']?.toString();
    final plain = json['plainLyrics']?.toString();
    final synced = (syncedRaw != null && syncedRaw.trim().isNotEmpty)
        ? parseLrc(syncedRaw)
        : const <LyricsLine>[];
    final found = synced.isNotEmpty || (plain != null && plain.trim().isNotEmpty);
    return LyricsResult(plain: plain, synced: synced, found: found);
  }

  Future<File> _file() async {
    if (cacheFile != null) return cacheFile!;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/lyrics_cache_v1.json');
  }

  Future<Map<String, dynamic>> _load() async {
    if (_memory != null) return _memory!;
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _memory = Map<String, dynamic>.from(decoded);
          return _memory!;
        }
      }
    } catch (_) {}
    _memory = {};
    return _memory!;
  }

  Future<LyricsResult?> _read(String key) async {
    final all = await _load();
    final raw = all[key];
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final syncedRaw = map['synced']?.toString();
    final plain = map['plain']?.toString();
    final synced = (syncedRaw != null && syncedRaw.isNotEmpty)
        ? parseLrc(syncedRaw)
        : const <LyricsLine>[];
    final found = map['found'] == true ||
        synced.isNotEmpty ||
        (plain != null && plain.trim().isNotEmpty);
    if (!found && map['found'] == false) {
      return const LyricsResult(found: false, fromCache: true);
    }
    return LyricsResult(plain: plain, synced: synced, found: found, fromCache: true);
  }

  Future<void> _write(String key, LyricsResult result) async {
    final all = await _load();
    all[key] = {
      'plain': result.plain,
      'synced': result.synced.isEmpty
          ? null
          : result.synced
              .map((l) => '[${_ts(l.time)}]${l.text}')
              .join('\n'),
      'found': result.found,
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    if (all.length > _maxCache) {
      final entries = all.entries.toList()
        ..sort((a, b) {
          final at = (a.value is Map) ? (a.value['at'] ?? '') : '';
          final bt = (b.value is Map) ? (b.value['at'] ?? '') : '';
          return at.toString().compareTo(bt.toString());
        });
      for (final e in entries.take(all.length - _maxCache)) {
        all.remove(e.key);
      }
    }
    _memory = all;
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(all));
    } catch (_) {}
  }

  static String _ts(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = ((d.inMilliseconds.remainder(1000)) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }
}
