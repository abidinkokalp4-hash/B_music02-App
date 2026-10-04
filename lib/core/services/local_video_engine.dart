import 'dart:async';
import 'dart:io';
import '../platform/device_controls.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' show VideoPlayerValue;

/// Bounded native decoding, including MPEG-PS/MPEG-2; never copies a movie to RAM.
class LocalVideoEngine extends ValueNotifier<VideoPlayerValue> {
  LocalVideoEngine(this.uri) : super(const VideoPlayerValue(duration: Duration.zero)) {
    MediaKitInit.ensure();
    native = mk.Player(configuration: const mk.PlayerConfiguration(bufferSize: 32 * 1024 * 1024, logLevel: mk.MPVLogLevel.v));
    controller = VideoController(native);
    subscriptions.add(native.stream.log.listen((log) {
      if (!closed && log.level == 'error' &&
          (log.prefix.startsWith('vo/') || log.text.contains('Error opening/initializing'))) {
        value = value.copyWith(errorDescription: 'Video görüntüsü başlatılamadı: ${log.text}');
      }
      if (RegExp(r'gpu|EGL|VO:|failed|error|paused', caseSensitive: false).hasMatch(log.text)) {
        debugPrint('[B_music02 video engine] ${log.prefix}: ${log.text}');
      }
    }));
    void changed(dynamic _) => sync();
    subscriptions.add(native.stream.position.listen((position) {
      if (position.inSeconds > 0 && !reportedProgress) {
        reportedProgress = true;
        debugPrint('[B_music02 video] advancing position=${position.inMilliseconds}ms');
      }
    }));
    subscriptions.addAll([
      native.stream.position.listen(changed), native.stream.duration.listen(changed),
      native.stream.playing.listen(changed), native.stream.buffering.listen(changed),
      native.stream.width.listen(changed), native.stream.height.listen(changed),
      native.stream.rate.listen(changed), native.stream.volume.listen(changed),
      native.stream.completed.listen(changed),
      native.stream.error.listen((message) {
        if (!closed) value = value.copyWith(errorDescription: message);
      }),
    ]);
  }
  final String uri;
  late final mk.Player native;
  late final VideoController controller;
  final subscriptions = <StreamSubscription<dynamic>>[];
  bool closed = false, initialized = false, looping = false;
  bool reportedProgress = false;
  void sync() {
    if (closed) return;
    final s = native.state;
    value = VideoPlayerValue(duration: s.duration, position: s.position,
      size: Size((s.width ?? 16).toDouble(), (s.height ?? 9).toDouble()),
      isInitialized: initialized, isPlaying: s.playing, isBuffering: s.buffering,
      isLooping: looping, volume: s.volume / 100, playbackSpeed: s.rate,
      isCompleted: s.completed, errorDescription: value.errorDescription);
  }
  Future<void> initialize({Duration start = Duration.zero}) async {
    // Native renderers can use a software GPU on emulators and older devices.
    // Without this permission mpv may reject the available rendering context.
    final platform = native.platform;
    if (platform is mk.NativePlayer && Platform.isAndroid) {
      final emulator = await DeviceControls.channel.invokeMethod<bool>('isEmulator') ?? false;
      if (emulator) {
        await platform.setProperty('gpu-sw', 'yes');
        // Android's emulator rejects EGL_CONTEXT_FLAGS_KHR=0. Requesting a
        // debug context supplies a supported flag; physical devices keep defaults.
        await platform.setProperty('gpu-debug', 'yes');
      }
    }
    await native.open(mk.Media(uri, start: start), play: false);
    if (closed) return;
    initialized = true;
    sync();
  }
  Future<void> play() => native.play();
  Future<void> pause() => native.pause();
  Future<void> seekTo(Duration position) => native.seek(position);
  Future<void> setPlaybackSpeed(double speed) => native.setRate(speed);
  Future<void> setVolume(double volume) => native.setVolume(volume * 100);
  Future<void> setLooping(bool enabled) async {
    looping = enabled;
    await native.setPlaylistMode(enabled ? mk.PlaylistMode.single : mk.PlaylistMode.none);
    sync();
  }
  Future<Uint8List?> screenshot() => native.screenshot(format: 'image/png');
  Future<void> subtitle(String uri) => native.setSubtitleTrack(mk.SubtitleTrack.uri(uri));
  Future<void> close() async {
    if (closed) return;
    closed = true;
    for (final subscription in subscriptions) { await subscription.cancel(); }
    await native.dispose();
    super.dispose();
  }
  @override
  void dispose() { unawaited(close()); }
}
class MediaKitInit {
  static bool initialized = false;
  static void ensure() {
    if (initialized) return;
    mk.MediaKit.ensureInitialized();
    initialized = true;
  }
}
