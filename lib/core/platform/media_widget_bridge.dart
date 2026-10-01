import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'device_controls.dart';

/// Updates only when visible metadata or the play button actually changes.
class MediaWidgetBridge {
  MediaWidgetBridge(this.handler);
  final AudioHandler handler;
  StreamSubscription<MediaItem?>? _metadata;
  StreamSubscription<PlaybackState>? _playback;
  Map<String, Object?>? _last;
  void start() {
    _metadata = handler.mediaItem.listen((_) => _update());
    _playback = handler.playbackState.listen((_) => _update());
    _update();
  }
  void _update() {
    final item = handler.mediaItem.value;
    final state = handler.playbackState.value;
    final values = <String, Object?>{
      'title': item?.title ?? 'Müziğini seç',
      'artist': item?.artist ?? 'B_music02',
      'playing': state.playing && state.processingState != AudioProcessingState.completed,
      'artPath': item?.artUri?.scheme == 'file' ? item!.artUri!.toFilePath() : null,
    };
    if (_last != null && values.keys.every((key) => values[key] == _last![key])) return;
    _last = values;
    unawaited(_send(values));
  }
  Future<void> _send(Map<String, Object?> values) async {
    try {
      await DeviceControls.channel.invokeMethod<void>('updateWidget', values);
    } on MissingPluginException {
      // Desktop and test hosts do not expose Android widgets.
    } on PlatformException {
      // A launcher failure must not interrupt music playback.
    }
  }
  Future<void> dispose() async {
    await _metadata?.cancel();
    await _playback?.cancel();
  }
}
