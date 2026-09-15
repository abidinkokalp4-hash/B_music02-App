Duration boundedVideoPosition(Duration requested, Duration total) => Duration(
  milliseconds: requested.inMilliseconds.clamp(
    0,
    total.inMilliseconds < 0 ? 0 : total.inMilliseconds,
  ),
);
String videoTime(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 0x7fffffff);
  final s = (seconds % 60).toString().padLeft(2, '0');
  final m = ((seconds ~/ 60) % 60).toString().padLeft(2, '0');
  return seconds >= 3600 ? '${seconds ~/ 3600}:$m:$s' : '${seconds ~/ 60}:$s';
}
