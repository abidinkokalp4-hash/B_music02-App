import 'dart:async';

import 'package:b_music02/core/services/announcements.dart';
import 'package:b_music02/core/services/push_notifications.dart';
import 'package:b_music02/features/profile/announcements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const polled = '''{"announcements":[
  {"id":"shared","title":"Dosyadaki başlık","body":"announcements.json","createdAt":"2026-10-07T09:00:00Z"},
  {"id":"old","title":"Eski","createdAt":"2026-01-01T00:00:00Z"}
]}''';
const pushed = '''{"announcements":[
  {"id":"shared","title":"Push başlığı","body":"FCM","createdAt":"2026-10-07T09:00:00Z"},
  {"id":"push-only","title":"Anlık duyuru","body":"Sadece push ile geldi","url":"https://example.com/a","createdAt":"2026-10-07T12:00:00Z"}
]}''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Announcement.fromPush', () {
    test('reads id/title/body/url from the data payload', () {
      final item = Announcement.fromPush({
        'id': ' 2026-10-07-2 ',
        'title': 'Yeni sürüm',
        'body': 'Güncelleme hazır',
        'url': 'https://github.com/abidinkokalp4-hash/B_music02-App/releases/latest',
        'createdAt': '2026-10-07T10:00:00+03:00',
      })!;
      expect(item.id, '2026-10-07-2');
      expect(item.title, 'Yeni sürüm');
      expect(item.body, 'Güncelleme hazır');
      expect(item.url, startsWith('https://github.com/'));
      expect(item.createdAt, DateTime.utc(2026, 10, 7, 7));
    });

    test('falls back to the notification payload, message id and sent time', () {
      final sent = DateTime.utc(2026, 10, 7, 20, 30);
      final item = Announcement.fromPush({},
          title: 'Konsoldan', body: 'Firebase konsolu', messageId: '0:123', sentTime: sent)!;
      expect(item.id, 'fcm-0:123');
      expect(item.title, 'Konsoldan');
      expect(item.body, 'Firebase konsolu');
      expect(item.createdAt, sent);
      // Data wins over the notification payload.
      expect(Announcement.fromPush({'id': 'x', 'title': 'Veri'}, title: 'Bildirim')!.title, 'Veri');
    });

    test('rejects messages without id or title and non-https links', () {
      expect(Announcement.fromPush({'title': 'Kimliksiz'}), isNull);
      expect(Announcement.fromPush({'id': 'a'}), isNull);
      expect(Announcement.fromPush({'id': 'a', 'title': '   '}), isNull);
      expect(Announcement.fromPush({'id': 'a', 'title': 't', 'url': 'http://x.com'})!.url, isNull);
      expect(Announcement.fromPush({'id': 'a', 'title': 't', 'url': 'javascript:alert(1)'})!.url, isNull);
    });

    test('limits sizes like the announcements.json parser', () {
      final item = Announcement.fromPush(
          {'id': 'i' * 300, 'title': 't' * 300, 'body': 'b' * 3000})!;
      expect(item.id.length, 200);
      expect(item.title.length, 120);
      expect(item.body.length, 1000);
    });
  });

  test('merge keeps one entry per id, file copy wins, newest first', () {
    final items = Announcement.merge(
        Announcement.parseAll(polled), Announcement.parseAll(pushed));
    expect(items.map((e) => e.id), ['push-only', 'shared', 'old']);
    expect(items[1].title, 'Dosyadaki başlık');
    expect(Announcement.merge(const [], const []), isEmpty);
  });

  test('service shows pushed announcements and the native push state', () async {
    const channel = MethodChannel('test/push-state');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => {
              'json': polled,
              'pushed': pushed,
              'seen': ['shared', 'push-only'],
              'enabled': true,
              'allowed': true,
              'push': 'subscribed',
            });
    final service = AnnouncementService(channel: channel, android: true);
    await service.loadCached();
    expect(service.items.map((e) => e.id), ['push-only', 'shared', 'old']);
    expect(service.push, 'subscribed');
    expect(service.byId('push-only')!.url, 'https://example.com/a');
    expect(service.byId('missing'), isNull);
  });

  test('tapped FCM-displayed notification is stored natively and opened once', () async {
    const channel = MethodChannel('test/push-open');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'announcementsPushed') return (call.arguments as Map)['id'];
      if (call.method == 'announcementTap') return null;
      return {'json': null, 'pushed': pushed, 'seen': <String>[], 'enabled': true, 'allowed': true};
    });
    final service = AnnouncementService(channel: channel, android: true);
    final taps = <String>[];
    final sub = service.taps.listen(taps.add);
    final item = Announcement.fromPush({'id': 'push-only', 'title': 'Anlık duyuru', 'url': 'https://example.com/a'})!;
    await service.openedPush(item);
    await Future<void>.delayed(Duration.zero);
    final stored = calls.firstWhere((c) => c.method == 'announcementsPushed');
    expect((stored.arguments as Map)['id'], 'push-only');
    expect((stored.arguments as Map)['url'], 'https://example.com/a');
    expect(taps, ['push-only']);
    expect(await service.takeTap(), 'push-only');
    expect(await service.takeTap(), isNull);
    await sub.cancel();
  });

  test('push setup is a safe no-op when Firebase is unavailable', () async {
    final service = AnnouncementService(channel: const MethodChannel('test/none'), android: false);
    final push = PushNotifications(announcements: service, android: true);
    await push.init().timeout(const Duration(seconds: 2));
    expect(push.available, isFalse);
    await PushNotifications(announcements: service, android: false).requestPermissionOnce();
  });

  testWidgets('Duyurular list includes announcements received by push', (tester) async {
    const channel = MethodChannel('test/push-ui');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async =>
            {'json': polled, 'pushed': pushed, 'seen': <String>[], 'enabled': true, 'allowed': true});
    final service = AnnouncementService(channel: channel, android: true);
    await tester.pumpWidget(MaterialApp(home: AnnouncementsScreen(service: service, highlight: 'push-only')));
    await tester.pumpAndSettle();
    expect(find.text('Anlık duyuru'), findsOneWidget);
    expect(find.text('Dosyadaki başlık'), findsOneWidget);
    expect(find.text('Push başlığı'), findsNothing);
    expect(find.byKey(const ValueKey('announcement-push-only')), findsOneWidget);
  });
}
