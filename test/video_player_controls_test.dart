import 'package:flutter_test/flutter_test.dart';
import 'package:b_music02/features/home/video_player_controls.dart';

void main() {
  test('seeking never goes outside the video duration', () {
    const total = Duration(seconds: 95);
    expect(
      boundedVideoPosition(const Duration(seconds: -10), total),
      Duration.zero,
    );
    expect(boundedVideoPosition(const Duration(seconds: 100), total), total);
    expect(
      boundedVideoPosition(const Duration(seconds: 24), total),
      const Duration(seconds: 24),
    );
    expect(
      boundedVideoPosition(const Duration(seconds: 10), Duration.zero),
      Duration.zero,
    );
  });
  test(
    'long videos display hours and short videos retain minute precision',
    () {
      expect(videoTime(Duration.zero), '0:00');
      expect(videoTime(const Duration(seconds: 95)), '1:35');
      expect(videoTime(const Duration(seconds: 3661)), '1:01:01');
      expect(videoTime(const Duration(seconds: -1)), '0:00');
    },
  );
}
