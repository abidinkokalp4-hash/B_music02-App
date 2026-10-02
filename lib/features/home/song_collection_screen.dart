import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_catalog.dart';
import 'global_mini_player.dart';
import 'widgets/music_widgets.dart';

class SongCollectionScreen extends StatefulWidget {
  const SongCollectionScreen(
      {super.key, required this.title, required this.songs, this.music});
  final String title;
  final List<SongModel> songs;
  final LocalMusicService? music;
  @override
  State<SongCollectionScreen> createState() => _CollectionState();
}

class _CollectionState extends State<SongCollectionScreen> {
  late final music = widget.music ?? LocalMusicService.instance;
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          IconButton(
              tooltip: 'Çalma listesine ekle',
              onPressed: widget.songs.isEmpty
                  ? null
                  : () => addSongsToList(c, music, widget.songs),
              icon: const Icon(Icons.playlist_add_rounded))
        ]),
        body: AnimatedBuilder(
            animation: music,
            builder: (c, _) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: widget.songs.length + 1,
                itemBuilder: (c, i) {
                  if (i == 0)
                    return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '${widget.songs.length} şarkı · ${musicDurationLabel(widget.songs)}')),
                          FilledButton.icon(
                              onPressed: widget.songs.isEmpty
                                  ? null
                                  : () => runMusicAction(
                                      c,
                                      () => music.playSong(widget.songs.first,
                                          from: widget.songs)),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Tümünü çal')),
                        ]));
                  final song = widget.songs[i - 1];
                  return MusicSongTile(
                      song: song,
                      music: music,
                      onPlay: () => music.playSong(song, from: widget.songs));
                })),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: GlobalMiniPlayer(music: music, onOpenMusic: () {}))),
      );
}
