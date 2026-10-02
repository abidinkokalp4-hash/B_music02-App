import 'package:b_music02/core/services/playlist_pins.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pinned shortcuts survive reopening and keep their order after rename',
      () async {
    final pins = PlaylistPins();
    await pins.toggle('Yol');
    await pins.toggle('Gece');
    await pins.rename('Yol', 'Uzun Yol');
    final reopened = PlaylistPins();
    await reopened.load(['Gece', 'Uzun Yol']);
    expect(reopened.names, ['Uzun Yol', 'Gece']);
    await reopened.remove('Uzun Yol');
    await pins.load(['Gece']);
    expect(pins.names, ['Gece']);
  });

  test('rapid taps cannot leave a stale pin stored after unpinning', () async {
    final pins = PlaylistPins();
    await Future.wait([pins.toggle('Yol'), pins.toggle('Yol')]);
    expect(pins.names, isEmpty);
    final reopened = PlaylistPins();
    await reopened.load(['Yol']);
    expect(reopened.names, isEmpty);
  });

  test('missing playlists and damaged preferences do not become shortcuts',
      () async {
    SharedPreferences.setMockInitialValues({
      PlaylistPins.key: ['Yol', 'Silinmiş']
    });
    final pins = PlaylistPins();
    await pins.load(['Yol']);
    expect(pins.names, ['Yol']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PlaylistPins.key, 'broken');
    await pins.load(['Yol']);
    expect(pins.names, isEmpty);
  });
}
