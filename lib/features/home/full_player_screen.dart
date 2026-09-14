import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final music = LocalMusicService.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<int?>(
          stream: music.player.currentIndexStream,
          builder: (context, _) {
            final tag = music.player.sequenceState.currentSource?.tag;
            final item = tag is MediaItem ? tag : null;
            final songId = item == null ? null : int.tryParse(item.id);
            if (item == null) {
              return const Center(child: Text('Çalan müzik yok'));
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                      ),
                      const Expanded(
                        child: Text(
                          'Şimdi Çalıyor',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const Spacer(),
                  Hero(
                    tag: 'global-player-art',
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonPurple.withValues(alpha: 0.32),
                            blurRadius: 42,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: songId == null
                          ? _fallback()
                          : QueryArtworkWidget(
                              id: songId,
                              type: ArtworkType.AUDIO,
                              artworkFit: BoxFit.cover,
                              nullArtworkWidget: _fallback(),
                              artworkBorder: BorderRadius.zero,
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    item.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.artist ?? 'Bilinmeyen sanatçı',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  StreamBuilder<Duration>(
                    stream: music.player.positionStream,
                    builder: (context, posSnapshot) {
                      final position = posSnapshot.data ?? music.player.position;
                      final duration = music.player.duration ?? Duration.zero;
                      final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
                      final value = position.inMilliseconds.clamp(0, maxMs).toDouble();
                      return Column(
                        children: [
                          Slider(
                            value: value,
                            min: 0,
                            max: maxMs.toDouble(),
                            activeColor: AppColors.neonPurple,
                            onChanged: (v) => music.seek(Duration(milliseconds: v.round())),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_time(position), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text(_time(duration), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(onPressed: () => music.seekRelative(const Duration(seconds: -10)), icon: const Icon(Icons.replay_10_rounded, size: 30)),
                      IconButton(onPressed: music.previous, icon: const Icon(Icons.skip_previous_rounded, size: 38)),
                      StreamBuilder<bool>(
                        stream: music.player.playingStream,
                        builder: (context, snapshot) {
                          final playing = snapshot.data ?? music.player.playing;
                          return FilledButton(
                            onPressed: music.togglePlayPause,
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(20),
                            ),
                            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                          );
                        },
                      ),
                      IconButton(onPressed: music.next, icon: const Icon(Icons.skip_next_rounded, size: 38)),
                      IconButton(onPressed: () => music.seekRelative(const Duration(seconds: 10)), icon: const Icon(Icons.forward_10_rounded, size: 30)),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _time(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.neonPurple, Color(0xFF2E126B)]),
        ),
        child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white),
      );
}
