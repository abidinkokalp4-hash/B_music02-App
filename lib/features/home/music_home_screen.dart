import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_catalog.dart';
import '../../core/services/music_insights_service.dart';
import 'discover_screen.dart';
import 'download_center_screen.dart';
import 'full_player_screen.dart';
import 'global_mini_player.dart';
import 'library_screen.dart';
import 'song_collection_screen.dart';
import 'widgets/music_widgets.dart';

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen(
      {super.key,
      required this.onOpenMusic,
      required this.onOpenDiscover,
      required this.onRequestLogin,
      this.music});
  final VoidCallback onOpenMusic, onOpenDiscover;
  final Future<void> Function() onRequestLogin;
  final LocalMusicService? music;
  @override
  State<MusicHomeScreen> createState() => _HomeState();
}

class _HomeState extends State<MusicHomeScreen> {
  late final music = widget.music ?? LocalMusicService.instance;
  final insights = MusicInsightsService.instance;
  StreamSubscription<void>? insightSubscription;
  List<SongModel> recent = [], top = [];
  int minutes = 0;

  @override
  void initState() {
    super.initState();
    music.addListener(changed);
    insightSubscription = insights.changes.listen((_) => history());
    unawaited(load());
  }

  @override
  void dispose() {
    music.removeListener(changed);
    insightSubscription?.cancel();
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> load() async {
    await music.requestPermissionAndLoad(request: false);
    await history();
  }

  Future<void> history() async {
    final values = await Future.wait([
      insights.recentTracks(limit: 40),
      insights.topTracks(limit: 100),
    ]);
    final listened = await insights.todayMinutes();
    final byId = {for (final s in music.songs) s.id.toString(): s};
    if (mounted)
      setState(() {
        recent = values[0]
            .map((entry) => byId[entry.id])
            .whereType<SongModel>()
            .toList();
        top = values[1]
            .map((entry) => byId[entry.id])
            .whereType<SongModel>()
            .toList();
        minutes = listened;
      });
  }

  void collection(String title, List<SongModel> songs) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => SongCollectionScreen(title: title, songs: songs)));

  Future<void> shuffleLibrary() async {
    if (music.songs.isEmpty) {
      widget.onOpenMusic();
      return;
    }
    await music.player.setShuffleModeEnabled(true);
    await music.playSong(music.songs[Random().nextInt(music.songs.length)],
        from: music.songs);
  }

  Future<void> contact() async {
    try {
      if (await launchUrl(
          Uri(
              scheme: 'mailto',
              path: 'abidinkokalp4@gmail.com',
              queryParameters: {'subject': 'B_music02 İletişim'}),
          mode: LaunchMode.externalApplication)) return;
    } catch (_) {/* Show a copyable address if no mail app is installed. */}
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('İletişim'),
              content: const SelectableText('abidinkokalp4@gmail.com'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Tamam'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? 'Gecenin ritmi'
        : hour < 12
            ? 'Güne müzikle başla'
            : hour < 18
                ? 'Günün ritmini yakala'
                : 'Akşamın sesi';
    final fresh = selectMusic(music.songs, sort: MusicSort.newest);
    final carousel = recent.isNotEmpty ? recent : fresh;
    return Scaffold(
        body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Row(children: [
                      Container(
                          width: 44,
                          height: 44,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14)),
                          child: Image.asset('assets/images/b_music02_logo.png',
                              fit: BoxFit.cover)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('B_music02',
                                style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.6)),
                            Text('Müzik her zaman seninle',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant)),
                          ])),
                      PopupMenuButton<String>(
                          tooltip: 'Uygulama menüsü',
                          onSelected: (_) => contact(),
                          itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'contact',
                                    child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading:
                                            Icon(Icons.mail_outline_rounded),
                                        title: Text('İletişim'))),
                              ]),
                    ]),
                    const SizedBox(height: 26),
                    Text(greeting,
                        style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2)),
                    const SizedBox(height: 7),
                    Text('Müziklerin. Favorilerin. Senin ritmin.',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 22),
                    Material(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => const _SearchRoute())),
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 17),
                                child: Row(children: [
                                  Icon(Icons.search_rounded,
                                      color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text('Bugün ne dinlemek istersin?',
                                          style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 13))),
                                ])))),
                    const SizedBox(height: 18),
                    StreamBuilder<MediaItem?>(
                        stream: music.mediaItemStream,
                        initialData: music.currentMediaItem,
                        builder: (c, snapshot) => snapshot.data == null
                            ? _welcomeHero(scheme)
                            : _nowPlaying(snapshot.data!, scheme)),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                          child: _QuickCard(
                              title: 'Favorilerim',
                              detail: '${music.favoriteSongs.length} şarkı',
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFDA6FAB),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const _FavoritesRoute())))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _QuickCard(
                              title: 'İndirilenler',
                              detail: 'Çevrimdışı arşivin',
                              icon: Icons.download_done_rounded,
                              color: const Color(0xFF68B8E8),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const DownloadCenterScreen(
                                              showDownloadsFirst: true))))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _QuickCard(
                              title: 'Yeni eklenenler',
                              detail: 'Arşivinin en yenileri',
                              icon: Icons.auto_awesome_rounded,
                              color: const Color(0xFFB5A0F8),
                              onTap: () =>
                                  collection('Yeni eklenenler', fresh))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _QuickCard(
                              title: 'Keşfet',
                              detail: 'Çevrimiçi müzik ara',
                              icon: Icons.explore_outlined,
                              color: const Color(0xFF83C9AD),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const DiscoverScreen())))),
                    ]),
                    const SizedBox(height: 22),
                    if (carousel.isNotEmpty) ...[
                      MusicSectionTitle(
                          title: recent.isEmpty
                              ? 'Arşivinden keşfet'
                              : 'Yeniden dinle',
                          subtitle: recent.isEmpty
                              ? 'Son eklediğin şarkılar'
                              : 'En son dinlediğin müzikler',
                          onAll: () => collection(
                              recent.isEmpty
                                  ? 'Yeni eklenenler'
                                  : 'Son çalınanlar',
                              carousel)),
                      SizedBox(
                          height: 188,
                          child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: carousel.length.clamp(0, 10),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (c, i) {
                                final song = carousel[i];
                                return SizedBox(
                                    width: 126,
                                    child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () => runMusicAction(
                                            c,
                                            () => music.playSong(song,
                                                from: carousel)),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              MediaArtwork(
                                                  id: song.id,
                                                  label: song.title,
                                                  size: 126,
                                                  radius: 18),
                                              const SizedBox(height: 10),
                                              Text(song.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(height: 3),
                                              Text(songArtist(song),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: scheme
                                                          .onSurfaceVariant)),
                                            ])));
                              })),
                    ] else
                      MusicEmptyState(
                          icon: Icons.headphones_rounded,
                          title: 'Arşivine bir göz atalım',
                          description: music.hasPermission
                              ? 'Telefonuna eklediğin müzikler burada görünecek.'
                              : 'Müzik erişim iznini ver, şarkılarını yanında taşı.',
                          action: widget.onOpenMusic,
                          actionLabel: 'Müziklerimi aç'),
                    if (top.isNotEmpty) ...[
                      MusicSectionTitle(
                          title: 'Vazgeçilmezlerin',
                          subtitle: 'En çok dinlediğin şarkılar',
                          onAll: () => collection('En çok dinlenenler', top)),
                      ...top.take(5).map((song) => MusicSongTile(
                          song: song,
                          music: music,
                          onPlay: () => music.playSong(song, from: top))),
                    ],
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: scheme.outline.withValues(alpha: .5))),
                      child: Row(children: [
                        Icon(Icons.graphic_eq_rounded,
                            color: scheme.primary, size: 30),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  minutes == 0
                                      ? 'Bugün ritmi sen belirle'
                                      : 'Bugün $minutes dakika müzik',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Müziklerini internet olmadan da dinle.',
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11)),
                            ]))
                      ]),
                    ),
                  ]),
            )));
  }

  Widget _welcomeHero(ColorScheme scheme) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(scheme.primary, const Color(0xFF24143E), .55)!,
                const Color(0xFF17192B)
              ],
            )),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SENİN MÜZİK DÜNYAN',
              style: TextStyle(
                  color: Color(0xFFD3BEF6),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6)),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(
                child: Text('Kendi\nritmini bul.',
                    style: TextStyle(
                        fontSize: 33,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -1.2))),
            Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .1), width: 16),
                    color: Colors.white.withValues(alpha: .04)),
                child: const Icon(Icons.headphones_rounded,
                    color: Color(0xFFD9C1FF), size: 45)),
          ]),
          const SizedBox(height: 22),
          Row(children: [
            FilledButton.icon(
                onPressed: () => runMusicAction(context, shuffleLibrary),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF291744)),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Müziği başlat'))
          ]),
        ]),
      );

  Widget _nowPlaying(MediaItem item, ColorScheme scheme) => Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: () => openFullPlayer(context, music: music),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.graphic_eq_rounded,
                          size: 16, color: scheme.primary),
                      const SizedBox(width: 7),
                      Text('ŞİMDİ ÇALIYOR',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary)),
                      const Spacer(),
                      const Icon(Icons.open_in_full_rounded, size: 16)
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      MediaArtwork(
                          id: int.tryParse(item.id),
                          uri: item.artUri,
                          label: item.title,
                          size: 80,
                          radius: 18),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2)),
                            const SizedBox(height: 6),
                            Text(item.artist ?? 'Bilinmeyen sanatçı',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12)),
                          ]))
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      IconButton(
                          tooltip: '10 saniye geri',
                          onPressed: () => runMusicAction(
                              context, () => music.seekRelative(-10)),
                          icon: const Icon(Icons.replay_10_rounded)),
                      IconButton(
                          tooltip: 'Önceki şarkı',
                          onPressed: () =>
                              runMusicAction(context, music.previous),
                          icon: const Icon(Icons.skip_previous_rounded)),
                      const Spacer(),
                      PlayerPlayButton(music: music, size: 50),
                      const Spacer(),
                      IconButton(
                          tooltip: 'Sonraki şarkı',
                          onPressed: () => runMusicAction(context, music.next),
                          icon: const Icon(Icons.skip_next_rounded)),
                      IconButton(
                          tooltip: '10 saniye ileri',
                          onPressed: () => runMusicAction(
                              context, () => music.seekRelative(10)),
                          icon: const Icon(Icons.forward_10_rounded)),
                    ]),
                  ]),
            )),
      );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard(
      {required this.title,
      required this.detail,
      required this.icon,
      required this.color,
      required this.onTap});
  final String title, detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(height: 14),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ]))));
}

class _SearchRoute extends StatelessWidget {
  const _SearchRoute();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Arşivde ara')),
      body: const LibraryScreen(focusSearch: true),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: GlobalMiniPlayer(onOpenMusic: () {}))));
}

class _FavoritesRoute extends StatelessWidget {
  const _FavoritesRoute();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      body: const LibraryScreen(favoritesOnly: true),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: GlobalMiniPlayer(onOpenMusic: () {}))));
}
