import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../onboarding/music_permissions_screen.dart';

class MusicSettingsScreen extends StatelessWidget {
  const MusicSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.of(context);
    final music = LocalMusicService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const _SectionTitle('Görünüm'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tema',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.phone_android_rounded),
                        label: Text('Sistem'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Koyu'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Açık'),
                      ),
                    ],
                    selected: {themeController.themeMode},
                    onSelectionChanged: (value) {
                      themeController.setThemeMode(value.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Müzik ve izinler'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.library_music_rounded, color: AppColors.gold),
                  title: const Text('Müzik izinleri'),
                  subtitle: const Text('Telefondaki müzikler ve bildirim izni'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MusicPermissionsScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: AppColors.gold),
                  title: const Text('Telefon uygulama ayarları'),
                  subtitle: const Text('Android izinleri ve bildirim seçenekleri'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 19),
                  onTap: openAppSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Bu cihazdaki veriler'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_rounded, color: AppColors.gold),
                  title: const Text('Favoriler'),
                  trailing: Text(
                    '${music.favoriteIds.length}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.playlist_play_rounded, color: AppColors.gold),
                  title: const Text('Çalma listeleri'),
                  trailing: Text(
                    '${music.playlists.length}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: AppColors.gold),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'B_music02 bu sürümde kullanıcı hesabı kullanmaz. Favoriler, çalma listeleri ve dinleme istatistikleri bu cihazda saklanır.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Hakkında'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: AppColors.gold),
              title: Text('B_music02'),
              subtitle: Text('Müzik dinle • keşfet • listelerini yönet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
