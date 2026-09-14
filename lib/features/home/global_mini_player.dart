import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';
import 'full_player_screen.dart';

class GlobalMiniPlayer extends StatelessWidget {
  const GlobalMiniPlayer({super.key, required this.onOpenMusic});
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
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xF2111320),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF25283A)),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 320),
                pageBuilder: (_, animation, __) => const FullPlayerScreen(),
                transitionsBuilder: (_, animation, __, child) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: FadeTransition(opacity: animation, child: child),
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 7, 6, 7),
              child: Row(
                children: [
                  Hero(
                    tag: 'global-player-art',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 47,
                        height: 47,
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(item.artist ?? 'Bilinmeyen sanatçı', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                      ],
                    ),
                  ),
                  _control(Icons.replay_10_rounded, () => _seekRelative(music, -10)),
                  _control(Icons.skip_previous_rounded, () => music.player.seekToPrevious()),
                  StreamBuilder<bool>(
                    stream: music.player.playingStream,
                    builder: (context, playingSnapshot) {
                      final playing = playingSnapshot.data ?? music.player.playing;
                      return IconButton(
                        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                        padding: EdgeInsets.zero,
                        onPressed: music.togglePlayPause,
                        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26),
                      );
                    },
                  ),
                  _control(Icons.skip_next_rounded, () => music.player.seekToNext()),
                  _control(Icons.forward_10_rounded, () => _seekRelative(music, 10)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _seekRelative(LocalMusicService music, int seconds) {
    final target = music.player.position + Duration(seconds: seconds);
    music.player.seek(target.isNegative ? Duration.zero : target);
  }

  static Widget _control(IconData icon, VoidCallback action) => IconButton(
        constraints: const BoxConstraints.tightFor(width: 30, height: 34),
        padding: EdgeInsets.zero,
        onPressed: action,
        icon: Icon(icon, size: 20, color: Colors.white70),
      );

  static Widget _fallbackArt() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.neonPurple, Color(0xFF2E126B)]),
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.white),
      );
}
