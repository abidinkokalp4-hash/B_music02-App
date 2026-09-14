import 'package:flutter/material.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';
import '../onboarding/music_permissions_screen.dart';
import 'legal_documents_screen.dart';
import 'music_settings_screen.dart';

class ProfileHubScreen extends StatefulWidget {
  const ProfileHubScreen({super.key});

  @override
  State<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends State<ProfileHubScreen> {
  final LocalMusicService _music = LocalMusicService.instance;

  @override
  void initState() {
    super.initState();
    _music.addListener(_changed);
  }

  @override
  void dispose() {
    _music.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
          children: [
            _topBar(),
            const SizedBox(height: 8),
            _identity(),
            const SizedBox(height: 18),
            _stats(),
            const SizedBox(height: 18),
            _localModeCard(),
            const SizedBox(height: 10),
            _menuTile(
              icon: Icons.tune_rounded,
              title: 'Uygulama Ayarları',
              onTap: () => _open(const MusicSettingsScreen()),
            ),
            const SizedBox(height: 7),
            _menuTile(
              icon: Icons.notifications_none_rounded,
              title: 'Bildirimler ve İzinler',
              onTap: () => _open(const MusicPermissionsScreen()),
            ),
            const SizedBox(height: 7),
            _menuTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik',
              onTap: () => _open(const PrivacyPolicyScreen()),
            ),
            const SizedBox(height: 7),
            _menuTile(
              icon: Icons.calendar_month_outlined,
              title: 'Kullanım',
              onTap: () => _open(const TermsOfUseScreen()),
            ),
            const SizedBox(height: 7),
            _menuTile(
              icon: Icons.info_outline_rounded,
              title: 'Hakkında',
              onTap: _about,
            ),
            const SizedBox(height: 13),
            _bottomBanner(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Expanded(
          child: Text('Profil', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        ),
        IconButton(
          onPressed: () => _open(const MusicSettingsScreen()),
          icon: const Icon(Icons.settings_outlined, size: 25),
        ),
      ],
    );
  }

  Widget _identity() {
    return Column(
      children: [
        Container(
          width: 94,
          height: 94,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.neonPurple, AppColors.neonPink],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonPurple.withValues(alpha: 0.38),
                blurRadius: 24,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset('assets/images/b_music02_logo.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'B_music02',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.neonPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'Yerel müzik modu • Hesapsız kullanım',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
        ),
      ],
    );
  }

  Widget _stats() {
    return Row(
      children: [
        Expanded(child: _Stat(value: '${_music.songs.length}', label: 'Şarkı')),
        Expanded(child: _Stat(value: '${_music.favoriteIds.length}', label: 'Favori')),
        Expanded(child: _Stat(value: '${_music.playlists.length}', label: 'Liste')),
      ],
    );
  }

  Widget _localModeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF291446), Color(0xFF161226)],
        ),
        border: Border.all(color: const Color(0xFF5C2C93)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, color: Color(0xFFFFC340), size: 25),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verilerin cihazında', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text(
                  'Favoriler, listeler ve dinleme verileri hesap açmadan bu cihazda saklanır.',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF151724),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 21, color: Colors.white),
              const SizedBox(width: 11),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 21),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBanner() {
    return Container(
      height: 84,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF772AE8), Color(0xFF173BC6)],
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('B_music02’yi Keşfet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  'Yeni müziklerini bul, listelerini düzenle ve dinleme deneyimini kişiselleştir.',
                  style: TextStyle(color: Colors.white70, fontSize: 9.5, height: 1.25),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.auto_awesome_rounded, size: 42, color: Color(0xFFE7A4FF)),
        ],
      ),
    );
  }

  Future<void> _about() async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('B_music02'),
        content: const Text(
          'Müziklerini dinlemek, keşfetmek, favorilerini ve çalma listelerini yönetmek için geliştirilen B_music02 müzik uygulaması.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
      ],
    );
  }
}
