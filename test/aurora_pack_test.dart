import 'dart:convert';
import 'dart:io';

import 'package:b_music02/core/services/lyrics_service.dart';
import 'package:b_music02/core/services/music_insights_service.dart';
import 'package:b_music02/core/services/rating_service.dart';
import 'package:b_music02/core/services/search_history.dart';
import 'package:b_music02/core/services/video_library.dart';
import 'package:b_music02/core/theme/aurora.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyricsService', () {
    test('parseLrc reads mm:ss and mm:ss.xx timestamps', () {
      const raw = '''[00:12.00] İlk satır
[00:15.50] İkinci satır
[01:02:03] Üçüncü
[02:01.123] Dördüncü
[00:15.50] Aynı anda
''';
      final lines = LyricsService.parseLrc(raw);
      expect(lines.length, 5);
      expect(lines.first.text, 'İlk satır');
      expect(lines.first.time, const Duration(seconds: 12));
      expect(lines[1].text, 'İkinci satır');
      expect(lines[1].time, const Duration(seconds: 15, milliseconds: 500));
      final fourth = lines.firstWhere((l) => l.text == 'Dördüncü');
      expect(fourth.time.inMilliseconds, closeTo(2 * 60 * 1000 + 1000 + 123, 20));
    });

    test('activeIndex follows playback position', () {
      final lines = [
        const LyricsLine(Duration(seconds: 0), 'a'),
        const LyricsLine(Duration(seconds: 10), 'b'),
        const LyricsLine(Duration(seconds: 20), 'c'),
      ];
      expect(LyricsService.activeIndex(lines, Duration.zero), 0);
      expect(LyricsService.activeIndex(lines, const Duration(seconds: 10)), 1);
      expect(LyricsService.activeIndex(lines, const Duration(seconds: 19)), 1);
      expect(LyricsService.activeIndex(lines, const Duration(seconds: 25)), 2);
      expect(LyricsService.activeIndex(const [], Duration.zero), -1);
    });

    test('fetches synced lyrics from LRCLIB and caches them', () async {
      final dir = Directory.systemTemp.createTempSync('lyrics-cache');
      final cache = File('${dir.path}/cache.json');
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.headers['User-Agent'], contains('BMusic'));
        expect(request.url.path, '/api/get');
        return http.Response(
            jsonEncode({
              'syncedLyrics': '[00:01.00] Merhaba\n[00:05.00] Dünya',
              'plainLyrics': 'Merhaba\nDünya',
            }),
            200);
      });
      final service = LyricsService(client: client, cacheFile: cache);
      final first = await service.fetch(
        title: 'Merhaba',
        artist: 'Sanatçı',
        duration: const Duration(seconds: 200),
      );
      expect(first.found, isTrue);
      expect(first.isSynced, isTrue);
      expect(first.synced.first.text, 'Merhaba');
      expect(first.fromCache, isFalse);
      final second = await service.fetch(
        title: 'Merhaba',
        artist: 'Sanatçı',
        duration: const Duration(seconds: 200),
      );
      expect(second.fromCache, isTrue);
      expect(second.synced.length, 2);
      expect(calls, 1);
      dir.deleteSync(recursive: true);
    });

    test('returns a graceful not-found when LRCLIB has no match', () async {
      final dir = Directory.systemTemp.createTempSync('lyrics-empty');
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/get')) {
          return http.Response('{"statusCode":404}', 404);
        }
        return http.Response('[]', 200);
      });
      final service =
          LyricsService(client: client, cacheFile: File('${dir.path}/c.json'));
      final result = await service.fetch(title: 'Bilinmeyen', artist: 'X');
      expect(result.found, isFalse);
      dir.deleteSync(recursive: true);
    });
  });

  group('SearchHistory', () {
    test('adds, moves to front, removes and clears', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = SearchHistory(prefsLoader: () async => prefs);
      await history.add('  tarkan  ');
      await history.add('Sıla');
      await history.add('tarkan');
      expect(history.items, ['tarkan', 'Sıla']);
      await history.remove('Sıla');
      expect(history.items, ['tarkan']);
      await history.clear();
      expect(history.items, isEmpty);
    });
  });

  group('VideoAccess', () {
    test('treats limited Android 14 access as allowed', () {
      final limited = mergeVideoAccess(
        photoHasAccess: true,
        photoIsAuth: false,
      );
      expect(limited.allowed, isTrue);
      expect(limited.limited, isTrue);
    });

    test('a granted videos permission overrides a stale PhotoManager denial', () {
      final access = mergeVideoAccess(
        photoHasAccess: false,
        photoIsAuth: false,
        handlerGranted: true,
      );
      expect(access.allowed, isTrue);
      expect(access.limited, isFalse);
    });

    test('handler limited access is allowed', () {
      final access = mergeVideoAccess(
        photoHasAccess: false,
        photoIsAuth: false,
        handlerLimited: true,
      );
      expect(access.allowed, isTrue);
      expect(access.limited, isTrue);
    });

    test('both denied stays denied', () {
      final access = mergeVideoAccess(
        photoHasAccess: false,
        photoIsAuth: false,
      );
      expect(access.allowed, isFalse);
    });
  });

  group('RatingService', () {
    test('prompts once after a few days and sessions, never again', () {
      final first = DateTime(2026, 11, 1);
      expect(
          RatingService.shouldPrompt(
              sessions: 2, firstUse: first, alreadyPrompted: false, now: DateTime(2026, 11, 10)),
          isFalse);
      expect(
          RatingService.shouldPrompt(
              sessions: 5, firstUse: DateTime(2026, 11, 9), alreadyPrompted: false, now: DateTime(2026, 11, 10)),
          isFalse);
      expect(
          RatingService.shouldPrompt(
              sessions: 5, firstUse: first, alreadyPrompted: false, now: DateTime(2026, 11, 10)),
          isTrue);
      expect(
          RatingService.shouldPrompt(
              sessions: 20, firstUse: first, alreadyPrompted: true, now: DateTime(2026, 11, 10)),
          isFalse);
    });
  });

  group('Aurora', () {
    test('greeting follows the time of day', () {
      expect(Aurora.greeting(DateTime(2026, 11, 12, 8)), 'Günaydın');
      expect(Aurora.greeting(DateTime(2026, 11, 12, 14)), 'İyi günler');
      expect(Aurora.greeting(DateTime(2026, 11, 12, 19)), 'İyi akşamlar');
      expect(Aurora.greeting(DateTime(2026, 11, 12, 23)), 'İyi geceler');
    });
  });

  group('forgotten tracks', () {
    test('returns songs not heard for two weeks, oldest first', () async {
      SharedPreferences.setMockInitialValues({
        'b_music02_play_counts_v1': jsonEncode({'1': 4, '2': 2, '3': 8}),
        'b_music02_last_played_v1': jsonEncode({
          '1': DateTime(2026, 8, 1).toUtc().toIso8601String(),
          '2': DateTime(2026, 11, 10).toUtc().toIso8601String(),
          '3': DateTime(2026, 6, 1).toUtc().toIso8601String(),
        }),
        'b_music02_recent_tracks_v1': jsonEncode([
          {'id': '1', 'title': 'Eski', 'artist': 'A', 'playedAt': DateTime(2026, 8, 1).toUtc().toIso8601String()},
          {'id': '2', 'title': 'Yeni', 'artist': 'B', 'playedAt': DateTime(2026, 11, 10).toUtc().toIso8601String()},
          {'id': '3', 'title': 'Daha eski', 'artist': 'C', 'playedAt': DateTime(2026, 6, 1).toUtc().toIso8601String()},
        ]),
      });
      // The service is a singleton that also talks to LocalMusicService. We
      // only exercise forgottenTracks, which is prefs-only.
      final rows = await MusicInsightsService.instance.forgottenTracks(
        now: DateTime(2026, 11, 12),
        minAge: const Duration(days: 14),
      );
      expect(rows.map((e) => e.id).toList(), ['3', '1']);
      expect(rows.first.title, 'Daha eski');
    });
  });
}
