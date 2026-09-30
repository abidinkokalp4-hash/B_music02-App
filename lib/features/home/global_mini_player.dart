import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/services/local_music_service.dart';
import 'full_player_screen.dart';
import 'widgets/music_widgets.dart';

class GlobalMiniPlayer extends StatelessWidget {
  const GlobalMiniPlayer({super.key, required this.onOpenMusic, this.music});
  final VoidCallback onOpenMusic;
  final LocalMusicService? music;

  @override
  Widget build(BuildContext context) {
    final m = music ?? LocalMusicService.instance;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<MediaItem?>(
      stream: m.mediaItemStream,
      initialData: m.currentMediaItem,
      builder: (c, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();
        return Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openFullPlayer(c, music: m),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: Row(children: [
                      Hero(
                          tag: 'global-player-art',
                          child: MediaArtwork(
                              id: int.tryParse(item.id),
                              uri: item.artUri,
                              label: item.title,
                              size: 46,
                              radius: 11)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(item.artist ?? 'Bilinmeyen sanatçı',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 11)),
                          ])),
                      const SizedBox(width: 8),
                      PlayerPlayButton(music: m, size: 42),
                      IconButton(
                          tooltip: 'Sonraki şarkı',
                          onPressed: () => runMusicAction(c, m.next),
                          icon: const Icon(Icons.skip_next_rounded, size: 26)),
                    ])),
                StreamBuilder<Duration>(
                    stream: m.player.positionStream,
                    builder: (c, snapshot) {
                      final duration = m.player.duration?.inMilliseconds ?? 0;
                      final position =
                          (snapshot.data ?? m.player.position).inMilliseconds;
                      return LinearProgressIndicator(
                          minHeight: 2,
                          value: duration <= 0
                              ? 0
                              : (position / duration).clamp(0, 1),
                          backgroundColor:
                              scheme.primary.withValues(alpha: .08),
                          color: scheme.primary);
                    }),
              ]),
            ));
      },
    );
  }
}
