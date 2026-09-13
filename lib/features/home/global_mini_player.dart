import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';

class GlobalMiniPlayer extends StatelessWidget {
  const GlobalMiniPlayer({
    super.key,
    required this.onOpenMusic,
  });

  final VoidCallback onOpenMusic;

  @override
  Widget build(BuildContext context) {
    final music = LocalMusicService.instance;
    return StreamBuilder<int?>(
      stream: music.player.currentIndexStream,
      builder: (context, snapshot) {
        final tag = music.player.sequenceState.currentSource?.tag;
        final item = tag is MediaItem ? tag : null;
        if (item == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 7),
          decoration: BoxDecoration(
            color: const Color(0xF2171717),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: onOpenMusic,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: AppColors.gold),
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
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.artist ?? 'Bilinmeyen sanatçı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white38, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: music.player.playingStream,
                    builder: (context, playingSnapshot) {
                      final playing = playingSnapshot.data ?? music.player.playing;
                      return IconButton(
                        onPressed: music.togglePlayPause,
                        icon: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: AppColors.gold,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: music.next,
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
