import 'package:b_music02/core/l10n/app_text.dart';
import 'package:b_music02/core/services/announcements.dart';
import 'package:b_music02/core/services/crossfade.dart';
import 'package:b_music02/core/services/voice_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('greeting and rating pushes do not pile up in Duyurular', () {
    final now = DateTime.utc(2026, 11, 6);
    Announcement a(String id, String title, int daysAgo) => Announcement(
        id: id, title: title, createdAt: now.subtract(Duration(days: daysAgo)));
    final listed = Announcement.listed([
      a('1', 'Hayırlı Cumalar 🤲', 0),
      a('2', 'B Music\'i beğendin mi? ⭐', 1),
      a('3', 'Yeni sürüm çıktı', 2),
      a('4', 'Günaydın', 3),
      a('5', 'Eski duyuru', 200),
    ]);
    expect(listed.map((e) => e.id), ['3', '5']);
  });

  test('crossfade volume ramps down at the end', () {
    expect(Crossfade.fadeOutVolume(const Duration(seconds: 10), 0), 1);
    expect(Crossfade.fadeOutVolume(const Duration(seconds: 3), 6), .5);
    expect(Crossfade.fadeOutVolume(Duration.zero, 6), 0);
  });

  test('voice commands in several languages', () {
    expect(parseVoiceCommand('sonraki şarkı'), VoiceAction.next);
    expect(parseVoiceCommand('Next song'), VoiceAction.next);
    expect(parseVoiceCommand('önceki'), VoiceAction.previous);
    expect(parseVoiceCommand('müziği durdur'), VoiceAction.pause);
    expect(parseVoiceCommand('çal'), VoiceAction.play);
    expect(parseVoiceCommand('merhaba'), VoiceAction.unknown);
  });

  test('every language translates new UI and falls back to Turkish', () {
    for (final lang in ['en', 'ku', 'ckb', 'ar']) {
      expect(translate('Dinleme istatistikleri', lang),
          isNot('Dinleme istatistikleri'));
      expect(translate("TV'ye yansıt", lang), isNot("TV'ye yansıt"));
    }
    expect(translate('Olmayan metin', 'ar'), 'Olmayan metin');
    expect(translate('Duyurular', 'tr'), 'Duyurular');
  });
}
