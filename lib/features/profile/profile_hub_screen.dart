import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../onboarding/music_permissions_screen.dart';
import 'legal_documents_screen.dart';
import 'music_settings_screen.dart';
import 'profile_screen.dart';

class ProfileHubScreen extends StatefulWidget {
  const ProfileHubScreen({
    super.key,
    required this.onRequestLogin,
    required this.onSignOut,
  });

  final Future<void> Function() onRequestLogin;
  final Future<void> Function() onSignOut;

  @override
  State<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends State<ProfileHubScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  bool _avatarUploading = false;
  String _username = '';
  String _displayName = '';
  String _avatarUrl = '';
  int _following = 0;
  int _followers = 0;

  SupabaseClient get _supabase => Supabase.instance.client;
  User? get _user => _supabase.auth.currentUser;
  bool get _signedIn => _user != null;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('profiles')
          .select('username,display_name,avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      final followingRows = await _supabase
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', user.id);
      final followerRows = await _supabase
          .from('user_follows')
          .select('follower_id')
          .eq('following_id', user.id);
      if (!mounted) return;
      setState(() {
        _username = data?['username']?.toString() ?? '';
        _displayName = data?['display_name']?.toString() ?? '';
        _avatarUrl = data?['avatar_url']?.toString() ?? '';
        _following = (followingRows as List).length;
        _followers = (followerRows as List).length;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil bilgileri yüklenemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final user = _user;
    if (user == null || _avatarUploading) {
      await widget.onRequestLogin();
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null || !mounted) return;

    setState(() => _avatarUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final lower = image.name.toLowerCase();
      final extension = lower.endsWith('.png')
          ? 'png'
          : lower.endsWith('.webp')
              ? 'webp'
              : 'jpg';
      final contentType = extension == 'png'
          ? 'image/png'
          : extension == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final path = '${user.id}/profile.$extension';

      await _supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
              cacheControl: '3600',
            ),
          );
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      final cacheBusted = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      await _supabase
          .from('profiles')
          .update({'avatar_url': cacheBusted}).eq('id', user.id);

      if (!mounted) return;
      setState(() => _avatarUrl = cacheBusted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil fotoğrafı yüklenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (mounted) _loadProfile();
    });
  }

  String get _name {
    if (!_signedIn) return 'Misafir';
    if (_displayName.trim().isNotEmpty) return _displayName.trim();
    if (_username.trim().isNotEmpty) return _username.trim();
    return 'B_music02 Kullanıcısı';
  }

  String get _subtitle {
    if (!_signedIn) return 'Hesapsız kullanım • Müzik modu';
    if (_username.trim().isNotEmpty) return '@${_username.trim()} • B_music02 üyesi';
    return 'B_music02 üyesi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
            children: [
              _topBar(),
              const SizedBox(height: 8),
              _identity(),
              const SizedBox(height: 18),
              _socialStats(),
              const SizedBox(height: 20),
              if (!_signedIn) ...[
                _guestCard(),
                const SizedBox(height: 10),
              ],
              if (_signedIn) ...[
                _menuTile(
                  icon: Icons.edit_rounded,
                  title: 'Profili Düzenle',
                  onTap: () => _open(const ProfileScreen()),
                ),
                const SizedBox(height: 7),
              ],
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
              if (_signedIn) ...[
                const SizedBox(height: 10),
                _menuTile(
                  icon: Icons.logout_rounded,
                  title: 'Çıkış Yap',
                  onTap: () => widget.onSignOut(),
                ),
              ],
              const SizedBox(height: 13),
              _bottomBanner(),
            ],
          ),
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
        GestureDetector(
          onTap: _signedIn ? _pickAvatar : () => widget.onRequestLogin(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 98,
                height: 98,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.neonPurple, AppColors.neonPink]),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPurple.withValues(alpha: 0.38),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _avatarUploading || _loading
                      ? const ColoredBox(
                          color: Color(0xFF161827),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPurple),
                          ),
                        )
                      : _signedIn && _avatarUrl.trim().isNotEmpty
                          ? Image.network(_avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _logo())
                          : _logo(),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 4,
                child: Container(
                  width: 29,
                  height: 29,
                  decoration: const BoxDecoration(
                    color: AppColors.neonPurple,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: AppColors.background, width: 3)),
                  ),
                  child: Icon(
                    _signedIn ? Icons.camera_alt_rounded : Icons.login_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(_name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(_subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
      ],
    );
  }

  Widget _logo() => Image.asset('assets/images/b_music02_logo.png', fit: BoxFit.cover);

  Widget _socialStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: _Stat(value: _signedIn ? '$_following' : '0', label: 'Takip')),
        Container(width: 1, height: 34, color: const Color(0xFF2A2D40)),
        Expanded(child: _Stat(value: _signedIn ? '$_followers' : '0', label: 'Takipçi')),
      ],
    );
  }

  Widget _guestCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hesabını aç', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Kullanıcıları takip etmek, takipçi edinmek ve arkadaşlarının hikâyelerini görmek için giriş yap.',
            style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.35),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onRequestLogin(),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Giriş Yap / Kayıt Ol'),
            ),
          ),
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
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
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
                  'Keşfet bölümünden kullanıcı bul, takip isteği gönder ve arkadaşlarınla bağlan.',
                  style: TextStyle(color: Colors.white70, fontSize: 9.5, height: 1.25),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.explore_rounded, size: 42, color: Color(0xFFE7A4FF)),
        ],
      ),
    );
  }

  Future<void> _about() async {
    await showDialog<void>(
      context: context,
      builder: (c) => const AlertDialog(
        title: Text('B_music02'),
        content: Text('Müzik, keşif, çevrimdışı dinleme ve sosyal bağlantıları tek yerde buluşturan B_music02 uygulaması.'),
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
        Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
