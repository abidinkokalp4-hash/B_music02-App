import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_text.dart';
import '../../core/services/music_insights_service.dart';

/// Dinleme istatistikleri: bugün, seri, en çok dinlenenler.
class ListeningStatsScreen extends StatelessWidget {
  const ListeningStatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = MusicInsightsService.instance;
    return Scaffold(
      appBar: AppBar(title: const AppText('Dinleme istatistikleri')),
      body: FutureBuilder(
        future: Future.wait([s.todayMinutes(), s.currentStreak(), s.topTracks(limit: 20)]),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final today = snap.data![0] as int;
          final streak = snap.data![1] as int;
          final top = snap.data![2] as List<TrackInsight>;
          Widget tile(IconData i, String label, String value) => Expanded(
                child: Card(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Icon(i, color: const Color(0xFFFFD400)),
                    const SizedBox(height: 8),
                    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    AppText(label, style: const TextStyle(fontSize: 12)),
                  ]),
                )),
              );
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              tile(Icons.today, 'Bugün (dakika)', '$today'),
              tile(Icons.local_fire_department, 'Gün serisi', '$streak'),
            ]),
            const SizedBox(height: 16),
            const AppText('En Çok Dinlenenler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (top.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: AppText('Henüz dinleme kaydı yok', textAlign: TextAlign.center)),
            for (final (i, t) in top.indexed)
              ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text('${t.plays}×'),
              ),
          ]);
        },
      ),
    );
  }
}

/// İlk açılışta (ve Ayarlar'dan) yeni özellikleri anlatan kısa ipuçları.
const featureTips = <(IconData, String, String)>[
  (Icons.language, 'Dil', 'Ayarlar › Dil: Türkçe, English, Kurdî, Soranî, العربية. Tüm ekranlar seçilen dile geçer.'),
  (Icons.cast, "TV'ye yansıt", 'Video menüsünden (⋮) telefon ekranını TV veya Chromecast’e yansıt.'),
  (Icons.music_video_outlined, 'Arka planda video sesi', 'Ekran kapalıyken de videonun sesi çalmaya devam eder.'),
  (Icons.picture_in_picture_alt, 'Mini video penceresi', 'Video oynarken ana ekran tuşuna bas: video küçük pencerede sürer.'),
  (Icons.ios_share_rounded, 'Paylaşım kartı', 'Oynatıcıdaki paylaş düğmesi: “Şu an dinliyorum” kartını hikâyende paylaş.'),
  (Icons.mic_none_rounded, 'Sesli komut', 'Oynatıcıdaki mikrofona dokun ve “Sonraki”, “Dur”, “Çal” de.'),
  (Icons.surround_sound, '8D ses', 'Ayarlar › Oynatma: kulaklıkta etrafını saran uzamsal ses.'),
  (Icons.swap_horiz, 'Geçiş efekti', 'Şarkılar birbirine yumuşakça geçsin (crossfade).'),
  (Icons.timer_outlined, 'Uyku zamanlayıcısı', 'Süre bitmeden son 30 saniyede ses yavaşça kısılır.'),
  (Icons.insights, 'Dinleme istatistikleri', 'Ayarlar › Oynatma: bugün kaç dakika dinledin, en sevdiklerin.'),
  (Icons.widgets_outlined, 'Ana ekran widget’ı', 'Ana ekrana basılı tutup Widget’lar bölümünden B Music’i seç.'),
];

const tipsKey = 'b_music_tips_v2';

Future<void> showFeatureTipsOnce(BuildContext context) async {
  final p = await SharedPreferences.getInstance();
  if (p.getBool(tipsKey) ?? false) return;
  await p.setBool(tipsKey, true);
  if (context.mounted) await showFeatureTips(context);
}

Future<void> showFeatureTips(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        builder: (c, scroll) => ListView(controller: scroll, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: AppText('Yenilikler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          for (final t in featureTips)
            ListTile(
              leading: Icon(t.$1, color: const Color(0xFFFFD400)),
              title: AppText(t.$2),
              subtitle: AppText(t.$3, style: const TextStyle(fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(onPressed: () => Navigator.pop(c), child: const AppText('Anladım')),
          ),
        ]),
      ),
    );
