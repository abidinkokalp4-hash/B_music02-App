import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SocialService _social = SocialService.instance;

  bool _loading = true;
  List<SocialProfile> _profiles = const [];
  List<Map<String, dynamic>> _blocks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final profiles = await _social.loadProfiles();
      final user = _supabase.auth.currentUser;
      List<Map<String, dynamic>> blocks = const [];
      if (user != null) {
        final rows = await _supabase
            .from('user_blocks')
            .select('blocked_id, created_at')
            .eq('blocker_id', user.id)
            .order('created_at', ascending: false);
        blocks = rows
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _blocks = blocks;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  SocialProfile? _profile(String id) {
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Future<void> _reportUser() async {
    final me = _supabase.auth.currentUser;
    if (me == null) return;

    SocialProfile? selected;
    String reason = 'Taciz veya zorbalık';
    final details = TextEditingController();

    final candidates = _profiles.where((profile) => profile.id != me.id).toList();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Kullanıcı bildir'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Kullanıcı'),
                      items: candidates
                          .map(
                            (profile) => DropdownMenuItem(
                              value: profile.id,
                              child: Text('@${profile.username}'),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        selected = id == null ? null : _profile(id);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: reason,
                      decoration: const InputDecoration(labelText: 'Neden'),
                      items: const [
                        DropdownMenuItem(value: 'Taciz veya zorbalık', child: Text('Taciz veya zorbalık')),
                        DropdownMenuItem(value: 'Spam veya dolandırıcılık', child: Text('Spam veya dolandırıcılık')),
                        DropdownMenuItem(value: 'Nefret söylemi', child: Text('Nefret söylemi')),
                        DropdownMenuItem(value: 'Uygunsuz içerik', child: Text('Uygunsuz içerik')),
                        DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => reason = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: details,
                      maxLength: 500,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama (isteğe bağlı)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Bildir'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submit == true && selected != null) {
      try {
        await _supabase.from('user_reports').insert({
          'reporter_id': me.id,
          'reported_user_id': selected!.id,
          'reason': reason,
          'details': details.text.trim().isEmpty ? null : details.text.trim(),
          'status': 'open',
        });
        _message('Bildirimin alındı. Moderasyon ekibi inceleyecek.');
      } catch (_) {
        _message('Bu kullanıcı için açık bir bildirimin zaten olabilir.');
      }
    }
    details.dispose();
  }

  Future<void> _unblock(String blockedId) async {
    final me = _supabase.auth.currentUser;
    if (me == null) return;
    await _supabase
        .from('user_blocks')
        .delete()
        .eq('blocker_id', me.id)
        .eq('blocked_id', blockedId);
    await _load();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Güvenlik Merkezi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_rounded, color: AppColors.gold),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Taciz, spam, dolandırıcılık, nefret söylemi veya uygunsuz içerikleri buradan bildirebilirsin. Sohbet ve topluluk içeriklerinde bulunan Şikâyet Et seçeneğini de kullanabilirsin.',
                          style: TextStyle(fontSize: 11, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _reportUser,
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Kullanıcı Bildir'),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Engellediğin kullanıcılar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (_blocks.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.check_circle_rounded, color: AppColors.gold),
                    title: Text('Engellenen kullanıcı yok'),
                  )
                else
                  ..._blocks.map((row) {
                    final id = row['blocked_id']?.toString() ?? '';
                    final profile = _profile(id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                        child: Text(
                          (profile?.name ?? '?').characters.first.toUpperCase(),
                          style: const TextStyle(color: AppColors.gold),
                        ),
                      ),
                      title: Text(profile?.name ?? 'Kullanıcı'),
                      subtitle: Text(profile == null ? id : '@${profile.username}'),
                      trailing: TextButton(
                        onPressed: () => _unblock(id),
                        child: const Text('Engeli kaldır'),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
