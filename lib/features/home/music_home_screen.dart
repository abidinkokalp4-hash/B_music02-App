import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/search_history_service.dart';
import '../../core/services/story_service.dart';
import '../../core/services/youtube_music_service.dart';
import '../../core/theme/app_theme.dart';
import '../stories/story_composer_screen.dart';
import '../stories/story_viewer_screen.dart';
import 'youtube_player_screen.dart';

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({
    super.key,
    required this.onOpenMusic,
    required this.onOpenDiscover,
    required this.onRequestLogin,
  });

  final VoidCallback onOpenMusic;
  final VoidCallback onOpenDiscover;
  final Future<void> Function() onRequestLogin;

  @override
  State<MusicHomeScreen> createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends State<MusicHomeScreen> {
  final LocalMusicService _music = LocalMusicService.instance;
  final SearchHistoryService _history = SearchHistoryService.instance;
  final StoryService _storiesService = StoryService.instance;
  final YouTubeMusicService _youtube = const YouTubeMusicService();

  bool _loading = true;
  List<MusicStory> _stories = const [];
  List<YouTubeMusicItem> _recommendations = const [];
  String? _recommendationSeed;

  @override
  void initState() {
    super.initState();
    _music.addListener(_musicChanged);
    _load();
  }

  @override
  void dispose() {
    _music.removeListener(_musicChanged);
    super.dispose();
  }

  void _musicChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    await _music.requestPermissionAndLoad(request: false);

    List<MusicStory> stories = const [];
    List<YouTubeMusicItem> recommendations = const [];
    String? seed;

    try {
      stories = await _storiesService.activeStories();
    } catch (_) {}

    try {
      seed = await _history.latest();
      if (seed != null && seed.trim().isNotEmpty) {
        final result = await _youtube.searchMusic('$seed music', maxResults: 12);
        recommendations = result.items;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _stories = stories;
      _recommendations = recommendations;
      _recommendationSeed = seed;
      _loading = false;
    });
  }

  MediaItem? get _currentItem {
    final tag = _music.player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  Future<void> _newStory() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await widget.onRequestLogin();
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryComposerScreen()),
    );
    if (created == true) await _load();
  }

  Future<void> _openStory(int index) async {
    if (_stories.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(stories: _stories, initialIndex: index),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openRecommendation(YouTubeMusicItem item) async {
    await _music.pause();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => YouTubePlayerScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.neonPurple,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.neonPurple),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
                  children: [
                    _topBar(),
                    const SizedBox(height: 14),
                    _storyRail(),
                    const SizedBox(height: 16),
                    _nowPlayingCard(),
                    const SizedBox(height: 18),
                    _sectionTitle('Önerilen Albümler', action: 'Aramaya Git'),
                    const SizedBox(height: 10),
                    _albumRail(),
                    const SizedBox(height: 18),
                    _sectionTitle('Senin İçin Öneriler', action: 'Tümünü Gör'),
                    const SizedBox(height: 6),
                    _recommendationList(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Center(
            child: Text(
              'Ana Sayfa',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              onPressed: _load,
              icon: const Icon(Icons.notifications_none_rounded, size: 25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyRail() {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          if (index == 0) {
            final signedIn = Supabase.instance.client.auth.currentUser != null;
            return _StoryBubble(
              label: signedIn ? 'Hikayen' : 'Giriş Yap',
              highlighted: true,
              imageUrl: null,
              fallback: Image.asset('assets/images/b_music02_logo.png', fit: BoxFit.cover),
              badge: Icons.add_rounded,
              onTap: _newStory,
            );
          }
          final story = _stories[index - 1];
          return _StoryBubble(
            label: story.profileName,
            highlighted: true,
            imageUrl: story.avatarUrl.isNotEmpty ? story.avatarUrl : story.thumbnailUrl,
            fallback: const Icon(Icons.music_note_rounded, color: Colors.white),
            onTap: () => _openStory(index - 1),
          );
        },
      ),
    );
  }

  Widget _nowPlayingCard() {
    final item = _currentItem;
    final songId = item == null ? null : int.tryParse(item.id);

    return Container(
      height: 146,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2D48)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPurple.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (songId != null)
            QueryArtworkWidget(
              id: songId,
              type: ArtworkType.AUDIO,
              artworkFit: BoxFit.cover,
              nullArtworkWidget: _heroFallback(),
              artworkBorder: BorderRadius.zero,
            )
          else
            _heroFallback(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xED111022), Color(0xB5120D2D), Color(0x5A210F4B)],
              ),
            ),
          ),
          Positioned(
            right: 54,
            top: 14,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.neonPink, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonPurple.withValues(alpha: 0.70),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 18,
            right: 126,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ŞİMDİ ÇALAN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item?.title ?? 'Müziğini Aç',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  item?.artist ?? 'B_music02',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70),
              ),
              child: StreamBuilder<bool>(
                stream: _music.player.playingStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? _music.player.playing;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: item == null ? widget.onOpenMusic : _music.togglePlayPause,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? action}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (_recommendationSeed != null)
                Text(
                  '“$_recommendationSeed” aramana göre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5),
                ),
            ],
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: widget.onOpenDiscover,
            child: Text(
              action,
              style: const TextStyle(
                color: AppColors.neonPurple,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _albumRail() {
    if (_recommendations.isEmpty) return _noRecommendations();
    final items = _recommendations.take(3).toList();
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 118,
            child: InkWell(
              onTap: () => _openRecommendation(item),
              borderRadius: BorderRadius.circular(13),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _albumFallback(index),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xE6000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 9,
                      right: 9,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            item.channelTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _recommendationList() {
    if (_recommendations.isEmpty) return _noRecommendations();
    final items = _recommendations.skip(3).take(5).toList();
    return Column(
      children: items.map((item) {
        return InkWell(
          onTap: () => _openRecommendation(item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.thumbnailUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => SizedBox(
                      width: 44,
                      height: 44,
                      child: _albumFallback(0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _noRecommendations() {
    return InkWell(
      onTap: widget.onOpenDiscover,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151724),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.neonPurple),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                'Arama bölümünde birkaç sanatçı veya şarkı ara. Öneriler burada aramalarına göre oluşacak.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _heroFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF150C34), Color(0xFF5D0D8D), Color(0xFF11142E)],
        ),
      ),
    );
  }

  static Widget _albumFallback(int index) {
    const gradients = [
      [Color(0xFFFF4BB8), Color(0xFF5C1DFF)],
      [Color(0xFF347BFF), Color(0xFF0D173C)],
      [Color(0xFF8738FF), Color(0xFF0D1236)],
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradients[index % gradients.length],
        ),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white70),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    required this.highlighted,
    required this.imageUrl,
    required this.fallback,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool highlighted;
  final String? imageUrl;
  final Widget fallback;
  final VoidCallback onTap;
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 63,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 57,
                  height: 57,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: highlighted
                        ? const LinearGradient(
                            colors: [AppColors.neonPurple, AppColors.neonPink],
                          )
                        : null,
                    border: highlighted
                        ? null
                        : Border.all(color: const Color(0xFF55586A), width: 1.2),
                    boxShadow: highlighted
                        ? [
                            BoxShadow(
                              color: AppColors.neonPurple.withValues(alpha: 0.38),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => fallback,
                          )
                        : fallback,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 21,
                      height: 21,
                      decoration: const BoxDecoration(
                        color: AppColors.neonPurple,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppColors.background, width: 2),
                        ),
                      ),
                      child: Icon(badge, color: Colors.white, size: 15),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9.3, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
