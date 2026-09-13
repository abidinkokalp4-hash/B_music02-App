import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/session_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../onboarding/permissions_screen.dart';
import 'legal_documents_screen.dart';
import 'moderation_center_screen.dart';
import 'safety_center_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _showListening = true;
  bool _keepSignedIn = true;
  bool _isModerator = false;
  bool _deletingAccount = false;
  String _dmPrivacy = 'everyone';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final keep = await SessionPreferences.keepSignedIn();
    final user = _supabase.auth.currentUser;
    bool listening = true;
    String dmPrivacy = 'everyone';
    bool isModerator = false;

    if (user != null) {
      try {
        final row = await _supabase
            .from('profiles')
            .select('show_listening_status, dm_privacy, app_role')
            .eq('id', user.id)
            .single();
        listening = row['show_listening_status'] != false;
        dmPrivacy = row['dm_privacy']?.toString() ?? 'everyone';
        final role = row['app_role']?.toString() ?? 'user';
        isModerator = role == 'admin' || role == 'moderator';
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _keepSignedIn = keep;
      _showListening = listening;
      _dmPrivacy = dmPrivacy;
      _isModerator = isModerator;
      _loading = false;
    });
  }

  Future<void> _updateProfile(Map<String, dynamic> values) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('profiles').update(values).eq('id', user.id);
  }

  Future<void> _setListening(bool value) async {
    setState(() => _showListening = value);
    try {
      await _updateProfile({'show_listening_status': value});
    } catch (_) {
      if (mounted) setState(() => _showListening = !value);
    }
  }

  Future<void> _setDmPrivacy(String value) async {
    final previous = _dmPrivacy;
    setState(() => _dmPrivacy = value);
    try {
      await _updateProfile({'dm_privacy': value});
    } catch (_) {
      if (mounted) setState(() => _dmPrivacy = previous);
    }
  }

  Future<void> _setKeepSignedIn(bool value) async {
    setState(() => _keepSignedIn = value);
    await SessionPreferences.setKeepSignedIn(value);
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabı kalıcı olarak sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu işlem geri alınamaz. Profilin, sosyal verilerin ve hesabına bağlı kullanıcı yüklemelerin kalıcı olarak silinir.',
            ),
            const SizedBox(height: 14),
            const Text('Devam etmek için aşağıya SİL yaz:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'SİL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(
                dialogContext,
                controller.text.trim().toUpperCase() == 'SİL',
              );
            },
            child: const Text('Hesabımı Sil'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (confirmed != true) return;
    setState(() => _deletingAccount = true);

    try {
      final response = await _supabase.functions.invoke('delete-account');
      final data = response.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) throw StateError('delete_failed');

      await SessionPreferences.setKeepSignedIn(false);
      try {
        await _supabase.auth.signOut();
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesabın kalıcı olarak silindi.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesap silinemedi. İnternet bağlantını kontrol edip tekrar dene.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar ve Gizlilik')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
              children: [
                _section('İzinler', Icons.verified_user_rounded),
                const SizedBox(height: 8),
                _tile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'İzinler ve Gizlilik',
                  subtitle: 'Müzik, bildirim, kamera ve mikrofon izinlarını yönet.',
                  onTap: () => _open(const PermissionsCenterScreen()),
                ),
                const SizedBox(height: 22),
                _section('Hesap', Icons.account_circle_rounded),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _keepSignedIn,
                  onChanged: _setKeepSignedIn,
                  secondary: const Icon(Icons.login_rounded, color: AppColors.gold),
                  title: const Text('Oturumumu açık tut'),
                  subtitle: const Text(
                    'Açıksa uygulamayı yeniden açtığında tekrar şifre istemez.',
                  ),
                ),
                const SizedBox(height: 8),
                _tile(
                  icon: Icons.shield_rounded,
                  title: 'Güvenlik Merkezi',
                  subtitle: 'Kullanıcı bildir, engellediklerini gör veya engeli kaldır.',
                  onTap: () => _open(const SafetyCenterScreen()),
                ),
                const SizedBox(height: 12),
                _section('Sosyal Gizlilik', Icons.shield_outlined),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _showListening,
                  onChanged: _setListening,
                  secondary: const Icon(Icons.headphones_rounded, color: AppColors.gold),
                  title: const Text('Dinlediğim müziği göster'),
                  subtitle: const Text(
                    'Kapalıysa diğer kullanıcılar şu an ne dinlediğini göremez.',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_chat_unread_rounded, color: AppColors.gold),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kim özel mesaj gönderebilir?',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Mesaj gizliliğini hesabına göre ayarla.',
                              style: TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: _dmPrivacy,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'everyone', child: Text('Herkes')),
                          DropdownMenuItem(value: 'following', child: Text('Takip')),
                          DropdownMenuItem(value: 'nobody', child: Text('Hiç kimse')),
                        ],
                        onChanged: (value) {
                          if (value != null) _setDmPrivacy(value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _section('Yasal ve Topluluk', Icons.policy_rounded),
                const SizedBox(height: 8),
                _tile(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Gizlilik Politikası',
                  subtitle: 'Hangi verilerin neden işlendiğini gör.',
                  onTap: () => _open(const PrivacyPolicyScreen()),
                ),
                const SizedBox(height: 8),
                _tile(
                  icon: Icons.gavel_rounded,
                  title: 'Kullanım Koşulları',
                  subtitle: 'Uygulamayı kullanırken geçerli kuralları gör.',
                  onTap: () => _open(const TermsOfUseScreen()),
                ),
                const SizedBox(height: 8),
                _tile(
                  icon: Icons.groups_2_rounded,
                  title: 'Topluluk Kuralları',
                  subtitle: 'Paylaşım, sohbet ve telif kurallarını gör.',
                  onTap: () => _open(const CommunityGuidelinesScreen()),
                ),
                if (_isModerator) ...[
                  const SizedBox(height: 22),
                  _section('Yönetici', Icons.admin_panel_settings_rounded),
                  const SizedBox(height: 8),
                  _tile(
                    icon: Icons.rule_folder_rounded,
                    title: 'Moderasyon Merkezi',
                    subtitle: 'Şikâyetleri incele, içerik kaldır ve hesapları yönet.',
                    onTap: () => _open(const ModerationCenterScreen()),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.14)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_rounded, color: AppColors.gold, size: 19),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'B_music02 şifreni cihazda düz metin olarak saklamaz. Oturum tercihi Supabase güvenli oturum mekanizmasıyla çalışır.',
                          style: TextStyle(fontSize: 10, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _section('Tehlikeli Alan', Icons.warning_amber_rounded),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  tileColor: Colors.red.withValues(alpha: 0.08),
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Hesabımı Sil',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'Hesabını ve hesabına bağlı kullanıcı verilerini kalıcı olarak sil.',
                    style: TextStyle(fontSize: 10),
                  ),
                  trailing: _deletingAccount
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded, color: Colors.redAccent),
                  onTap: _deletingAccount ? null : _deleteAccount,
                ),
              ],
            ),
    );
  }

  Widget _section(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 18),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: Theme.of(context).colorScheme.surface,
      leading: Icon(icon, color: AppColors.gold),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
