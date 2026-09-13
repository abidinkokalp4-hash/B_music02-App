import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onOpenMusic,
    required this.onOpenCommunity,
    required this.onOpenChat,
    required this.onOpenProfile,
    required this.onOpenDiscover,
    required this.onOpenInsights,
  });

  final VoidCallback onOpenMusic;
  final VoidCallback onOpenCommunity;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDiscover;
  final VoidCallback onOpenInsights;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final LocalMusicService _music = LocalMusicService.instance;
  final MusicInsightsService _insights = MusicInsightsService.instance;
  final SocialService _social = SocialService.instance;

  bool _loading = true;
  String _name = 'Müziksever';
  List<TrackInsight> _topTracks = const [];
  List<TrackInsight> _recent = const [];
  List<ListeningPresence> _presence = const [];
  List<CommunityPoll> _polls = const [];
  int _todayMinutes = 0;
  int _streak = 0;
  StreamSubscription<void>? _insightSub;

  @override
  void initState() {
    super.initState();
    _insightSub = _insights.changes.listen((_) => _loadLocalOnly());
    _load();
  }

  @override
  void dispose() {
    _insightSub?.cancel();
    super.dispose();
  }

  Future<void> _loadLocalOnly() async {
    try {
      final values = await Future.wait<dynamic>([
        _insights.topTracks(limit: 10),
        _insights.recentTracks(limit: 10),
        _insights.todayMinutes(),
        _insights.currentStreak(),
      ]);
      if (!mounted) return;
      setState(() {
        _topTracks = values[0] as List<TrackInsight>;
        _recent = values[1] as List<TrackInsight>;
        _todayMinutes = values[2] as int;
        _streak = values[3] as int;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    await _loadProfile();

    final values = await Future.wait<dynamic>([
      _insights.topTracks(limit: 10),
      _insights.recentTracks(limit: 10),
      _insights.todayMinutes(),
      _insights.currentStreak(),
      _social.loadListeningPresence().catchError((_) => <ListeningPresence>[]),
      _social.loadPolls().catchError((_) => <CommunityPoll>[]),
    ]);

    if (!mounted) return;
    setState(() {
      _topTracks = values[0] as List<TrackInsight>;
      _recent = values[1] as List<TrackInsight>;
      _todayMinutes = values[2] as int;
      _streak = values[3] as int;
      _presence = values[4] as List<ListeningPresence>;
      _polls = values[5] as List<CommunityPoll>;
      _loading = false;
    });
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('display_name, username')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        final display = row['display_name']?.toString().trim();
        final username = row['username']?.toString().trim();
        _name = display?.isNotEmpty == true
            ? display!
            : username?.isNotEmpty == true
                ? username!
                : 'Müziksever';
      }
    } catch (_) {}
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'İyi geceler';
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  MediaItem? get _currentItem {
    final tag = _music.player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.gold,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 140),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildContinueCard(),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 25),
                    _sectionHeader(
                      'Senin İçin',
                      Icons.auto_awesome_rounded,
                      widget.onOpenInsights,
                    ),
                    const SizedBox(height: 11),
                    _buildInsightCards(),
                    if (_recent.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      _sectionHeader(
                        'Son Dinlediklerin',
                        Icons.history_rounded,
                        widget.onOpenMusic,
                      ),
                      const SizedBox(height: 10),
                      _buildRecentStrip(),
                    ],
                    const SizedBox(height: 26),
                    _sectionHeader(
                      'B_music02 Top 10',
                      Icons.local_fire_department_rounded,
                      widget.onOpenInsights,
                    ),
                    const SizedBox(height: 10),
                    _buildTopTen(),
                    const SizedBox(height: 26),
                    _sectionHeader(
                      'Arkadaşların Ne Dinliyor?',
                      Icons.headphones_rounded,
                      widget.onOpenCommunity,
                    ),
                    const SizedBox(height: 10),
                    _buildPresenceStrip(),
                    const SizedBox(height: 26),
                    _sectionHeader(
                      'Toplulukta Gündem',
                      Icons.groups_rounded,
                      widget.onOpenCommunity,
                    ),
                    const SizedBox(height: 10),
                    _buildCommunityPulse(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/b_music02_logo.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting, $_name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'B_music02 • Müzik burada yaşar',
                style: TextStyle(color: AppColors.gold, fontSize: 9),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Ara ve indir',
          onPressed: widget.onOpenDiscover,
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: 'Profil',
          onPressed: widget.onOpenProfile,
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
    );
  }

  Widget _buildContinueCard() {
    return StreamBuilder<bool>(
      stream: _music.player.playingStream,
      builder: (context, snapshot) {
        final item = _currentItem;
        final playing = snapshot.data ?? _music.player.playing;
        return InkWell(
          onTap: widget.onOpenMusic,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A2910), Color(0xFF31101D), Color(0xFF121212)],
              ),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.black26,
                  ),
                  child: const Icon(
                    Icons.album_rounded,
                    color: AppColors.gold,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item == null ? 'Müziğini seç' : 'Devam Et',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item?.title ?? 'Müziklerim seni bekliyor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item?.artist ?? 'Telefondaki müziklere git',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (item != null)
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _music.togglePlayPause,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.library_music_rounded, 'Müziklerim', widget.onOpenMusic),
      (Icons.download_rounded, 'Keşfet', widget.onOpenDiscover),
      (Icons.groups_2_rounded, 'Topluluk', widget.onOpenCommunity),
      (Icons.chat_bubble_rounded, 'Sohbet', widget.onOpenChat),
    ];
    return Row(
      children: actions.map((entry) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: entry == actions.last ? 0 : 8),
            child: InkWell(
              onTap: entry.$3,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                height: 76,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(entry.$1, color: AppColors.gold, size: 21),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(
                        entry.$2,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionHeader(String title, IconData icon, VoidCallback onTap) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        TextButton(onPressed: onTap, child: const Text('Tümü')),
      ],
    );
  }

  Widget _buildInsightCards() {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            Icons.schedule_rounded,
            'Bugün',
            '$_todayMinutes dk',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _metricCard(
            Icons.local_fire_department_rounded,
            'Seri',
            '$_streak gün',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _metricCard(
            Icons.favorite_rounded,
            'Favori',
            '${_music.favoriteIds.length}',
          ),
        ),
      ],
    );
  }

  Widget _metricCard(IconData icon, String label, String value) {
    return InkWell(
      onTap: widget.onOpenInsights,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentStrip() {
    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recent.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final track = _recent[index];
          return Container(
            width: 188,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: AppColors.gold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopTen() {
    if (_topTracks.isEmpty) {
      return _emptyCard('Top 10 dinledikçe oluşacak.');
    }
    return Column(
      children: _topTracks.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final track = entry.value;
        return InkWell(
          onTap: widget.onOpenInsights,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${track.plays}×',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPresenceStrip() {
    if (_presence.isEmpty) {
      return _emptyCard('Arkadaşlarının açık dinleme durumları burada görünecek.');
    }
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _presence.take(10).length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final item = _presence[index];
          return InkWell(
            onTap: widget.onOpenCommunity,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              width: 195,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                    child: const Icon(Icons.headphones_rounded, color: AppColors.gold),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.profile?.name ?? 'Kullanıcı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.title ?? 'Müzik',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.gold, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommunityPulse() {
    if (_polls.isEmpty) {
      return _emptyCard('Topluluk anketleri ve gündem burada görünecek.');
    }
    final poll = _polls.first;
    return InkWell(
      onTap: widget.onOpenCommunity,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.poll_rounded, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Günün Sorusu',
                    style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    poll.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${poll.totalVotes} oy • Katılmak için dokun',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white38, fontSize: 10),
      ),
    );
  }
}
