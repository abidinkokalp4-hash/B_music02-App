import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/theme/app_theme.dart';

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({
    super.key,
    required this.onOpenMusic,
    required this.onOpenDiscover,
    required this.onRequestLogin,
  });
  final VoidCallback onOpenMusic, onOpenDiscover;
  final Future<void> Function() onRequestLogin;
  @override
  State<MusicHomeScreen> createState() => _Home();
}

class _Home extends State<MusicHomeScreen> {
  final m = LocalMusicService.instance;
  final insights = MusicInsightsService.instance;
  StreamSubscription<void>? insightSub;
  StreamSubscription<int?>? indexSub;
  List<SongModel> recent = [], top = [];
  @override
  void initState() {
    super.initState();
    m.addListener(changed);
    insightSub = insights.changes.listen((_) => history());
    indexSub = m.player.currentIndexStream.listen((_) => changed());
    load();
  }

  @override
  void dispose() {
    m.removeListener(changed);
    insightSub?.cancel();
    indexSub?.cancel();
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> load() async {
    await m.requestPermissionAndLoad(request: false);
    await history();
  }

  Future<void> history() async {
    final r = await insights.recentTracks(limit: 40);
    final t = await insights.topTracks(limit: 100);
    final byId = {for (final s in m.songs) s.id.toString(): s};
    if (mounted)
      setState(() {
        recent = r.map((x) => byId[x.id]).whereType<SongModel>().toList();
        top = t.map((x) => byId[x.id]).whereType<SongModel>().toList();
      });
  }

  MediaItem? get item {
    final tag = m.player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  SongModel? get song {
    for (final s in m.songs) {
      if (s.id.toString() == item?.id) return s;
    }
    return null;
  }

  Future<void> contact() async {
    try {
      final ok = await launchUrl(
        Uri(
          scheme: 'mailto',
          path: 'abidinkokalp4@gmail.com',
          queryParameters: {'subject': 'B_music02 İletişim'},
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw StateError('mail');
    } catch (_) {
      if (mounted)
        showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('İletişim'),
            content: const SelectableText('abidinkokalp4@gmail.com'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
    }
  }

  void all(String title, List<SongModel> songs) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(children: songs.map((s) => songTile(s, songs)).toList()),
      ),
    ),
  );
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/b_music02_logo.png',
                  width: 44,
                  height: 48,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'B_music02',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Müzik ve video her zaman seninle',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Menü',
                  onSelected: (_) => contact(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'contact',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mail_outline, color: AppColors.neonPink),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('İletişim'),
                              Text(
                                'abidinkokalp4@gmail.com',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            now(),
            const SizedBox(height: 22),
            heading('Son Çalınanlar', recent),
            SizedBox(
              height: 142,
              child: recent.isEmpty
                  ? const Center(
                      child: Text('Dinlediğin şarkılar burada görünecek.'),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recent.take(10).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (c, i) {
                        final s = recent[i];
                        return InkWell(
                          onTap: () => m.playSong(s, from: recent),
                          child: SizedBox(
                            width: 100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                art(s.id, 100),
                                const SizedBox(height: 6),
                                Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  artist(s.artist),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            heading('En Çok Dinlenenler', top),
            if (top.isEmpty)
              const Text('Dinledikçe sıralaman oluşacak.')
            else
              ...top.take(5).map((s) => songTile(s, top)),
            if (m.favoriteSongs.isNotEmpty) ...[
              const SizedBox(height: 24),
              heading('Favoriler', m.favoriteSongs),
              ...m.favoriteSongs
                  .take(4)
                  .map((s) => songTile(s, m.favoriteSongs)),
            ],
          ],
        ),
      ),
    ),
  );
  Widget heading(String title, List<SongModel> songs) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      TextButton(onPressed: () => all(title, songs), child: const Text('Tümü')),
    ],
  );
  String artist(String? a) =>
      a == null || a == '<unknown>' ? 'Bilinmeyen sanatçı' : a;
  Widget art(int? id, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: size,
      height: size,
      child: id == null
          ? fallback()
          : QueryArtworkWidget(
              id: id,
              type: ArtworkType.AUDIO,
              artworkBorder: BorderRadius.zero,
              artworkFit: BoxFit.cover,
              nullArtworkWidget: fallback(),
            ),
    ),
  );
  Widget fallback() => const ColoredBox(
    color: Color(0xFF24102F),
    child: Icon(Icons.music_note, color: AppColors.neonPink, size: 34),
  );
  Widget songTile(SongModel s, List<SongModel> queue) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: art(s.id, 54),
    title: Text(
      s.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      artist(s.artist),
      maxLines: 1,
      style: const TextStyle(fontSize: 12),
    ),
    onTap: () => m.playSong(s, from: queue),
    trailing: PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'favorite') {
          await m.toggleFavorite(s);
        } else if (value == 'play') {
          await m.playSong(s, from: queue);
        } else {
          await m.addToPlaylist(value, s);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'play', child: Text('Oynat')),
        PopupMenuItem(
          value: 'favorite',
          child: Text(
            m.isFavorite(s) ? 'Favorilerden çıkar' : 'Favorilere ekle',
          ),
        ),
        ...m.playlists.keys.map(
          (name) =>
              PopupMenuItem(value: name, child: Text('Listeye ekle: $name')),
        ),
      ],
    ),
  );
  Widget now() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF401249), Color(0xFF160D20)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.neonPink.withValues(alpha: .7)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Text(
              'Şimdi Çalıyor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.neonPink,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Favori',
              onPressed: song == null ? null : () => m.toggleFavorite(song!),
              icon: Icon(
                song != null && m.isFavorite(song!)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Row(
          children: [
            art(song?.id, 100),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item?.title ?? 'Müziğini seç',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    artist(item?.artist),
                    style: const TextStyle(fontSize: 14, color: Colors.white60),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<Duration>(
                    stream: m.player.positionStream,
                    builder: (c, s) {
                      final duration = m.player.duration ?? Duration.zero;
                      final p = s.data ?? m.player.position;
                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(c).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: p.inMilliseconds.toDouble().clamp(
                                0,
                                duration.inMilliseconds.toDouble(),
                              ),
                              max: duration.inMilliseconds.toDouble().clamp(
                                1,
                                double.infinity,
                              ),
                              onChanged: duration == Duration.zero
                                  ? null
                                  : (v) => m.seek(
                                      Duration(milliseconds: v.toInt()),
                                    ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                time(p),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                time(duration),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StreamBuilder<bool>(
              stream: m.player.shuffleModeEnabledStream,
              builder: (c, s) => IconButton(
                tooltip: 'Karışık çal',
                onPressed: m.toggleShuffle,
                icon: Icon(
                  Icons.shuffle,
                  color: (s.data ?? m.player.shuffleModeEnabled)
                      ? AppColors.neonPink
                      : Colors.white,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Önceki',
              onPressed: item == null ? null : m.previous,
              icon: const Icon(
                Icons.skip_previous,
                color: Colors.white,
                size: 30,
              ),
            ),
            StreamBuilder<bool>(
              stream: m.player.playingStream,
              builder: (c, s) => IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.neonPink,
                  padding: const EdgeInsets.all(10),
                ),
                iconSize: 36,
                onPressed: item == null
                    ? widget.onOpenMusic
                    : m.togglePlayPause,
                icon: Icon(
                  (s.data ?? m.player.playing) ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sonraki',
              onPressed: item == null ? null : m.next,
              icon: const Icon(Icons.skip_next, color: Colors.white, size: 30),
            ),
            StreamBuilder<LoopMode>(
              stream: m.player.loopModeStream,
              builder: (c, s) {
                final mode = s.data ?? m.player.loopMode;
                return IconButton(
                  tooltip: 'Tekrar',
                  onPressed: m.cycleRepeatMode,
                  icon: Icon(
                    mode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                    color: mode == LoopMode.off
                        ? Colors.white
                        : AppColors.neonPink,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    ),
  );
  String time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
