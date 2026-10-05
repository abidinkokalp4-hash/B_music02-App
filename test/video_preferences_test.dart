import 'package:b_music02/core/services/video_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('video progress and favorites survive a new player session', () async {
    final prefs = VideoPreferences();
    await prefs.toggleFavorite('video-1');
    await prefs.record(
        'video-1', const Duration(seconds: 42), const Duration(minutes: 3));
    final reopened = VideoPreferences();
    await reopened.load();
    expect(reopened.isFavorite('video-1'), true);
    expect(reopened.position('video-1'), const Duration(seconds: 42));
    expect(reopened.recent, ['video-1']);
    await reopened.toggleFavorite('video-1');
    final again = VideoPreferences();
    await again.load();
    expect(again.isFavorite('video-1'), false);
  });
  test('finished and invalid positions do not resume beyond the video',
      () async {
    final prefs = VideoPreferences();
    await prefs.record(
        'finished', const Duration(seconds: 59), const Duration(minutes: 1));
    await prefs.record(
        'negative', const Duration(seconds: -2), const Duration(minutes: 1));
    await prefs.record(
        'beyond', const Duration(minutes: 9), const Duration(minutes: 1));
    expect(prefs.position('finished'), Duration.zero);
    expect(prefs.position('negative'), Duration.zero);
    expect(prefs.position('beyond'), Duration.zero);
  });
  test('rapid saves retain the latest position and unique history', () async {
    final prefs = VideoPreferences();
    await Future.wait(List.generate(
        10,
        (i) => prefs.record(
            'video', Duration(seconds: i * 5), const Duration(minutes: 2))));
    final reopened = VideoPreferences();
    await reopened.load();
    expect(reopened.position('video'), const Duration(seconds: 45));
    expect(reopened.recent, ['video']);
  });
  test('damaged history does not block playback or new recordings', () async {
    SharedPreferences.setMockInitialValues({VideoPreferences.key: '{bad'});
    final prefs = VideoPreferences();
    await prefs.load();
    expect(prefs.position('video'), Duration.zero);
    await prefs.record(
        'video', const Duration(seconds: 5), const Duration(minutes: 1));
    final reopened = VideoPreferences();
    await reopened.load();
    expect(reopened.position('video'), const Duration(seconds: 5));
  });
  test('initial catalog is baseline; later additions stay new until opened', () async {
    final prefs = VideoPreferences();
    await prefs.observeLibrary({'old'});
    expect(prefs.isNew('old'), false);
    await prefs.observeLibrary({'old', 'added'});
    expect(prefs.isNew('added'), true);
    final reopened = VideoPreferences();
    await reopened.load();
    expect(reopened.isNew('added'), true);
    await reopened.markSeen('added');
    await reopened.observeLibrary({'old', 'added'});
    expect(reopened.isNew('added'), false);
    await reopened.observeLibrary({'old', 'other'});
    expect(reopened.isNew('added'), false);
    expect(reopened.isNew('other'), true);
  });

}
