import 'package:b_music02/core/theme/app_theme.dart';
import 'package:b_music02/core/theme/theme_controller.dart';
import 'package:b_music02/features/profile/announcements_screen.dart';
import 'package:b_music02/features/profile/player_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/tmp');
  });

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ThemeControllerScope(
        controller: ThemeController(),
        child: MaterialApp(
            theme: AppTheme.dark(), home: const PlayerSettingsScreen())));
    await tester.pumpAndSettle();
  }

  Future<void> page(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('notification settings keep the widget action and show status',
      (tester) async {
    await openSettings(tester);
    await page(tester, 'Bildirimler');
    expect(find.text('Ana ekran oynatıcısı'), findsOneWidget);
    expect(find.text('Bildirim izni'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Yeni video rozeti'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Yeni video rozeti'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Duyurular'), 200,
        scrollable: find.byType(Scrollable).first);
    final toggle = find.widgetWithText(SwitchListTile, 'Duyuru bildirimleri');
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Duyurular'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Duyurular'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementsScreen), findsOneWidget);
    expect(find.text('Henüz duyuru yok'), findsOneWidget);
  });

  testWidgets('appearance settings offer icon colour and home sections',
      (tester) async {
    await openSettings(tester);
    await page(tester, 'Görünüm');
    await tester.scrollUntilVisible(find.text('Uygulama simgesi rengi'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Uygulama simgesi rengi'));
    await tester.pumpAndSettle();
    expect(find.text('Pembe'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Video listesi görünümü'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Favori Klasörler'), findsNothing);
    expect(find.text('Son İzlenenler'), findsOneWidget);
  });

  testWidgets('about page shows archive stats, news and support',
      (tester) async {
    await openSettings(tester);
    await page(tester, 'Hakkında');
    expect(find.text('Arşivin'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Yenilikler'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Yenilikler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reels'), findsOneWidget);
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sorun bildir'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
