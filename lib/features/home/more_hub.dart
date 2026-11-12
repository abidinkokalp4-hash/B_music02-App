import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_text.dart';
import '../../core/services/announcements.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/theme/aurora.dart';
import '../alarm/alarm_screen.dart';
import '../profile/announcements_screen.dart';
import '../profile/player_settings_screen.dart';
import 'full_player_screen.dart';
import 'widgets/reference_design.dart';

/// "Daha Fazla" tab: listening stats, shortcuts and the six settings groups.
class MoreHub extends StatefulWidget {
  const MoreHub({super.key});
  @override
  State<MoreHub> createState() => _MoreHubState();
}

class _MoreHubState extends State<MoreHub> {
  int today = 0, streak = 0;
  StreamSubscription<void>? sub;

  @override
  void initState() {
    super.initState();
    unawaited(load());
    sub = MusicInsightsService.instance.changes.listen((_) => load());
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final insights = MusicInsightsService.instance;
    final values = await Future.wait([insights.todayMinutes(), insights.currentStreak()]);
    if (mounted) setState(() { today = values[0]; streak = values[1]; });
  }

  void openSettings([String? section]) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PlayerSettingsScreen(section: section)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 160),
          children: [
            Row(children: [
              const BrandLogo(size: 32),
              const SizedBox(width: 8),
              const Expanded(
                  child: AppText('B Music',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: tr('Duyurular'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => const AnnouncementsScreen())),
                icon: ListenableBuilder(
                  listenable: AnnouncementService.instance,
                  builder: (c, _) {
                    final service = AnnouncementService.instance;
                    final unread = service.items.any((e) => !service.seen.contains(e.id));
                    return Badge(
                      isLabelVisible: unread,
                      child: const Icon(Icons.notifications_none_rounded),
                    );
                  },
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(children: [
                const BrandLogo(size: 64),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const AppText('Dinleme istatistiklerin',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Aurora.textMuted)),
                      const SizedBox(height: 4),
                      const AppText('Bugün', style: TextStyle(fontSize: 12, color: Aurora.textMuted)),
                      Text(Aurora.listeningLabel(today),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    ])),
                Container(width: 1, height: 56, color: Aurora.glassBorder),
                const SizedBox(width: 12),
                Column(children: [
                  const Icon(Icons.local_fire_department_rounded, color: Aurora.coralSoft, size: 28),
                  Text('$streak',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const AppText('günlük seri',
                      style: TextStyle(fontSize: 10, color: Aurora.textMuted)),
                ]),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
              child: AppText('KISAYOLLAR',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      color: Aurora.textMuted)),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                for (final item in <(IconData, Color, String, VoidCallback)>[
                  (Icons.graphic_eq_rounded, const Color(0xFFB65CFF), 'Ekolayzer',
                      () => openSettings('Ekolayzer')),
                  (Icons.nights_stay_rounded, const Color(0xFFFF8A6B), 'Uyku zamanlayıcısı',
                      () => showSleepTimer(context)),
                  (Icons.alarm_rounded, const Color(0xFF8B6CFF), 'Alarm',
                      () => Navigator.push(context,
                          MaterialPageRoute<void>(builder: (_) => const AlarmScreen()))),
                  (Icons.cloud_upload_outlined, Aurora.coralSoft, 'Yedekle',
                      () => openSettings('Gizlilik')),
                  (Icons.brush_outlined, const Color(0xFF9B6CFF), 'Tema',
                      () => openSettings('Görünüm')),
                  (Icons.language_rounded, Aurora.coral, 'Dil',
                      () => openSettings('Dil')),
                ])
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    onTap: item.$4,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(item.$1, color: item.$2, size: 26),
                      const SizedBox(height: 8),
                      AppText(item.$3,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2)),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (final entry in <(IconData, String, String, String)>[
                  (Icons.settings_outlined, 'GENEL', 'Genel', 'Genel'),
                  (Icons.play_circle_outline_rounded, 'OYNATMA', 'Oynatma', 'Oynatma'),
                  (Icons.notifications_none_rounded, 'BİLDİRİMLER', 'Bildirimler', 'Bildirimler'),
                  (Icons.folder_open_rounded, 'DOSYA TARAMASI', 'Dosya taraması', 'Dosya Taraması'),
                  (Icons.shield_outlined, 'GİZLİLİK', 'Gizlilik', 'Gizlilik'),
                  (Icons.info_outline_rounded, 'HAKKINDA', 'Hakkında', 'Hakkında'),
                ]) ...[
                  if (entry != (Icons.settings_outlined, 'GENEL', 'Genel', 'Genel'))
                    Divider(height: 1, color: light ? const Color(0xFFE5E1EC) : Aurora.glassBorder),
                  ListTile(
                    leading: Icon(entry.$1, color: Aurora.electric),
                    title: AppText(entry.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: AppText(entry.$2,
                        style: const TextStyle(fontSize: 10, letterSpacing: 1.1, color: Aurora.textMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Aurora.textMuted),
                    onTap: () => openSettings(entry.$4),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
