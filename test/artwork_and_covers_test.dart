import 'dart:io';
import 'package:b_music02/features/home/widgets/music_widgets.dart';
import 'dart:typed_data';
import 'package:b_music02/core/services/artwork_palette.dart';
import 'package:b_music02/core/services/playlist_covers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('missing artwork uses the application logo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MediaArtwork(label: 'Kapaksız şarkı'))));
    await tester.pumpAndSettle();
    final picture = tester.widget<Image>(find.byType(Image));
    expect(picture.image, const AssetImage('assets/images/b_music02_logo.png'));
    expect(tester.takeException(), isNull);
  });
  test('dominant colour ignores transparent, white, black and grey pixels', () {
    final pixels = Uint8List.fromList([
      0, 0, 0, 255, 255, 255, 255, 255, 120, 120, 120, 255,
      0, 255, 0, 0, 200, 40, 70, 255, 204, 44, 74, 255,
      40, 100, 220, 255,
    ]);
    expect(dominantArtworkColor(pixels), const Color.fromARGB(255, 202, 42, 72));
    expect(dominantArtworkColor(Uint8List.fromList([100, 100, 100, 255])), isNull);
  });
  test('invalid artwork uses the theme fallback without breaking playback', () async {
    expect(await ArtworkPalette.forArtwork(Uri.parse('https://example.com/cover')), isNull);
    expect(await ArtworkPalette.forArtwork(Uri.file('/missing/bmusic-cover.png')), isNull);
  });
  test('covers survive reload and rename, replacement and deletion clean owned files', () async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('bmusic-cover-test-');
    try {
      final source = await File('${root.path}/photo.png').writeAsBytes([1, 2, 3]);
      final covers = PlaylistCovers(directory: () async => root);
      await covers.set('Yol', source.path);
      final first = covers.pathFor('Yol')!;
      expect(first, isNot(source.path));
      await covers.rename('Yol', 'Gece');
      final reloaded = PlaylistCovers(directory: () async => root);
      await reloaded.load();
      expect(reloaded.pathFor('Yol'), isNull);
      expect(reloaded.pathFor('Gece'), first);
      await reloaded.set('Gece', source.path);
      expect(await File(first).exists(), false);
      final second = reloaded.pathFor('Gece')!;
      await reloaded.remove('Gece');
      expect(await File(second).exists(), false);
      expect(await source.exists(), true);
      await covers.load();
      expect(covers.pathFor('Gece'), isNull);
    } finally { await root.delete(recursive: true); }
  });
  test('stale and damaged cover preferences do not break the library', () async {
    SharedPreferences.setMockInitialValues({PlaylistCovers.key: '{"Yol":"/missing/image.jpg"}'});
    final covers = PlaylistCovers();
    await covers.load();
    expect(covers.pathFor('Yol'), isNull);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PlaylistCovers.key, 'broken');
    await covers.load();
    expect(covers.pathFor('Yol'), isNull);
  });
}
