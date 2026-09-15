import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:b_music02/core/services/player_preferences.dart';
import 'package:b_music02/core/l10n/app_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'settings survive reload and reset does not erase library data',
    () async {
      SharedPreferences.setMockInitialValues({
        'b_music02_local_favorites': ['12'],
        'b_music02_local_playlists_v1': '{"Road":[12]}',
      });
      final settings = PlayerPreferences.instance;
      await settings.load();
      await settings.set('volume', .35);
      await settings.set('background', false);
      await settings.set('eqGains', [1.0, -2.0, 3.0]);
      await settings.load();
      expect(settings.number('volume', 1), .35);
      expect(settings.flag('background'), false);
      expect(settings.gains('eqGains'), [1.0, -2.0, 3.0]);
      await settings.reset();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('b_music02_local_favorites'), ['12']);
      expect(prefs.getString('b_music02_local_playlists_v1'), '{"Road":[12]}');
      expect(settings.flag('background'), true);
    },
  );
  test('language labels translate and unknown text is preserved', () {
    expect(translate('Ayarlar', 'en'), 'Settings');
    expect(translate('Ayarlar', 'ku'), 'Mîheng');
    expect(translate('Ayarlar', 'ar'), 'الإعدادات');
    expect(translate('Ayarlar', 'tr'), 'Ayarlar');
    expect(translate('recording-0001.mp3', 'en'), 'recording-0001.mp3');
  });
}
