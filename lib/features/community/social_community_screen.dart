import 'package:flutter/material.dart';

import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

class SocialCommunityScreen extends StatefulWidget {
  const SocialCommunityScreen({super.key});

  @override
  State<SocialCommunityScreen> createState() => _SocialCommunityScreenState();
}

class _SocialCommunityScreenState extends State<SocialCommunityScreen> {
  final SocialService _social = SocialService.instance;

  bool _loading = true;
  List<CommunityPoll> _polls = const [];
  List<ListeningPresence> _presence = const [];
  List<SocialProfile> _profiles = const [];
  Set<String> _following = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        _social.loadPolls(),
        _social.loadListeningPresence(),
        _social.loadProfiles(),
        _social.loadFollowingIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _polls = values[0] as List<CommunityPoll>;
        _presence = values[1] as List<ListeningPresence>;
        _profiles = values[2] as List<SocialProfile>;
        _following = values[3] as Set<String>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sosyal alan yüklenemedi: $error')),
      );
    }
  }

  Future<void> _toggleFollow(SocialProfile profile) async {
    try {
      final following = await _social.toggleFollow(profile.id);
      if (!mounted) return;
      setState(() {
        if (following) {
          _following.add(profile.id);
        } else {
          _following.remove(profile.id);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip işlemi tamamlanamadı.')),
      );
    }
  }

  Future<void> _createPoll() async {
    final question = TextEditingController();
    final first = TextEditingController();
    final second = TextEditingController();
    final third = TextEditingController();

    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Yeni anket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: question,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Soru',
                    prefixIcon: Icon(Icons.poll_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: first,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: '1. seçenek'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: second,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: '2. seçenek'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: third,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: '3. seçenek (isteğe bağlı)',
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
              child: const Text('Yayınla'),
            ),
          ],
        );
      },
    );

    if (create == true) {
      try {
        await _social.createPoll(
          question.text,
          [first.text, second.text, third.text],
        );
        await _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Soru ve en az iki seçenek girin.'),
            ),
          );
        }
      }
    }

    question.dispose();
    first.dispose();
    second.dispose();
    third.dispose();
  }

  Future<void> _vote(CommunityPoll poll, PollOption option) async {
    await _social.vote(poll.id, option.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.gold,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
                  children: [
                    _header(),
                    const SizedBox(height: 22),
                    _sectionTitle(
                      'Şu an ne dinleniyor?',
                      Icons.graphic_eq_rounded,
                    ),
                    const SizedBox(height: 10),
                    _listeningStrip(),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: _sectionTitle(
                            'Topluluk anketleri',
                            Icons.poll_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Anket oluştur',
                          onPressed: _createPoll,
                          icon: const Icon(
                            Icons.add_circle_rounded,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_polls.isEmpty)
                      _emptyCard(
                        'Henüz anket yok',
                        'İlk topluluk anketini sen oluşturabilirsin.',
                      )
                    else
                      ..._polls.map(_pollCard),
                    const SizedBox(height: 24),
                    _sectionTitle('Müzik insanları', Icons.people_alt_rounded),
                    const SizedBox(height: 10),
                    ..._profiles
                        .where((profile) => profile.id != _social.user?.id)
                        .take(12)
                        .map(_profileTile),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.gold, AppColors.burgundy],
            ),
          ),
          child: const Icon(Icons.groups_2_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sosyal Topluluk',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 2),
              Text(
                'Anket • Takip • Dinleme durumu',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 19),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _listeningStrip() {
    if (_presence.isEmpty) {
      return _emptyCard(
        'Henüz canlı dinleme yok',
        'Müzik açıldığında izin veren kullanıcıların dinleme durumu burada görünür.',
      );
    }

    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _presence.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _presence[index];
          return Container(
            width: 185,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: item.isPlaying
                    ? AppColors.gold.withValues(alpha: 0.35)
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                      child: Text(
                        (item.profile?.name ?? '?').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.profile?.name ?? 'Kullanıcı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(
                      item.isPlaying
                          ? Icons.graphic_eq_rounded
                          : Icons.pause_circle_outline_rounded,
                      color: item.isPlaying ? AppColors.gold : Colors.white38,
                      size: 19,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.title ?? 'Müzik',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  item.artist ?? 'Bilinmeyen sanatçı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _pollCard(CommunityPoll poll) {
    final total = poll.totalVotes;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...poll.options.map((option) {
            final selected = poll.selectedOptionId == option.id;
            final ratio = total == 0 ? 0.0 : option.votes / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _vote(poll, option),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: selected
                        ? AppColors.gold.withValues(alpha: 0.13)
                        : Colors.white.withValues(alpha: 0.025),
                    border: Border.all(
                      color: selected
                          ? AppColors.gold
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected ? AppColors.gold : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${(ratio * 100).round()}%',
                        style: TextStyle(
                          color: selected ? AppColors.gold : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Text(
            '$total oy',
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _profileTile(SocialProfile profile) {
    final following = _following.contains(profile.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: AppColors.gold.withValues(alpha: 0.12),
            backgroundImage: profile.avatarUrl?.trim().isNotEmpty == true
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl?.trim().isNotEmpty == true
                ? null
                : Text(
                    profile.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${profile.username}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => _toggleFollow(profile),
            child: Text(following ? 'Takipte' : 'Takip Et'),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
