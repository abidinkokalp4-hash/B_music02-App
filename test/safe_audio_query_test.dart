import 'package:b_music02/core/services/safe_audio_query.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.lucasjosino.on_audio_query');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('artwork never throws and returns null on plugin errors', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      throw PlatformException(
          code: 'vb',
          message:
              "Tried to get one of the methods but the 'PluginProvider' has not initialized");
    });
    SafeAudioQuery.hasPermission = true;
    final results = await Future.wait(
        [for (var i = 0; i < 5; i++) SafeAudioQuery.artwork(9000 + i)]);
    expect(results.every((r) => r == null), isTrue);
    expect(calls, lessThanOrEqualTo(5));
  });

  test('artwork is skipped without library permission', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      return null;
    });
    SafeAudioQuery.hasPermission = false;
    expect(await SafeAudioQuery.artwork(77), isNull);
    expect(calls, 0);
  });

  test('permissionsStatus swallows plugin errors', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'x');
    });
    expect(await SafeAudioQuery.permissionsStatus(), isFalse);
  });
}
