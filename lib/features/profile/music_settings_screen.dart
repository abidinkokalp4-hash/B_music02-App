import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../onboarding/music_permissions_screen.dart';
import 'legal_documents_screen.dart';

class MusicSettingsScreen extends StatelessWidget {
  const MusicSettingsScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.of(context);
    final music = LocalMusicService.instance;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 170),
          children: [
            _header(context),
            const SizedBox(height: 26),
            _sectionLabel('GÖRÜNÜM'),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _box(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tema',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Uygulamanın görünümünü seç.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.auto_awesome_rounded),
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
            const SizedBox(height: 26),
            _sectionLabel('MÜZİK VE İZİNLER'),
            const SizedBox(height: 9),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.library_music_rounded,
                  title: 'Müzik erişimi',
                  subtitle: 'Telefondaki şarkılar ve medya izinları',
                  onTap: () => _open(context, const MusicPermissionsScreen()),
                ),
                _SettingsTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Sistem izinleri',
                  subtitle: 'Android bildirim ve uygulama izinlarını aç',
                  onTap: openAppSettings,
                ),
              ],
            ),
            const SizedBox(height: 26),
            _sectionLabel('GİZLİLİK VE YASAL'),
            const SizedBox(height: 9),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Gizlilik Politikası',
                  subtitle: 'Hangi verilerin nasıl kullanıldığını gör',
                  onTap: () => _open(context, const PrivacyPolicyScreen()),
                ),
                _SettingsTile(
                  icon: Icons.gavel_rounded,
                  title: 'Kullanım Koşulları',
                  subtitle: 'Uygulama ve içerik kullanım şartları',
                  onTap: () => _open(context, const TermsOfUseScreen()),
                ),
                _SettingsTile(
                  icon: Icons.library_music_outlined,
                  title: 'İçerik ve Kaynak Kuralları',
                  subtitle: 'Telif ve dış kaynak kullanım bilgileri',
                  onTap: () => _open(context, const CommunityGuidelinesScreen()),
                ),
              ],
            ),
            const SizedBox(height: 26),
            _sectionLabel('BU CİHAZDAKİ VERİLER'),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _DataCard(
                    icon: Icons.favorite_rounded,
                    value: '${music.favoriteIds.length}',
                    label: 'Favori',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DataCard(
                    icon: Icons.queue_music_rounded,
                    value: '${music.playlists.length}',
                    label: 'Çalma listesi',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.22),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_rounded, color: AppColors.accentSoft),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bu sürüm kullanıcı hesabı istemez. Favoriler, çalma listeleri ve dinleme istatistikleri cihazında yerel olarak saklanır.',
                      style: TextStyle(height: 1.45, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _sectionLabel('HAKKINDA'),
            const SizedBox(height: 9),
            const _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.album_rounded,
                  title: 'B_music02',
                  subtitle: 'Müziğini dinle • keşfet • listelerini yönet',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AYARLAR',
          style: TextStyle(
            color: AppColors.accentSoft,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kontrol sende.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Görünüm, izinler, gizlilik ve cihazındaki müzik verileri.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  static Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.accentSoft,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  static BoxDecoration _box(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(context).dividerColor),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 64,
                color: Theme.of(context).dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: AppColors.accentSoft, size: 21),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 21),
      onTap: onTap,
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentSoft, size: 22),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
