import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_music_service.dart';
import 'social_service.dart';

class MusicInsightsService {
  MusicInsightsService._();

  static final MusicInsightsService instance = MusicInsightsService._();

  static const _countsKey = 'b_music02_play_counts_v1';
  static const _recentKey = 'b_music02_recent_tracks_v1';
  static const _daysKey = 'b_music02_listening_days_v1';
  static const _minutesPrefix = 'b_music02_listening_minutes_';

  final LocalMusicService _music = LocalMusicService.instance;
  final SocialService _social = SocialService.instance;

  StreamSubscription<int?>? _indexSub;
  StreamSubscription<bool>? _playingSub;
  Timer? _minuteTimer;
  Timer? _sleepTimer;
  DateTime? _sleepEndsAt;
  String? _lastRecordedId;
  DateTime? _lastRecordedAt;
  bool _initialized = false;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  DateTime? get sleepEndsAt => _sleepEndsAt;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _indexSub = _music.player.currentIndexStream.listen((_) {
      unawaited(_publishPresence());
      if (_music.player.playing) {
        unawaited(_recordCurrentTrack());
      }
    });

    _playingSub = _music.player.playingStream.listen((playing) {
      unawaited(_publishPresence());
      if (playing) {
        unawaited(_recordCurrentTrack());
        _startMinuteTimer();
      } else {
        _minuteTimer?.cancel();
        _minuteTimer = null;
      }
    });
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
    if (!_music.player.playing) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_minutesPrefix${_dayKey(DateTime.now())}';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
    _changes.add(null);
  }

  Future<void> _publishPresence() async {
    final item = currentItem;
    try {
      await _social.publishListeningPresence(
        title: item?.title,
        artist: item?.artist,
        album: item?.album,
        isPlaying: _music.player.playing && item != null,
      );
    } catch (_) {
      // Sosyal durum müzik oynatımını hiçbir zaman engellememeli.
    }
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
      'playCounts': _decodeIntMap(prefs.getString(_countsKey)),
      'recentTracks': _decodeList(prefs.getString(_recentKey)),
      'listeningDays': prefs.getStringList(_daysKey) ?? <String>[],
      'repeatMode': _music.player.loopMode.index,
      'shuffle': _music.player.shuffleModeEnabled,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> backupToCloud() async {
    await _social.backupMusic(await createBackupPayload());
  }

  Future<bool> restoreCloudInsights() async {
    final payload = await _social.restoreMusicBackup();
    if (payload == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final playCounts = payload['playCounts'];
    final recent = payload['recentTracks'];
    final days = payload['listeningDays'];

    if (playCounts is Map) {
      await prefs.setString(_countsKey, jsonEncode(playCounts));
    }
    if (recent is List) {
      await prefs.setString(_recentKey, jsonEncode(recent));
    }
    if (days is List) {
      await prefs.setStringList(
        _daysKey,
        days.map((value) => value.toString()).toList(),
      );
    }
    await _music.restoreLibraryPreferences(payload);
    _changes.add(null);
    return true;
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepEndsAt = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () async {
      _sleepEndsAt = null;
      await _music.pause();
      _changes.add(null);
    });
    _changes.add(null);
  }

  void stopAfterCurrentTrack() {
    _sleepTimer?.cancel();
    _sleepEndsAt = null;
    late final StreamSubscription subscription;
    subscription = _music.player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await subscription.cancel();
        await _music.pause();
      }
    });
    _changes.add(null);
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    _changes.add(null);
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
