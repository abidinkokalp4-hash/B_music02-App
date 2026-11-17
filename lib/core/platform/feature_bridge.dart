import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../services/player_preferences.dart';
import 'device_controls.dart';

/// Native helpers for the Nov 2026 feature round: story video export, direct
/// share targets, volume booster, floating bubble, QR scanner and deep links.
class FeatureBridge {
  static final _channel = DeviceControls.channel;
  static AudioPlayer? _player;
  static StreamSubscription<Object?>? _a, _b, _c;

  /// Called once the music player exists (LocalAudioHandler).
  static void attach(AudioPlayer player) {
    if (_player != null) return;
    _player = player;
    try {
      _a = player.androidAudioSessionIdStream.listen((_) => applyBoost());
      _b = player.playingStream.listen((_) => pushBubble());
      _c = player.sequenceStateStream.listen((_) => pushBubble());
    } catch (_) {/* Test fakes. */}
  }

  static void detachForTests() {
    _a?.cancel();
    _b?.cancel();
    _c?.cancel();
    _player = null;
  }

  static Future<T?> _call<T>(String method, [Object? args]) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }

  // ---- Ses yükseltici --------------------------------------------------
  /// 100..200 (%). Stored as `volumeBoost`.
  static int get boostPercent =>
      PlayerPreferences.instance.number('volumeBoost', 100).round().clamp(100, 200);

  /// Approximate extra gain (dB) for a booster percentage (200 % = +10 dB).
  static double boostDb(int percent) => (percent.clamp(100, 200) - 100) / 10;

  static Future<bool> applyBoost() async {
    final session = _player?.androidAudioSessionId;
    if (session == null) return boostPercent <= 100;
    return await _call<bool>(
            'volumeBoost', {'session': session, 'percent': boostPercent}) ??
        false;
  }

  // ---- Mini müzik baloncuğu -------------------------------------------
  static bool get bubbleEnabled =>
      PlayerPreferences.instance.flag('musicBubble', fallback: false);

  static Future<bool> canDrawOverlays() async =>
      await _call<bool>('canDrawOverlays') ?? false;
  static Future<void> requestOverlay() => _call<void>('requestOverlay');

  static Future<void> pushBubble() async {
    final p = _player;
    if (p == null) return;
    MediaItem? item;
    try {
      final tag = p.sequenceState.currentSource?.tag;
      if (tag is MediaItem) item = tag;
    } catch (_) {}
    final art = item?.artUri;
    await _call<bool>('bubble', {
      'enabled': bubbleEnabled,
      'title': item?.title ?? '',
      'artist': item?.artist ?? '',
      'art': art != null && art.scheme == 'file' ? art.toFilePath() : null,
      'playing': p.playing,
    });
  }

  // ---- Paylaşım ---------------------------------------------------------
  static Future<String?> shareDir() => _call<String>('shareDir');

  /// Exports [image] (still card) + [start]..[end] of [audio] as an MP4.
  static Future<String> storyVideo(
      {required String image,
      required String audio,
      required Duration start,
      required Duration end}) async {
    final path = await _channel.invokeMethod<String>('storyVideo', {
      'image': image,
      'audio': audio,
      'start': start.inMilliseconds,
      'end': end.inMilliseconds,
    });
    if (path == null) throw StateError('story');
    return path;
  }

  /// [target]: null (system share sheet), 'instagram' or 'whatsapp'.
  static Future<bool> shareFile(String path,
          {required String mime, String? target, String? text}) async =>
      await _call<bool>('shareFile',
          {'path': path, 'mime': mime, 'target': target, 'text': text}) ??
      false;

  // ---- QR / bağlantılar -------------------------------------------------
  /// Google code scanner (no camera permission). Null when cancelled.
  static Future<String?> scanQr() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('scanQr');
  }

  static Future<String?> takeLink() => _call<String>('takeLink');
}

/// Deterministic pseudo waveform for the 15-second picker (looks like the
/// mockup; real decoding of the whole song would be slow).
List<double> pseudoWaveform(int seed, int count) {
  final r = math.Random(seed);
  var v = .5;
  return List.generate(count, (i) {
    v = (v + (r.nextDouble() - .5) * .5).clamp(.18, 1.0);
    return v;
  });
}
