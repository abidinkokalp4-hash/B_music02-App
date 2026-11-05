import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Owns both sleep modes, including all subscriptions needed to cancel them.
class SleepTimer {
  SleepTimer(
      {required this.player, required this.pause, required this.onChange});
  final AudioPlayer player;
  final Future<void> Function() pause;
  final void Function() onChange;
  Timer? _timer;
  Timer? _trackTimer;
  Timer? _fadeTimer;

  /// Timed sleep mode fades the music out over this window before pausing.
  static const fadeWindow = Duration(seconds: 30);
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  StreamSubscription<double>? _speedSubscription;
  DateTime? endsAt;
  bool afterTrack = false;
  int? _trackIndex;
  bool get isActive => endsAt != null || afterTrack;

  void start(Duration duration) {
    cancel(notify: false);
    if (duration <= Duration.zero) return;
    endsAt = DateTime.now().add(duration);
    _timer = Timer(duration, _finish);
    final fadeStart = duration - fadeWindow;
    if (fadeStart > Duration.zero) {
      _fadeTimer = Timer(fadeStart, () {
        var step = 0;
        _fadeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          step++;
          final v = 1 - step / fadeWindow.inSeconds;
          unawaited(player.setVolume(v.clamp(0.05, 1.0)));
          if (step >= fadeWindow.inSeconds) t.cancel();
        });
      });
    }
    onChange();
  }

  void stopAfterTrack() {
    cancel(notify: false);
    if (player.sequenceState.currentSource == null) return;
    afterTrack = true;
    _trackIndex = player.currentIndex;
    _stateSubscription = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_finish());
      } else {
        _scheduleTrackEnd();
      }
    });
    _eventSubscription = player.playbackEventStream.listen((event) {
      if (player.currentIndex != _trackIndex) {
        // Also stops on an explicit skip while this one-shot mode is armed.
        unawaited(_finish());
      } else {
        _scheduleTrackEnd();
      }
    });
    _speedSubscription = player.speedStream.listen((_) => _scheduleTrackEnd());
    _scheduleTrackEnd();
    onChange();
  }

  void _scheduleTrackEnd() {
    _trackTimer?.cancel();
    if (!afterTrack ||
        !player.playing ||
        player.processingState != ProcessingState.ready ||
        player.duration == null) return;
    // Pause just before the native gapless transition, including repeat-one.
    final remaining = player.duration! - player.position;
    final microseconds =
        (remaining.inMicroseconds / player.speed).round() - 50000;
    _trackTimer = Timer(
      Duration(microseconds: microseconds.clamp(0, 86400000000)),
      () {
        if (!afterTrack) return;
        final left = player.duration! - player.position;
        if (left.inMilliseconds > 150) {
          // A buffered/stalled decoder must not stop early.
          _scheduleTrackEnd();
        } else {
          unawaited(_finish());
        }
      },
    );
  }

  Future<void> _finish() async {
    if (!isActive) return;
    _fadeTimer?.cancel();
    _fadeTimer = null; // keep the faded volume until paused
    cancel(notify: false);
    try {
      await pause();
      await player.setVolume(1);
    } finally {
      onChange();
    }
  }

  void cancel({bool notify = true}) {
    if (_fadeTimer != null) {
      _fadeTimer!.cancel();
      _fadeTimer = null;
      if (player.volume < 1) unawaited(player.setVolume(1));
    }
    _timer?.cancel();
    _trackTimer?.cancel();
    _timer = _trackTimer = null;
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    _speedSubscription?.cancel();
    _stateSubscription = null;
    _eventSubscription = null;
    _speedSubscription = null;
    endsAt = null;
    afterTrack = false;
    _trackIndex = null;
    if (notify) onChange();
  }
}
