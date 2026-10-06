import 'package:b_music02/features/onboarding/app_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tour skips once, persists completion and does not return on launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const app = MaterialApp(home: AppTourGate(child: Scaffold(body: Text('Arşiv hazır'))));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('B Music'), findsOneWidget);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.text('Arşiv hazır'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('b_music_tour_v1'), true);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Arşiv hazır'), findsOneWidget);
    expect(find.text('Atla'), findsNothing);
  });
}
