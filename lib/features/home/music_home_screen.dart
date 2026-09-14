import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/theme/app_theme.dart';

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({
    super.key,
    required this.onOpenMusic,
    required this.onOpenDiscover,
  });

  final VoidCallback onOpenMusic;
  final VoidCallback onOpenDiscover;

  @override
  State<MusicHomeScreen> createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends State<MusicHomeScreen> {
  final LocalMusicService _music = LocalMusicService.instance;
  final MusicInsightsService _insights = MusicInsightsService.instance;

  bool _loading = true;
  List<TrackInsight> _recent = const [];
  List<TrackInsight> _top = const [];
  StreamSubscription<void>? _insightSub;

  @override
  void initState() {
    super.initState();
    _music.addListener(_musicChanged);
    _insightSub = _insights.changes.listen((_) => _loadStats());
    _load();
  }

  @override
  void dispose() {
    _music.removeListener(_musicChanged);
    _insightSub?.cancel();
    super.dispose();
  }

  void _musicChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    await _music.requestPermissionAndLoad(request: false);
    await _loadStats();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadStats() async {
    final values = await Future.wait<dynamic>([
      _insights.recentTracks(limit: 8),
      _insights.topTracks(limit: 8),
    ]);
    if (!mounted) return;
    setState(() {
      _recent = values[0] as List<TrackInsight>;
      _top = values[1] as List<TrackInsight>;
    });
  }

  MediaItem? get _currentItem {
    final tag = _music.player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  SongModel? _songForInsight(TrackInsight item) {
    final id = int.tryParse(item.id);
    if (id == null) return null;
    for (final song in _music.songs) {
      if (song.id == id) return song;
    }
    return null;
  }

  Future<void> _playInsight(TrackInsight item) async {
    final song = _songForInsight(item);
    if (song != null) await _music.playSong(song);
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
                    _moodRail(),
                    const SizedBox(height: 16),
                    _nowPlayingCard(),
                    const SizedBox(height: 18),
                    _sectionTitle('Önerilen Albümler', action: 'Tümünü Gör'),
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
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded, size: 25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodRail() {
    const labels = ['Keşfet', 'Gece Modu', 'Focus', 'Hiphop'];
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = index < _music.songs.length ? _music.songs[index] : null;
          return _MoodBubble(
            label: labels[index],
            song: song,
            highlighted: index == 0,
            onTap: widget.onOpenDiscover,
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
                colors: [
                  Color(0xED111022),
                  Color(0xB5120D2D),
                  Color(0x5A210F4B),
                ],
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
                    onPressed: item == null
                        ? widget.onOpenMusic
                        : _music.togglePlayPause,
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
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: widget.onOpenMusic,
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
    final songs = _music.songs.take(3).toList();
    if (songs.isEmpty) {
      return SizedBox(
        height: 108,
        child: Row(
          children: const [
            Expanded(child: _EmptyAlbum(label: 'Müziklerim')),
            SizedBox(width: 10),
            Expanded(child: _EmptyAlbum(label: 'Favoriler')),
            SizedBox(width: 10),
            Expanded(child: _EmptyAlbum(label: 'Listeler')),
          ],
        ),
      );
    }

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final song = songs[index];
          return SizedBox(
            width: 112,
            child: InkWell(
              onTap: () => _music.playSong(song),
              borderRadius: BorderRadius.circular(13),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    QueryArtworkWidget(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      nullArtworkWidget: _albumFallback(index),
                      artworkBorder: BorderRadius.zero,
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
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            song.artist ?? 'B_music02',
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
    final items = _top.isNotEmpty ? _top.take(4).toList() : _recent.take(4).toList();
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'Dinledikçe burada sana özel öneriler oluşacak.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        final song = _songForInsight(item);
        return InkWell(
          onTap: () => _playInsight(item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: song == null
                        ? _albumFallback(0)
                        : QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: _albumFallback(0),
                            artworkBorder: BorderRadius.zero,
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
                        item.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
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
    final colors = gradients[index % gradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white70),
    );
  }
}

class _MoodBubble extends StatelessWidget {
  const _MoodBubble({
    required this.label,
    required this.song,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final SongModel? song;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
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
                          color: AppColors.neonPurple.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: song == null
                    ? Container(
                        color: const Color(0xFF17192B),
                        child: const Icon(Icons.music_note_rounded, color: Colors.white70),
                      )
                    : QueryArtworkWidget(
                        id: song!.id,
                        type: ArtworkType.AUDIO,
                        artworkFit: BoxFit.cover,
                        nullArtworkWidget: Container(
                          color: const Color(0xFF17192B),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white70),
                        ),
                        artworkBorder: BorderRadius.zero,
                      ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9.5, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlbum extends StatelessWidget {
  const _EmptyAlbum({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB62EFF), Color(0xFF171834)],
        ),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(9),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}
