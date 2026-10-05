import 'package:b_music02/core/services/video_error_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a damaged packet does not remove a recovering video surface', (tester) async {
    final failures = <String>[];
    final guard = VideoErrorGuard(failures.add);
    guard.error('Error decoding audio.');
    await tester.pump(const Duration(seconds: 1));
    guard.position(const Duration(milliseconds: 1010));
    await tester.pump(const Duration(seconds: 4));
    expect(failures, isEmpty);
    guard.dispose();
  });
  testWidgets('a stalled decoder reports its error even with repeated messages', (tester) async {
    final failures = <String>[];
    final guard = VideoErrorGuard(failures.add);
    guard.error('Error decoding audio.');
    await tester.pump(const Duration(seconds: 2));
    guard.error('Decoder stopped');
    guard.position(Duration.zero);
    await tester.pump(const Duration(seconds: 2));
    expect(failures, ['Decoder stopped']);
    guard.dispose();
  });
  testWidgets('closing a player cancels delayed errors', (tester) async {
    final failures = <String>[];
    final guard = VideoErrorGuard(failures.add);
    guard.error('Failed to open');
    guard.dispose();
    await tester.pump(const Duration(seconds: 4));
    expect(failures, isEmpty);
  });
}
