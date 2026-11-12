import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';

import 'local_music_service.dart';
import 'sleep_timer.dart';

class MusicInsightsService {
  MusicInsightsService._();

  static final MusicInsightsService instance = MusicInsightsService._();

  static const _countsKey = 'b_music02_play_counts_v1';
  static const _recentKey = 'b_music02_recent_tracks_v1';
  static const _daysKey = 'b_music02_listening_days_v1';
  static const _minutesPrefix = 'b_music02_listening_minutes_';
  static const _lastPlayedKey = 'b_music02_last_played_v1';

  final LocalMusicService _music = LocalMusicService.instance;

  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlayerState>? _playingSub;
  Timer? _minuteTimer;
  late final SleepTimer sleepTimer = SleepTimer(
    player: _music.player,
    pause: _music.pause,
    onChange: () => _changes.add(null),
  );
  String? _lastRecordedId;
  DateTime? _lastRecordedAt;
  bool _initialized = false;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  DateTime? get sleepEndsAt => sleepTimer.endsAt;
  bool get stopsAfterTrack => sleepTimer.afterTrack;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _indexSub = _music.player.currentIndexStream.listen((_) {
      if (_music.player.playing) {
        unawaited(_recordCurrentTrack());
      }
    });

    _playingSub = _music.player.playerStateStream.listen((state) {
      if (state.playing && state.processingState == ProcessingState.ready) {
        unawaited(_recordCurrentTrack());
        _startMinuteTimer();
      } else {
        _minuteTimer?.cancel();
        _minuteTimer = null;
      }
    });
  }

  Future<void> dispose() async {
    await _indexSub?.cancel();
    await _playingSub?.cancel();
    _minuteTimer?.cancel();
    sleepTimer.cancel(notify: false);
    _initialized = false;
  }

  void _startMinuteTimer() {
    _minuteTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_incrementListeningMinute());
    });
  }

  MediaItem? get currentItem {
    final source = _music.player.sequenceState.currentSource;
    final tag = source?.tag;
    return tag is MediaItem ? tag : null;
  }

  Future<void> _recordCurrentTrack() async {
    final item = currentItem;
    if (item == null) return;

    final now = DateTime.now();
    if (_lastRecordedId == item.id &&
        _lastRecordedAt != null &&
        now.difference(_lastRecordedAt!) < const Duration(minutes: 2)) {
      return;
    }

    _lastRecordedId = item.id;
    _lastRecordedAt = now;

    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeIntMap(prefs.getString(_countsKey));
    counts[item.id] = (counts[item.id] ?? 0) + 1;
    await prefs.setString(_countsKey, jsonEncode(counts));

    final recent = _decodeList(prefs.getString(_recentKey));
    recent.removeWhere((entry) => entry['id']?.toString() == item.id);
    recent.insert(0, {
      'id': item.id,
      'title': item.title,
      'artist': item.artist,
      'album': item.album,
      'artUri': item.artUri?.toString(),
      'playedAt': now.toUtc().toIso8601String(),
    });
    if (recent.length > 40) recent.removeRange(40, recent.length);
    await prefs.setString(_recentKey, jsonEncode(recent));

    final lastPlayed = _decodeStringMap(prefs.getString(_lastPlayedKey));
    lastPlayed[item.id] = now.toUtc().toIso8601String();
    await prefs.setString(_lastPlayedKey, jsonEncode(lastPlayed));

    final dayKey = _dayKey(now);
    final days = (prefs.getStringList(_daysKey) ?? <String>[]).toSet();
    days.add(dayKey);
    final orderedDays = days.toList()..sort();
    if (orderedDays.length > 120) {
      orderedDays.removeRange(0, orderedDays.length - 120);
    }
    await prefs.setStringList(_daysKey, orderedDays);
    _changes.add(null);
  }

  Future<void> _incrementListeningMinute() async {
    if (!_music.player.playing ||
        _music.player.processingState != ProcessingState.ready) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_minutesPrefix${_dayKey(DateTime.now())}';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
    _changes.add(null);
  }

  Future<List<TrackInsight>> topTracks({int limit = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeIntMap(prefs.getString(_countsKey));
    final recent = _decodeList(prefs.getString(_recentKey));
    final metadata = <String, Map<String, dynamic>>{
      for (final row in recent) row['id'].toString(): row,
    };

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).map((entry) {
      final row = metadata[entry.key] ?? const <String, dynamic>{};
      return TrackInsight(
        id: entry.key,
        title: row['title']?.toString() ?? 'Müzik',
        artist: row['artist']?.toString() ?? 'Bilinmeyen sanatçı',
        album: row['album']?.toString(),
        plays: entry.value,
        playedAt: DateTime.tryParse(row['playedAt']?.toString() ?? ''),
      );
    }).toList();
  }

  Future<List<TrackInsight>> recentTracks({int limit = 12}) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = _decodeList(prefs.getString(_recentKey));
    final counts = _decodeIntMap(prefs.getString(_countsKey));

    return recent.take(limit).map((row) {
      final id = row['id']?.toString() ?? '';
      return TrackInsight(
        id: id,
        title: row['title']?.toString() ?? 'Müzik',
        artist: row['artist']?.toString() ?? 'Bilinmeyen sanatçı',
        album: row['album']?.toString(),
        plays: counts[id] ?? 0,
        playedAt: DateTime.tryParse(row['playedAt']?.toString() ?? ''),
      );
    }).toList();
  }

  Future<int> todayMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_minutesPrefix${_dayKey(DateTime.now())}') ?? 0;
  }

  Future<int> currentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final days = (prefs.getStringList(_daysKey) ?? <String>[]).toSet();
    var cursor = DateTime.now();
    var streak = 0;

    if (!days.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    while (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<Map<String, dynamic>> createBackupPayload() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'favorites': _music.favoriteIds.toList(),
      'playlists': _music.playlists.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'pinnedPlaylists': _music.pinnedPlaylistNames,
      'playCounts': _decodeIntMap(prefs.getString(_countsKey)),
      'recentTracks': _decodeList(prefs.getString(_recentKey)),
      'lastPlayed': _decodeStringMap(prefs.getString(_lastPlayedKey)),
      'listeningDays': prefs.getStringList(_daysKey) ?? <String>[],
      'repeatMode': _music.player.loopMode.index,
      'shuffle': _music.player.shuffleModeEnabled,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> backupToCloud() async {
    throw UnsupportedError('Bu sürümde bulut hesabı kullanılmıyor.');
  }

  Future<bool> restoreCloudInsights() async {
    return false;
  }

  void startSleepTimer(Duration duration) => sleepTimer.start(duration);

  void stopAfterCurrentTrack() => sleepTimer.stopAfterTrack();

  void cancelSleepTimer() => sleepTimer.cancel();


  /// Songs that were played at least once but not for [minAge] (default 14 days).
  /// Tracks that fell off the recent list and have no last-played stamp are
  /// also included — they have not been heard recently by definition.
  Future<List<TrackInsight>> forgottenTracks({
    int limit = 40,
    Duration minAge = const Duration(days: 14),
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeIntMap(prefs.getString(_countsKey));
    final recent = _decodeList(prefs.getString(_recentKey));
    final lastPlayedRaw = _decodeStringMap(prefs.getString(_lastPlayedKey));
    final metadata = <String, Map<String, dynamic>>{
      for (final row in recent) row['id'].toString(): row,
    };
    final lastPlayed = <String, DateTime>{};
    for (final e in lastPlayedRaw.entries) {
      final at = DateTime.tryParse(e.value);
      if (at != null) lastPlayed[e.key] = at.toLocal();
    }
    for (final row in recent) {
      final id = row['id']?.toString() ?? '';
      lastPlayed[id] ??= DateTime.tryParse(row['playedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    final cutoff = (now ?? DateTime.now()).subtract(minAge);
    final ids = {...counts.keys, ...lastPlayed.keys};
    final rows = <TrackInsight>[];
    for (final id in ids) {
      final last = lastPlayed[id];
      final plays = counts[id] ?? 0;
      if (plays <= 0 && last == null) continue;
      final forgotten = last == null || last.isBefore(cutoff);
      if (!forgotten) continue;
      final row = metadata[id] ?? const <String, dynamic>{};
      rows.add(TrackInsight(
        id: id,
        title: row['title']?.toString() ?? 'Müzik',
        artist: row['artist']?.toString() ?? 'Bilinmeyen sanatçı',
        album: row['album']?.toString(),
        plays: plays,
        playedAt: last,
      ));
    }
    rows.sort((a, b) {
      if (a.playedAt == null && b.playedAt == null) return b.plays.compareTo(a.plays);
      if (a.playedAt == null) return 1;
      if (b.playedAt == null) return -1;
      return a.playedAt!.compareTo(b.playedAt!);
    });
    return rows.take(limit).toList();
  }

  Map<String, int> _decodeIntMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map<String, int>((key, value) {
        return MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0);
      });
    } catch (_) {
      return <String, int>{};
    }
  }


  Map<String, String> _decodeStringMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map<String, String>((key, value) =>
          MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  String _dayKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class TrackInsight {
  const TrackInsight({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.plays,
    required this.playedAt,
  });

  final String id;
  final String title;
  final String artist;
  final String? album;
  final int plays;
  final DateTime? playedAt;
}
