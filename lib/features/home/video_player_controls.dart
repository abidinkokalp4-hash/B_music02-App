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

/// What a one-finger drag on the video does.
enum VideoDrag { seek, brightness, volume, page }

/// Horizontal drags seek. Vertical drags change brightness on the left half
/// and volume on the right half. In reels mode (a list to swipe through) the
/// middle 40% pages to the previous/next video, while the outer 30% edges
/// keep brightness (left) and volume (right).
VideoDrag videoDragFor({
  required double startX,
  required double width,
  required double dx,
  required double dy,
  required bool reels,
}) {
  if (dx.abs() > dy.abs()) return VideoDrag.seek;
  final fraction = width <= 0 ? .5 : startX / width;
  if (reels) {
    if (fraction < .3) return VideoDrag.brightness;
    if (fraction > .7) return VideoDrag.volume;
    return VideoDrag.page;
  }
  return fraction < .5 ? VideoDrag.brightness : VideoDrag.volume;
}
