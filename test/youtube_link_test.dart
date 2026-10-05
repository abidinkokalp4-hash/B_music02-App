import 'package:flutter_test/flutter_test.dart';
import 'package:b_music02/core/services/youtube_link.dart';

void main() {
  test('recognizes share, watch, shorts and live YouTube links', () {
    for (final link in [
      'https://youtu.be/dQw4w9WgXcQ?si=test',
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=12',
      'https://m.youtube.com/shorts/dQw4w9WgXcQ',
      'https://www.youtube.com/live/dQw4w9WgXcQ',
    ]) { expect(youtubeVideoId(link), 'dQw4w9WgXcQ'); }
  });
  test('rejects lookalike hosts, malformed ids and executable input', () {
    for (final link in ['https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ', 'javascript:alert(1)', 'https://youtu.be/short', 'https://www.youtube.com/watch?v=%27%3Cscript%3E', 'https://notyoutube.com/watch?v=dQw4w9WgXcQ']) {
      expect(youtubeVideoId(link), isNull);
    }
  });
}
