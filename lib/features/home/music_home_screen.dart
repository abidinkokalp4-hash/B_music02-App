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
      _insights.recentTracks(limit: 8),
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
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 130),
                  children: [
                    _header(),
                    const SizedBox(height: 22),
                    _nowPlaying(),
                    const SizedBox(height: 18),
                    _quickActions(),
                    const SizedBox(height: 24),
                    _stats(),
                    if (_recent.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      _sectionTitle('Son Dinlediklerin', Icons.history_rounded),
                      const SizedBox(height: 10),
                      ..._recent.map(_trackTile),
                    ],
                    if (_top.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      _sectionTitle('En Çok Dinlediklerin', Icons.bar_chart_rounded),
                      const SizedBox(height: 10),
                      ..._top.take(5).map(_topTile),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/b_music02_logo.png',
            width: 46,
            height: 46,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'B_music02',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 2),
              Text(
                'Müziğin, listelerin, keşiflerin',
                style: TextStyle(color: AppColors.gold, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Keşfet',
          onPressed: widget.onOpenDiscover,
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
  }

  Widget _nowPlaying() {
    final item = _currentItem;
    if (item == null) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const CircleAvatar(
            backgroundColor: AppColors.gold,
            child: Icon(Icons.music_note_rounded, color: Colors.black),
          ),
          title: const Text('Müziklerini aç', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('Telefondaki parçaları dinlemeye başla.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: widget.onOpenMusic,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: AppColors.gold),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: InkWell(
                onTap: widget.onOpenMusic,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Şimdi Çalıyor',
                      style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      item.artist ?? 'Bilinmeyen sanatçı',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _music.togglePlayPause,
              icon: Icon(
                _music.player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.library_music_rounded,
            label: 'Müziklerim',
            onTap: widget.onOpenMusic,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.favorite_rounded,
            label: '${_music.favoriteSongs.length} Favori',
            onTap: widget.onOpenMusic,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.explore_rounded,
            label: 'Keşfet',
            onTap: widget.onOpenDiscover,
          ),
        ),
      ],
    );
  }

  Widget _stats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${_music.songs.length}',
            label: 'Şarkı',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '${_music.playlists.length}',
            label: 'Liste',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '$_todayMinutes dk',
            label: 'Bugün',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '$_streak',
            label: 'Seri',
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.gold),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _trackTile(TrackInsight item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0x181D1D1D),
        child: Icon(Icons.music_note_rounded, color: AppColors.gold),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.play_arrow_rounded),
      onTap: () => _playInsight(item),
    );
  }

  Widget _topTile(TrackInsight item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.gold.withValues(alpha: 0.12),
        child: Text(
          '${item.plays}',
          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900),
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _playInsight(item),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: AppColors.gold),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
