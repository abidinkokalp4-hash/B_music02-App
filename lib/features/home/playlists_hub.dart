import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_catalog.dart';
import '../../core/services/music_insights_service.dart';
import 'widgets/music_widgets.dart';

class PlaylistsHub extends StatefulWidget {
  const PlaylistsHub({super.key, this.music});
  final LocalMusicService? music;
  @override
  State<PlaylistsHub> createState() => _PlaylistsState();
}

class _PlaylistsState extends State<PlaylistsHub> {
  late final music = widget.music ?? LocalMusicService.instance;
  final insights = MusicInsightsService.instance;
  StreamSubscription<void>? changes;
  String? selected, collection;
  List<SongModel> recent = [], top = [];

  @override
  void initState() {
    super.initState();
    music.addListener(changed);
    changes = insights.changes.listen((_) => loadHistory());
    unawaited(loadHistory());
  }

  @override
  void dispose() {
    music.removeListener(changed);
    changes?.cancel();
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> loadHistory() async {
    final rows = await Future.wait(
        [insights.recentTracks(limit: 40), insights.topTracks(limit: 100)]);
    final byId = {for (final song in music.songs) song.id.toString(): song};
    if (mounted)
      setState(() {
        recent = rows[0]
            .map((entry) => byId[entry.id])
            .whereType<SongModel>()
            .toList();
        top = rows[1]
            .map((entry) => byId[entry.id])
            .whereType<SongModel>()
            .toList();
      });
  }

  Future<void> nameDialog({String? old}) async {
    final name = await askPlaylistName(context, current: old);
    if (name == null) return;
    try {
      if (old == null) {
        await music.createPlaylist(name);
        if (mounted) setState(() => selected = name);
      } else {
        await music.renamePlaylist(old, name);
        if (mounted && selected == old) setState(() => selected = name);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bu adla bir liste var. Farklı bir ad seç.')));
    }
  }

  Future<void> delete(String name) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text('$name silinsin mi?'),
              content: const Text(
                  'Liste kaldırılır. Müzik dosyaların telefonunda kalır.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Vazgeç')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Listeyi sil'))
              ],
            ));
    if (confirmed == true) {
      await music.deletePlaylist(name);
      if (mounted)
        setState(() {
          if (selected == name) selected = null;
        });
    }
  }

  Future<void> addSongs() async {
    final name = selected;
    if (name == null) return;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => _PlaylistPicker(music: music, name: name));
  }

  Future<void> chooseCover() async {
    final name = selected;
    if (name == null) return;
    await runMusicAction(context, () async {
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 900, maxHeight: 900, imageQuality: 85);
      if (image != null) await music.setPlaylistCover(name, image.path);
    });
  }

  Widget cover(String name, List<SongModel> songs, {double size = 52}) {
    Widget fallback() => songs.isEmpty
        ? Container(width: size, height: size,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.queue_music_rounded, color: Theme.of(context).colorScheme.primary))
        : MediaArtwork(id: songs.first.id, size: size);
    final path = music.playlistCovers.pathFor(name);
    if (path == null) return fallback();
    return ClipRRect(borderRadius: BorderRadius.circular(14),
      child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback()));
  }

  Future<void> play(List<SongModel> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) return;
    await music.player.setShuffleModeEnabled(shuffle);
    await music.playSong(songs[shuffle ? Random().nextInt(songs.length) : 0],
        from: songs);
  }

  void back() => setState(() {
        selected = collection = null;
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = selected != null || collection != null;
    final songs = selected != null
        ? music.playlistSongs(selected!)
        : collection == 'Favorilerim'
            ? music.favoriteSongs
            : collection == 'Son çalınanlar'
                ? recent
                : top;
    return PopScope(
        canPop: !detail,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) back();
        },
        child: Scaffold(
            appBar: AppBar(
              leading: detail ? BackButton(onPressed: back) : null,
              title: Text(selected ?? collection ?? 'Listelerim',
                  style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8)),
              actions: selected != null
                  ? [
                      IconButton(
                          tooltip: 'Listeye şarkı ekle',
                          onPressed: addSongs,
                          icon: const Icon(Icons.playlist_add_rounded)),
                      PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'cover') chooseCover();
                            if (value == 'clearCover') runMusicAction(context,
                                () => music.removePlaylistCover(selected!));
                            if (value == 'rename') nameDialog(old: selected);
                            if (value == 'delete') delete(selected!);
                          },
                          itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'cover', child: Text('Kapak fotoğrafı seç')),
                                if (music.playlistCovers.pathFor(selected!) != null)
                                  const PopupMenuItem(
                                      value: 'clearCover', child: Text('Kapağı kaldır')),
                                const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Adını değiştir')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('Listeyi sil'))
                              ]),
                    ]
                  : detail
                      ? []
                      : [
                          IconButton(
                              tooltip: 'Yeni çalma listesi',
                              onPressed: nameDialog,
                              icon:
                                  const Icon(Icons.add_circle_outline_rounded))
                        ],
            ),
            body: detail
                ? Column(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                        child: Row(children: [
                          if (selected != null) ...[
                            GestureDetector(onTap: chooseCover,
                                child: cover(selected!, songs, size: 56)),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    '${songs.length} şarkı · ${musicDurationLabel(songs)}',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant)),
                                if (selected != null)
                                  const Padding(
                                      padding: EdgeInsets.only(top: 5),
                                      child: Text(
                                          'Sürükleyerek şarkıları sırala',
                                          style: TextStyle(fontSize: 11))),
                              ])),
                          IconButton(
                              tooltip: 'Karışık çal',
                              onPressed: songs.isEmpty
                                  ? null
                                  : () => runMusicAction(context,
                                      () => play(songs, shuffle: true)),
                              icon: const Icon(Icons.shuffle_rounded)),
                          IconButton.filled(
                              tooltip: 'Tüm listeyi çal',
                              onPressed: songs.isEmpty
                                  ? null
                                  : () => runMusicAction(
                                      context, () => play(songs)),
                              icon: const Icon(Icons.play_arrow_rounded)),
                        ])),
                    Expanded(
                        child: songs.isEmpty
                            ? MusicEmptyState(
                                icon: Icons.queue_music_rounded,
                                title: 'Birlikte iyi giden şarkılar',
                                description: selected != null
                                    ? 'Listeye müzik ekle, kendi seçkini oluştur.'
                                    : 'Dinlediğin ve beğendiğin müzikler burada görünecek.',
                                action: selected == null ? null : addSongs,
                                actionLabel: 'Şarkı ekle')
                            : selected != null
                                ? ReorderableListView.builder(
                                    buildDefaultDragHandles: false,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 150),
                                    itemCount: songs.length,
                                    onReorderItem: (from, to) => runMusicAction(
                                        context,
                                        () => music.movePlaylistSong(
                                            selected!, from, to)),
                                    itemBuilder: (c, i) => MusicSongTile(
                                        key: ValueKey(songs[i].id),
                                        song: songs[i],
                                        music: music,
                                        onPlay: () => music.playSong(songs[i],
                                            from: songs),
                                        trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PopupMenuButton<String>(
                                                  tooltip: 'Şarkı seçenekleri',
                                                  onSelected: (value) => value ==
                                                          'remove'
                                                      ? music
                                                          .removeFromPlaylist(
                                                              selected!,
                                                              songs[i])
                                                      : showSongActions(
                                                          c, music, songs[i]),
                                                  itemBuilder: (_) => const [
                                                        PopupMenuItem(
                                                            value: 'options',
                                                            child: Text(
                                                                'Şarkı seçenekleri')),
                                                        PopupMenuItem(
                                                            value: 'remove',
                                                            child: Text(
                                                                'Listeden çıkar'))
                                                      ]),
                                              ReorderableDragStartListener(
                                                  index: i,
                                                  child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(8),
                                                      child: Icon(Icons
                                                          .drag_handle_rounded))),
                                            ])),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 150),
                                    itemCount: songs.length,
                                    itemBuilder: (c, i) => MusicSongTile(
                                        song: songs[i],
                                        music: music,
                                        onPlay: () => music.playSong(songs[i],
                                            from: songs)))),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                    children: [
                        Text('Her ruh haline bir liste.',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 24),
                        for (final row in <(String, IconData, Color, int)>[
                          (
                            'Favorilerim',
                            Icons.favorite_rounded,
                            const Color(0xFFD770A8),
                            music.favoriteSongs.length
                          ),
                          (
                            'Son çalınanlar',
                            Icons.history_rounded,
                            const Color(0xFF83B7EE),
                            recent.length
                          ),
                          (
                            'En çok dinlenenler',
                            Icons.local_fire_department_outlined,
                            const Color(0xFFDDA374),
                            top.length
                          ),
                        ])
                          Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                      leading: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                              color:
                                                  row.$3.withValues(alpha: .12),
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          child: Icon(row.$2, color: row.$3)),
                                      title: Text(row.$1,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      subtitle: Text('${row.$4} şarkı',
                                          style: const TextStyle(fontSize: 12)),
                                      trailing: const Icon(
                                          Icons.chevron_right_rounded),
                                      onTap: () =>
                                          setState(() => collection = row.$1)))),
                        MusicSectionTitle(
                            title: 'Senin listelerin',
                            subtitle:
                                '${music.playlists.length} kişisel çalma listesi'),
                        if (music.playlists.isEmpty)
                          MusicEmptyState(
                              icon: Icons.playlist_add_rounded,
                              title: 'İlk seçkini oluştur',
                              description:
                                  'Uzun yol, spor veya bir akşam için sevdiğin müzikleri bir araya getir.',
                              action: nameDialog,
                              actionLabel: 'Yeni liste oluştur')
                        else
                          ...music.playlists.keys.map((name) {
                            final songs = music.playlistSongs(name);
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              leading: cover(name, songs),
                              title: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${songs.length} şarkı · ${musicDurationLabel(songs)}',
                                  style: const TextStyle(fontSize: 12)),
                              onTap: () => setState(() => selected = name),
                              trailing: PopupMenuButton<String>(
                                  onSelected: (value) => value == 'rename'
                                      ? nameDialog(old: name)
                                      : delete(name),
                                  itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'rename',
                                            child: Text('Adını değiştir')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Listeyi sil'))
                                      ]),
                            );
                          }),
                      ])));
  }
}

