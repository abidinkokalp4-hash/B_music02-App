import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../platform/device_controls.dart';
import 'player_preferences.dart';

/// Soft song transitions: the last [seconds] of a track fade out and the next
/// track fades in. Uses only the player volume, so it works on every device.
/// Preference key: `crossfadeSeconds` (0 = off).
class Crossfade {
  Crossfade._(this.player) {
    try {
      player.positionStream.listen(_tick);
      player.currentIndexStream.distinct().listen((_) => _fadeIn());
      player.androidAudioSessionIdStream.listen((_) => applySpatial());
    } catch (_) {/* Test fakes / unsupported players: no transitions. */}
  }

  /// Re-applies the 8D / uzamsal ses preference (`spatial8d`).
  static Future<bool> applySpatial() async {
    final p = _instance?.player;
    if (p == null) return false;
    final on = PlayerPreferences.instance.flag('spatial8d', fallback: false);
    return setSpatialAudio(p.androidAudioSessionId, on ? 1000 : 0);
  }
  static Crossfade? _instance;
  static void attach(AudioPlayer player) => _instance ??= Crossfade._(player);

  final AudioPlayer player;
  Timer? _ramp;
  bool _fadingOut = false;

  static double get seconds =>
      PlayerPreferences.instance.number('crossfadeSeconds', 0).clamp(0, 12);

  /// Volume (0..1) for the remaining time of the track; pure for tests.
  static double fadeOutVolume(Duration remaining, double fadeSeconds) {
    if (fadeSeconds <= 0) return 1;
    final r = remaining.inMilliseconds / (fadeSeconds * 1000);
    return r.clamp(0.0, 1.0);
  }

  void _tick(Duration position) {
    final fade = seconds;
    final duration = player.duration;
    if (fade <= 0 || duration == null || !player.playing) return;
    if (!player.hasNext && player.loopMode != LoopMode.all) return;
    final remaining = duration - position;
    if (remaining.inMilliseconds <= fade * 1000) {
      _fadingOut = true;
      _ramp?.cancel();
      unawaited(player.setVolume(fadeOutVolume(remaining, fade)));
    } else if (_fadingOut) {
      // User seeked back out of the fade window.
      _fadingOut = false;
      unawaited(player.setVolume(1));
    }
  }

  void _fadeIn() {
    final fade = seconds;
    _ramp?.cancel();
    if (!_fadingOut && player.volume >= 1) return;
    _fadingOut = false;
    if (fade <= 0) {
      unawaited(player.setVolume(1));
      return;
    }
    var step = 0;
    const steps = 20;
    unawaited(player.setVolume(0));
    _ramp = Timer.periodic(
        Duration(milliseconds: (fade * 1000 / steps).round()), (t) {
      step++;
      unawaited(player.setVolume((step / steps).clamp(0.0, 1.0)));
      if (step >= steps) t.cancel();
    });
  }
}
