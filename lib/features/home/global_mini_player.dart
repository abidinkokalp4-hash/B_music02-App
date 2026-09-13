import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

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

        final songId = int.tryParse(item.id);
        final dark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xF0121218) : const Color(0xF5FFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: dark ? AppColors.border : const Color(0xFFE1DDE9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.28 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: onOpenMusic,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: songId == null
                          ? _fallbackArt()
                          : QueryArtworkWidget(
                              id: songId,
                              type: ArtworkType.AUDIO,
                              artworkFit: BoxFit.cover,
                              nullArtworkWidget: _fallbackArt(),
                              artworkBorder: BorderRadius.zero,
                            ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.artist ?? 'Bilinmeyen sanatçı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: music.player.playingStream,
                    builder: (context, playingSnapshot) {
                      final playing = playingSnapshot.data ?? music.player.playing;
                      return Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: music.togglePlayPause,
                          icon: Icon(
                            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppColors.accentSoft,
                            size: 25,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: music.next,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _fallbackArt() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF312E81)],
        ),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
  }
}
