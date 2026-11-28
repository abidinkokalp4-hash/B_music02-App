import 'package:b_music02/features/extras/clip_window_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('moving and resizing a clip stays within the song and 30 seconds',
      (tester) async {
    var start = Duration.zero;
    var length = const Duration(seconds: 15);
    const total = Duration(minutes: 2);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, refresh) => ClipWindowPicker(
        start: start,
        length: length,
        total: total,
        onChanged: (s, l) => refresh(() {
          start = s;
          length = l;
        }),
      ),
    ))));
    final slider = find.byType(Slider);
    await tester.tapAt(tester.getTopRight(slider) + const Offset(-1, 24));
    await tester.pumpAndSettle();
    expect(length, maxClipLength);
    final bar = find.byWidgetPredicate((w) =>
        w is GestureDetector &&
        w.onHorizontalDragUpdate != null &&
        w.onTapUp != null);
    await tester.tapAt(tester.getCenter(bar) + const Offset(398, 0));
    await tester.pumpAndSettle();
    expect(start, const Duration(seconds: 90));
    expect(start + length, total);
    await tester.tapAt(tester.getCenter(slider));
    await tester.pumpAndSettle();
    expect(length.inSeconds, inInclusiveRange(14, 16));
    expect(start + length <= total, isTrue);
  });
}
