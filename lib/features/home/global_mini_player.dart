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

        return Container(
          height: 58,
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: const Color(0xF2111320),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF25283A)),
          ),
          child: InkWell(
            onTap: onOpenMusic,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 7, 6, 7),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 43,
                      height: 43,
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
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.artist ?? 'Bilinmeyen sanatçı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _Waveform(),
                  const SizedBox(width: 8),
                  StreamBuilder<bool>(
                    stream: music.player.playingStream,
                    builder: (context, playingSnapshot) {
                      final playing = playingSnapshot.data ?? music.player.playing;
                      return IconButton(
                        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                        padding: EdgeInsets.zero,
                        onPressed: music.togglePlayPause,
                        icon: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      );
                    },
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
          colors: [AppColors.neonPurple, Color(0xFF2E126B)],
        ),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform();

  static const _heights = <double>[10, 18, 13, 23, 15, 27, 20, 12, 24, 17, 21, 11];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _heights
            .map(
              (height) => Container(
                width: 2.2,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.neonPurple,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
