import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/search_history_service.dart';
import '../../core/services/story_service.dart';
import '../../core/theme/app_theme.dart';
import '../stories/story_composer_screen.dart';
import '../stories/story_viewer_screen.dart';

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

  bool _loading = true;
  List<MusicStory> _stories = const [];
  List<SongModel> _recommendations = const [];
  List<String> _seeds = const [];
  String? _ownAvatarUrl;

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
    List<String> seeds = const [];
    String? ownAvatar;

    try {
      stories = await _storiesService.activeStories();
    } catch (_) {}

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        final value = profile?['avatar_url']?.toString().trim() ?? '';
        if (value.isNotEmpty) ownAvatar = value;
      } catch (_) {}
    }

    try {
      seeds = await _history.recent(limit: 5);
    } catch (_) {}

    final recommendations = _buildLocalRecommendations(seeds);

    if (!mounted) return;
    setState(() {
      _stories = stories;
      _recommendations = recommendations;
      _seeds = seeds;
      _ownAvatarUrl = ownAvatar;
      _loading = false;
    });
  }

  List<SongModel> _buildLocalRecommendations(List<String> seeds) {
    final songs = List<SongModel>.of(_music.songs);
    if (songs.isEmpty) return const [];

    if (seeds.isEmpty) {
      songs.shuffle();
      return songs.take(14).toList();
    }

    final scored = <({SongModel song, int score})>[];
    for (final song in songs) {
      final songTokens = _tokens('${song.title} ${song.artist ?? ''}');
      var score = 0;
      for (final seed in seeds.take(4)) {
        final seedTokens = _tokens(seed);
        score += seedTokens.where(songTokens.contains).length * 3;
      }
      if (score > 0) scored.add((song: song, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final result = scored.map((e) => e.song).take(14).toList();
    if (result.length < 8) {
      final used = result.map((e) => e.id).toSet();
      final extras = songs.where((e) => !used.contains(e.id)).toList()..shuffle();
      result.addAll(extras.take(14 - result.length));
    }
    return result;
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
        builder: (_) => StoryViewerScreen(
          stories: _stories,
          initialIndex: index,
        ),
      ),
    );
    if (mounted) await _load();
  }

  void _seekRelative(int seconds) {
    final target = _music.player.position + Duration(seconds: seconds);
    _music.seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> _contact() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'abidinkokalp4@gmail.com',
      queryParameters: {'subject': 'B_music02 İletişim'},
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta uygulaması açılamadı.')),
      );
    }
  }

  Future<void> _topMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF121420),
      builder: (c) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.mail_outline_rounded),
          title: const Text('İletişime Geç'),
          subtitle: const Text('abidinkokalp4@gmail.com'),
          onTap: () => Navigator.pop(c, 'contact'),
        ),
      ),
    );
    if (action == 'contact') await _contact();
  }

  Future<void> _playRecommendation(SongModel song) async {
    await _music.playSong(song, from: _music.songs);
  }

  Set<String> _tokens(String value) {
    const ignored = <String>{
      'official', 'video', 'audio', 'music', 'lyrics', 'lyric', 'klip',
      'feat', 'ft', 'the', 'and', 'bir', 'ile'
    };
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9çğıöşüâîû]+', unicode: true), ' ')
        .split(' ')
        .where((e) => e.length > 1 && !ignored.contains(e))
        .toSet();
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Senin İçin Öneriler',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onOpenDiscover,
                          child: const Text('Aramaya Git'),
                        ),
                      ],
                    ),
                    if (_seeds.isNotEmpty)
                      Text(
                        'Son aramalarından karışık seçildi: ${_seeds.take(3).join(' • ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9.5,
                        ),
                      ),
                    const SizedBox(height: 8),
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
              onPressed: _topMenu,
              icon: const Icon(Icons.more_horiz_rounded, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyRail() {
    return SizedBox(
      height: 92,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 4;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _stories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final signedIn = Supabase.instance.client.auth.currentUser != null;
                return SizedBox(
                  width: itemWidth,
                  child: _StoryBubble(
                    label: signedIn ? 'Hikayen' : 'Giriş Yap',
                    imageUrl: _ownAvatarUrl,
                    badge: Icons.add_rounded,
                    onTap: _newStory,
                  ),
                );
              }
              final story = _stories[index - 1];
              return SizedBox(
                width: itemWidth,
                child: _StoryBubble(
                  label: story.profileName,
                  imageUrl: story.avatarUrl,
                  onTap: () => _openStory(index - 1),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _nowPlayingCard() {
    final item = _currentItem;
    final songId = item == null ? null : int.tryParse(item.id);
    return Container(
      height: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171326), Color(0xFF241344)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF342850)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPurple.withValues(alpha: 0.12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 112,
              height: 112,
              child: songId == null
                  ? _artFallback()
                  : QueryArtworkWidget(
                      id: songId,
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      nullArtworkWidget: _artFallback(),
                      artworkBorder: BorderRadius.zero,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ŞİMDİ ÇALAN',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item?.title ?? 'Müziğini Aç',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item?.artist ?? 'B_music02',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _smallControl(
                      Icons.skip_previous_rounded,
                      item == null ? null : _music.previous,
                    ),
                    _smallControl(
                      Icons.replay_10_rounded,
                      item == null ? null : () => _seekRelative(-10),
                    ),
                    StreamBuilder<bool>(
                      stream: _music.player.playingStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? _music.player.playing;
                        return IconButton.filled(
                          onPressed: item == null
                              ? widget.onOpenMusic
                              : _music.togglePlayPause,
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        );
                      },
                    ),
                    _smallControl(
                      Icons.forward_10_rounded,
                      item == null ? null : () => _seekRelative(10),
                    ),
                    _smallControl(
                      Icons.skip_next_rounded,
                      item == null ? null : _music.next,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallControl(IconData icon, VoidCallback? action) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 34),
      onPressed: action,
      icon: Icon(icon, size: 20),
    );
  }

  Widget _recommendationList() {
    if (_recommendations.isEmpty) {
      return InkWell(
        onTap: widget.onOpenDiscover,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151724),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Telefonundaki müziklerden öneri oluşturmak için Kitaplığım bölümünü aç.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: _recommendations.take(8).map((song) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: const Color(0xFF151724),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => _playRecommendation(song),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          artworkFit: BoxFit.cover,
                          artworkBorder: BorderRadius.zero,
                          nullArtworkWidget: _artFallback(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            song.artist ?? 'Bilinmeyen sanatçı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.neonPurple,
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

  static Widget _artFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7A32E8), Color(0xFF25104E)],
        ),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 42,
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    required this.imageUrl,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String? imageUrl;
  final VoidCallback onTap;
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.neonPurple, AppColors.neonPink],
                  ),
                ),
                child: ClipOval(
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback(),
                        )
                      : _fallback(),
                ),
              ),
              if (badge != null)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.neonPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badge, size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFF21183F),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
      ),
    );
  }
}
