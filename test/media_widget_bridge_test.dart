import 'package:audio_service/audio_service.dart';
import 'package:b_music02/core/platform/device_controls.dart';
import 'package:b_music02/core/platform/media_widget_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('widget receives metadata and play state without updates for every progress tick', () async {
    final messages = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceControls.channel, (call) async {
      messages.add(Map<Object?, Object?>.from(call.arguments as Map));
      return null;
    });
    final handler = BaseAudioHandler();
    final bridge = MediaWidgetBridge(handler)..start();
    handler.mediaItem.add(MediaItem(id: '1', title: 'Yol', artist: 'Sanatçı',
        artUri: Uri.file('/covers/one.jpg')));
    handler.playbackState.add(PlaybackState(playing: true, processingState: AudioProcessingState.ready));
    await Future<void>.delayed(Duration.zero);
    expect(messages.last['title'], 'Yol');
    expect(messages.last['artPath'], '/covers/one.jpg');
    expect(messages.last['playing'], true);
    final count = messages.length;
    for (var i = 0; i < 10; i++) {
      handler.playbackState.add(handler.playbackState.value.copyWith(updatePosition: Duration(seconds: i)));
    }
    await Future<void>.delayed(Duration.zero);
    expect(messages.length, count);
    handler.playbackState.add(handler.playbackState.value.copyWith(processingState: AudioProcessingState.completed));
    await Future<void>.delayed(Duration.zero);
    expect(messages.last['playing'], false);
    await bridge.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceControls.channel, null);
  });
}