class _PlaylistPicker extends StatefulWidget {
  const _PlaylistPicker({required this.music, required this.name});
  final LocalMusicService music;
  final String name;
  @override
  State<_PlaylistPicker> createState() => _PickerState();
}

class _PickerState extends State<_PlaylistPicker> {
  String query = '';
  bool saving = false;
  @override
  Widget build(BuildContext context) {
    final songs = selectMusic(widget.music.songs, query: query);
    return SafeArea(
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: Column(children: [
              ListTile(
                  title: Text(widget.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  subtitle:
                      const Text('Listene eklemek istediğin şarkıları seç'),
                  trailing: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Bitti'))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                      onChanged: (value) => setState(() => query = value),
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Şarkılarda ara'))),
              const SizedBox(height: 12),
              Expanded(
                  child: ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (c, i) {
                        final song = songs[i];
                        final included = widget.music.playlists[widget.name]
                                ?.contains(song.id) ??
                            false;
                        return CheckboxListTile(
                            value: included,
                            title: Text(song.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(songArtist(song),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            secondary:
                                MediaArtwork(id: song.id, size: 44, radius: 10),
                            onChanged: saving
                                ? null
                                : (value) async {
                                    setState(() => saving = true);
                                    await runMusicAction(
                                        c,
                                        () => value == true
                                            ? widget.music.addToPlaylist(
                                                widget.name, song)
                                            : widget.music.removeFromPlaylist(
                                                widget.name, song));
                                    if (mounted) setState(() => saving = false);
                                  });
                      })),
            ])));
  }
}
