import 'dart:convert';
import 'dart:typed_data';

import 'package:b_music02/core/services/alarm_store.dart';
import 'package:b_music02/core/services/app_update_service.dart';
import 'package:b_music02/core/services/contact_service.dart';
import 'package:b_music02/core/services/feedback_service.dart';
import 'package:b_music02/core/services/thumbnail_cache.dart';
import 'package:b_music02/core/services/video_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Öneri Kutusu', () {
    test('validates like firestore.rules', () {
      expect(FeedbackService.validate('  a '), isNotNull);
      expect(FeedbackService.validate('İyi'), isNull);
      expect(FeedbackService.validate('x' * 2001), isNotNull);
    });

    test('builds a create-only commit with a server timestamp', () {
      final body = FeedbackService().body(
          message: ' Harika uygulama ', contact: 'a@b.c', appVersion: '1.0.400',
          android: 34, device: 'Pixel 8', id: 'abc');
      final write = (body['writes'] as List).single as Map;
      expect(write['currentDocument'], {'exists': false});
      expect(write['updateTransforms'], [
        {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}
      ]);
      final update = write['update'] as Map;
      expect(update['name'], 'projects/bmusic02-app/databases/(default)/documents/feedback/abc');
      final fields = update['fields'] as Map;
      expect(fields.keys.toSet(), {'message', 'contact', 'appVersion', 'android', 'device'});
      expect(fields['message'], {'stringValue': 'Harika uygulama'});
      expect(fields['android'], {'integerValue': '34'});
    });

    test('optional fields are left out when empty', () {
      final body = FeedbackService().body(message: 'Merhaba', id: 'x');
      final fields = ((body['writes'] as List).single['update'] as Map)['fields'] as Map;
      expect(fields.keys, ['message']);
    });

    test('send posts to the Firestore REST endpoint', () async {
      late http.Request sent;
      final service = FeedbackService(client: MockClient((request) async {
        sent = request;
        return http.Response('{}', 200);
      }));
      await service.send(message: 'Karanlık tema çok güzel');
      expect(sent.url.host, 'firestore.googleapis.com');
      expect(sent.url.path, endsWith('/documents:commit'));
      expect(sent.url.queryParameters['key'], isNotEmpty);
      expect(jsonDecode(sent.body)['writes'], hasLength(1));
    });

    test('send reports failures', () async {
      final service = FeedbackService(client: MockClient((_) async => http.Response('denied', 403)));
      expect(() => service.send(message: 'Merhaba'), throwsA(isA<FeedbackException>()));
      expect(() => FeedbackService().send(message: '.'), throwsA(isA<FeedbackException>()));
    });
  });

  group('updater', () {
    test('reads the build from release tags', () {
      expect(AppUpdateService.buildOf('v1.0.512'), 512);
      expect(AppUpdateService.buildOf('1.0.7'), 7);
      expect(AppUpdateService.buildOf('v2.1.0'), isNull);
      expect(AppUpdateService.buildOf('latest'), isNull);
    });

    Map<String, dynamic> release(String tag, {bool apk = true}) => {
          'tag_name': tag,
          'body': 'Yenilikler',
          'assets': [
            if (apk)
              {
                'name': 'B_music02.apk',
                'size': 1234,
                'browser_download_url': 'https://github.com/abidinkokalp4-hash/B_music02-App/releases/download/$tag/B_music02.apk'
              }
          ],
        };

    test('only newer releases with the APK are offered', () {
      expect(AppUpdateService.parse(release('v1.0.20'), 19)?.build, 20);
      expect(AppUpdateService.parse(release('v1.0.20'), 19)?.size, 1234);
      expect(AppUpdateService.parse(release('v1.0.20'), 20), isNull);
      expect(AppUpdateService.parse(release('v1.0.21', apk: false), 19), isNull);
      expect(AppUpdateService.parse({...release('v1.0.30'), 'prerelease': true}, 19), isNull);
    });
  });

  group('alarm', () {
    test('next ring respects days and skips the current minute', () {
      final now = DateTime(2026, 10, 7, 8, 0); // Wednesday
      const weekdays = AlarmEntry(id: 1, hour: 7, minute: 30, days: {1, 2, 3, 4, 5});
      expect(weekdays.nextRing(now), DateTime(2026, 10, 8, 7, 30));
      const once = AlarmEntry(id: 2, hour: 9, minute: 15);
      expect(once.nextRing(now), DateTime(2026, 10, 7, 9, 15));
      const weekend = AlarmEntry(id: 3, hour: 10, minute: 0, days: {6, 7});
      expect(weekend.nextRing(now), DateTime(2026, 10, 10, 10, 0));
      const exact = AlarmEntry(id: 4, hour: 8, minute: 0);
      expect(exact.nextRing(now), DateTime(2026, 10, 8, 8, 0));
    });

    test('labels', () {
      expect(const AlarmEntry(id: 1, hour: 6, minute: 5).time, '06:05');
      expect(const AlarmEntry(id: 1, hour: 6, minute: 5).daysLabel, 'Bir kez');
      expect(const AlarmEntry(id: 1, hour: 6, minute: 5, days: {1, 2, 3, 4, 5, 6, 7}).daysLabel, 'Her gün');
      expect(const AlarmEntry(id: 1, hour: 6, minute: 5, days: {1, 2, 3, 4, 5}).daysLabel, 'Hafta içi');
      expect(const AlarmEntry(id: 1, hour: 6, minute: 5, days: {3, 1}).daysLabel, 'Pzt, Çar');
      final now = DateTime(2026, 10, 7, 8, 0);
      expect(AlarmEntry.untilLabel(now, DateTime(2026, 10, 7, 15, 12)), '7 saat 12 dakika sonra çalacak');
      expect(AlarmEntry.untilLabel(now, DateTime(2026, 10, 7, 8, 1)), '1 dakika sonra çalacak');
    });

    test('json round trip (shared with the native scheduler)', () {
      const alarm = AlarmEntry(id: 5, hour: 22, minute: 45, days: {7, 1}, songPath: '/m/a.mp3', songTitle: 'A', label: 'Uyu');
      final copy = AlarmEntry.fromJson(jsonDecode(jsonEncode(alarm.toJson())) as Map<String, dynamic>);
      expect(copy.toJson(), alarm.toJson());
      expect(alarm.toJson()['days'], [1, 7]);
    });

    test('store sorts and removes without Android', () async {
      final store = AlarmStore(android: false);
      await store.save(const AlarmEntry(id: 1, hour: 9, minute: 0));
      await store.save(const AlarmEntry(id: 2, hour: 6, minute: 0));
      expect(store.alarms.map((a) => a.id), [2, 1]);
      expect(store.nextId, 3);
      await store.remove(2);
      expect(store.alarms.map((a) => a.id), [1]);
    });
  });

  test('thumbnail memory cache is a bounded LRU', () {
    final cache = ThumbnailCache(maxEntries: 2, maxBytes: 1000);
    cache.put('a', Uint8List(10));
    cache.put('b', Uint8List(10));
    expect(cache.peek('a'), isNotNull); // a is now most recent
    cache.put('c', Uint8List(10));
    expect(cache.peek('b'), isNull);
    expect(cache.peek('a'), isNotNull);
    cache.put('big', Uint8List(995));
    expect(cache.memoryEntries, 1);
  });

  test('video folders come from the relative path', () {
    expect(VideoLibrary.folderOf('Movies/WhatsApp Video/'), 'WhatsApp Video');
    expect(VideoLibrary.folderOf('DCIM/Camera'), 'Camera');
    expect(VideoLibrary.folderOf(null), isNull);
    expect(VideoLibrary.folderOf('/'), isNull);
  });

  test('contact and share use the new address and the latest APK link', () {
    expect(ContactService.email, 'bmusiciletisim@gmail.com');
    final uri = ContactService.mailUri(subject: 'B Music Öneri', body: 'Merhaba dünya');
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'bmusiciletisim@gmail.com');
    expect(uri.query, contains('Merhaba%20d%C3%BCnya'));
    expect(ContactService.shareText,
        contains('https://github.com/abidinkokalp4-hash/B_music02-App/releases/latest/download/B_music02.apk'));
  });
}
