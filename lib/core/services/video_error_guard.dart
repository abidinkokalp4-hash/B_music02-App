import 'dart:async';

/// Decoder errors can describe a damaged packet, not a failed playback session.
/// Allow the native player to recover before replacing its rendering surface.
class VideoErrorGuard {
  VideoErrorGuard(this.onFailure);
  final void Function(String) onFailure;
  Timer? _timer;
  Duration _lastPosition = Duration.zero;
  String? _pending;

  void error(String message) {
    _pending = message;
    _timer ??= Timer(const Duration(seconds: 3), () {
      _timer = null;
      final message = _pending;
      _pending = null;
      if (message != null) onFailure(message);
    });
  }

  void position(Duration position) {
    if (position > _lastPosition) {
      _timer?.cancel();
      _timer = null;
      _pending = null;
    }
    _lastPosition = position;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
