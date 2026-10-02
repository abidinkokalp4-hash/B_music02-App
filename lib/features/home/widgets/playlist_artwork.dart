import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/services/local_music_service.dart';
import 'music_widgets.dart';

class PlaylistArtwork extends StatelessWidget {
  const PlaylistArtwork(
      {super.key, required this.music, required this.name, this.size = 52});
  final LocalMusicService music;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final songs = music.playlistSongs(name);
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => songs.isNotEmpty
        ? MediaArtwork(id: songs.first.id, size: size)
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.queue_music_rounded, color: scheme.primary));
    final path = music.playlistCovers.pathFor(name);
    if (path == null) return fallback();
    return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback()));
  }
}
