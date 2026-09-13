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
  int _todayMinutes = 0;
  int _streak = 0;
  List<TrackInsight> _recent = const [];
  List<TrackInsight> _top = const [];
  StreamSubscription<void>? _insightsSub;

  @override
  void initState() {
    super.initState();
    _music.addListener(_onMusicChanged);
    _insightsSub = _insights.changes.listen((_) => _loadStats());
    _load();
  }

  @override
  void dispose() {
    _music.removeListener(_onMusicChanged);
    _insightsSub?.cancel();
    super.dispose();
  }

  void _onMusicChanged() {
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
      _insights.todayMinutes(),
      _insights.currentStreak(),
      _insights.recentTracks(limit: 10),
      _insights.topTracks(limit: 8),
    ]);
    if (!mounted) return;
    setState(() {
      _todayMinutes = values[0] as int;
      _streak = values[1] as int;
      _recent = values[2] as List<TrackInsight>;
      _top = values[3] as List<TrackInsight>;
    });
  }

  MediaItem? get _currentItem {
    final tag = _music.player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  SongModel? _songForInsight(TrackInsight insight) {
    final id = int.tryParse(insight.id);
    if (id == null) return null;
    for (final song in _music.songs) {
      if (song.id == id) return song;
    }
    return null;
  }

  Future<void> _playInsight(TrackInsight insight) async {
    final song = _songForInsight(insight);
    if (song == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu parça artık telefonda bulunmuyor.')),
      );
      return;
    }
    await _music.playSong(song);
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
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 170),
                  children: [
                    _heroHeader(),
                    const SizedBox(height: 24),
                    _nowPlayingHero(),
                    const SizedBox(height: 18),
                    _libraryStrip(),
                    if (_recent.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      _sectionHeader(
                        eyebrow: 'GERİ DÖN',
                        title: 'Son dinlediklerin',
                        action: 'Tümü',
                        onTap: widget.onOpenMusic,
                      ),
                      const SizedBox(height: 14),
                      _recentRail(),
                    ],
                    if (_top.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      _sectionHeader(
                        eyebrow: 'SANA ÖZEL',
                        title: 'En çok çalanlar',
                      ),
                      const SizedBox(height: 10),
                      ..._top.take(6).toList().asMap().entries.map(
                            (entry) => _rankedTrack(entry.key + 1, entry.value),
                          ),
                    ],
                    const SizedBox(height: 26),
                    _discoverBanner(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _heroHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? 'Gece modu'
        : hour < 12
            ? 'Günaydın'
            : hour < 18
                ? 'İyi günler'
                : 'İyi akşamlar';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/b_music02_logo.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accentSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'B_music02',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        _RoundAction(
          icon: Icons.search_rounded,
          tooltip: 'Keşfet',
          onTap: widget.onOpenDiscover,
        ),
      ],
    );
  }

  Widget _nowPlayingHero() {
    final item = _currentItem;
    final songId = item == null ? null : int.tryParse(item.id);

    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.accentSoft,
                size: 29,
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Kendi sesini aç.',
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Telefondaki müziklerini tek yerde dinle, favorile ve listelerini oluştur.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: widget.onOpenMusic,
              icon: const Icon(Icons.library_music_rounded),
              label: const Text('Müziklerimi Aç'),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: widget.onOpenMusic,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: AspectRatio(
                aspectRatio: 1.62,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    songId == null
                        ? _artFallback()
                        : QueryArtworkWidget(
                            id: songId,
                            type: ArtworkType.AUDIO,
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: _artFallback(),
                            artworkBorder: BorderRadius.zero,
                          ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xD9000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'ŞİMDİ ÇALIYOR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 86,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.artist ?? 'Bilinmeyen sanatçı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: StreamBuilder<bool>(
                        stream: _music.player.playingStream,
                        builder: (context, snapshot) {
                          final playing = snapshot.data ?? _music.player.playing;
                          return Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _music.togglePlayPause,
                              icon: Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 29,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _libraryStrip() {
    return Row(
      children: [
        Expanded(
          child: _MetricPill(
            icon: Icons.library_music_rounded,
            value: '${_music.songs.length}',
            label: 'Şarkı',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _MetricPill(
            icon: Icons.favorite_rounded,
            value: '${_music.favoriteSongs.length}',
            label: 'Favori',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _MetricPill(
            icon: Icons.schedule_rounded,
            value: '$_todayMinutes',
            label: 'Dakika',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _MetricPill(
            icon: Icons.local_fire_department_rounded,
            value: '$_streak',
            label: 'Seri',
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String eyebrow,
    required String title,
    String? action,
    VoidCallback? onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppColors.accentSoft,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            child: Text(action),
          ),
      ],
    );
  }

  Widget _recentRail() {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recent.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final insight = _recent[index];
          final song = _songForInsight(insight);
          return SizedBox(
            width: 122,
            child: InkWell(
              onTap: () => _playInsight(insight),
              borderRadius: BorderRadius.circular(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: SizedBox(
                      width: 122,
                      height: 122,
                      child: song == null
                          ? _artFallback()
                          : QueryArtworkWidget(
                              id: song.id,
                              type: ArtworkType.AUDIO,
                              artworkFit: BoxFit.cover,
                              nullArtworkWidget: _artFallback(),
                              artworkBorder: BorderRadius.zero,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insight.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    insight.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 9,
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

  Widget _rankedTrack(int rank, TrackInsight item) {
    final song = _songForInsight(item);

    return InkWell(
      onTap: () => _playInsight(item),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                rank.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: rank <= 3 ? AppColors.accentSoft : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 48,
                height: 48,
                child: song == null
                    ? _artFallback()
                    : QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        artworkFit: BoxFit.cover,
                        nullArtworkWidget: _artFallback(),
                        artworkBorder: BorderRadius.zero,
                      ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.artist} • ${item.plays} kez',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow_rounded, color: AppColors.accentSoft),
          ],
        ),
      ),
    );
  }

  Widget _discoverBanner() {
    return InkWell(
      onTap: widget.onOpenDiscover,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.26)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.travel_explore_rounded, color: AppColors.accentSoft),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni bir şey bul',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'YouTube araması ve indirilebilir müzik keşfi.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.accentSoft),
          ],
        ),
      ),
    );
  }

  static Widget _artFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF312E81)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white, size: 34),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceAlt,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 21),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: AppColors.accentSoft),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
