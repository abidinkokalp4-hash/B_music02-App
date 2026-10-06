import 'dart:convert';

import 'package:b_music02/core/services/announcements.dart';
import 'package:b_music02/features/profile/announcements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const sample = '''{"announcements":[
  {"id":"old","title":"Eski","body":"Eski duyuru","createdAt":"2026-01-01T10:00:00+03:00"},
  {"id":"new","title":"Yeni sürüm","body":"v1.0.330 hazır","url":"https://github.com/abidinkokalp4-hash/B_music02-App/releases/latest","createdAt":"2026-10-07T10:00:00Z"},
  {"id":"undated","title":"Tarihsiz"},
  {"id":"new","title":"Kopya"},
  {"id":"","title":"Kimliksiz"},
  {"id":"insecure","title":"Link","url":"http://example.com","createdAt":"2026-10-08"},
  "metin"
]}''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parsing keeps valid unique entries newest first and only https links', () {
    final items = Announcement.parseAll(sample);
    expect(items.map((e) => e.id), ['insecure', 'new', 'old', 'undated']);
    expect(items[1].url, startsWith('https://github.com/'));
    expect(items[0].url, isNull);
    expect(items[1].createdAt, DateTime.utc(2026, 10, 7, 10));
    expect(items[2].createdAt, DateTime.utc(2026, 1, 1, 7));
    expect(items.firstWhere((e) => e.id == 'new').title, 'Yeni sürüm');
  });

  test('malformed or empty files never throw', () {
    for (final text in [null, '', 'not json', '[]', '{"announcements":{}}', '{"announcements":[]}']) {
      expect(Announcement.parseAll(text), isEmpty, reason: '$text');
    }
    // The seeded repository file is valid and empty.
    expect(jsonDecode('{"announcements":[]}'), isA<Map>());
  });

  test('service applies native state and throttles resume checks', () async {
    const channel = MethodChannel('test/announcements');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'announcementTap') return 'new';
      return {'json': sample, 'seen': ['old', 'new'], 'enabled': true, 'allowed': false};
    });
    final service = AnnouncementService(channel: channel, android: true);
    await service.check(force: true);
    expect(service.items.length, 4);
    expect(service.seen, {'old', 'new'});
    expect(service.allowed, false);
    await service.check(); // within 15 minutes of the last check
    expect(calls.where((c) => c == 'announcementsCheck').length, 1);
    await service.check(force: true);
    expect(calls.where((c) => c == 'announcementsCheck').length, 2);
    await service.setEnabled(false);
    expect(service.enabled, false);
    expect(calls.last, 'announcementsEnable');
    expect(await service.takeTap(), 'new');
    expect(await AnnouncementService(channel: channel, android: false).takeTap(), isNull);
  });

  testWidgets('Duyurular list shows entries, highlight and link button', (tester) async {
    const channel = MethodChannel('test/announcements-ui');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async =>
            {'json': sample, 'seen': <String>[], 'enabled': true, 'allowed': true});
    final service = AnnouncementService(channel: channel, android: true);
    await tester.pumpWidget(MaterialApp(
        home: AnnouncementsScreen(service: service, highlight: 'new')));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sürüm'), findsOneWidget);
    expect(find.text('v1.0.330 hazır'), findsOneWidget);
    expect(find.text('Bağlantıyı aç'), findsOneWidget);
    expect(find.text('Henüz duyuru yok'), findsNothing);
    final card = tester.widget<Card>(find.byKey(const ValueKey('announcement-new')));
    expect(card.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('empty list explains there are no announcements', (tester) async {
    const channel = MethodChannel('test/announcements-empty');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async =>
            {'json': '{"announcements":[]}', 'seen': <String>[], 'enabled': false, 'allowed': true});
    await tester.pumpWidget(MaterialApp(
        home: AnnouncementsScreen(service: AnnouncementService(channel: channel, android: true))));
    await tester.pumpAndSettle();
    expect(find.text('Henüz duyuru yok'), findsOneWidget);
    expect(find.textContaining('Duyuru bildirimleri kapalı'), findsOneWidget);
  });
}
