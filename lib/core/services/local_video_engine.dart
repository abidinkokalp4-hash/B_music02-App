import 'dart:async';
import 'dart:io';
import '../platform/device_controls.dart';
import 'dart:typed_data';
import 'video_error_guard.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

/// Bounded native decoding, including MPEG-PS/MPEG-2; never copies a movie to RAM.
class LocalVideoEngine extends ValueNotifier<VideoPlayerValue> {
  LocalVideoEngine(this.uri) : super(const VideoPlayerValue()) {
    errors = VideoErrorGuard((message) {
      if (!closed) value = value.copyWith(errorDescription: message);
    });
    MediaKitInit.ensure();
    native = mk.Player(configuration: const mk.PlayerConfiguration(bufferSize: 32 * 1024 * 1024, logLevel: mk.MPVLogLevel.v));
    controller = VideoController(native);
    subscriptions.add(native.stream.log.listen((log) {
      if (!closed && log.level == 'error' &&
          (log.prefix.startsWith('vo/') || log.text.contains('Error opening/initializing'))) {
        errors.error('Video görüntüsü başlatılamadı: ${log.text}');
      }
      if (RegExp(r'gpu|EGL|VO:|failed|error|paused', caseSensitive: false).hasMatch(log.text)) {
        debugPrint('[B_music02 video engine] ${log.prefix}: ${log.text}');
      }
    }));
    void changed(dynamic _) => sync();
    subscriptions.add(native.stream.position.listen((position) {
      errors.position(position);
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
        if (!closed) errors.error(message);
      }),
    ]);
  }
  final String uri;
  late final VideoErrorGuard errors;
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
    errors.dispose();
    for (final subscription in subscriptions) { await subscription.cancel(); }
    await native.dispose();
    super.dispose();
  }
  @override
  void dispose() { unawaited(close()); }
}
/// Snapshot of the libmpv player state (replaces package:video_player's value class).
@immutable
class VideoPlayerValue {
  const VideoPlayerValue({this.duration = Duration.zero, this.position = Duration.zero,
      this.size = Size.zero, this.isInitialized = false, this.isPlaying = false,
      this.isBuffering = false, this.isLooping = false, this.volume = 1, this.playbackSpeed = 1,
      this.isCompleted = false, this.errorDescription});
  final Duration duration, position;
  final Size size;
  final bool isInitialized, isPlaying, isBuffering, isLooping, isCompleted;
  final double volume, playbackSpeed;
  final String? errorDescription;
  bool get hasError => errorDescription != null;
  double get aspectRatio => size.width > 0 && size.height > 0 ? size.width / size.height : 16 / 9;
  VideoPlayerValue copyWith({String? errorDescription}) => VideoPlayerValue(duration: duration,
      position: position, size: size, isInitialized: isInitialized, isPlaying: isPlaying,
      isBuffering: isBuffering, isLooping: isLooping, volume: volume, playbackSpeed: playbackSpeed,
      isCompleted: isCompleted, errorDescription: errorDescription ?? this.errorDescription);
}

class MediaKitInit {
  static bool initialized = false;
  static void ensure() {
    if (initialized) return;
    mk.MediaKit.ensureInitialized();
    initialized = true;
  }
}
