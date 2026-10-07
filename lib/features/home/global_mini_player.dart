import 'dart:async';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/services/local_music_service.dart';
import 'full_player_screen.dart';
import 'widgets/music_widgets.dart';

/// Semi-transparent mini player above the tab bar. It shows for a few seconds
/// when a song starts (or after a tap / swipe up on the thin handle) and then
/// slides down to the handle so it never covers the screen for long.
class GlobalMiniPlayer extends StatefulWidget {
  const GlobalMiniPlayer({super.key, required this.onOpenMusic, this.music,
      this.visibleFor = const Duration(seconds: 4)});
  final VoidCallback onOpenMusic;
  final LocalMusicService? music;
  final Duration visibleFor;

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  late final LocalMusicService m = widget.music ?? LocalMusicService.instance;
  bool expanded = true;
  String? lastId;
  Timer? hideTimer;
  StreamSubscription<MediaItem?>? items;

  @override
  void initState() {
    super.initState();
    lastId = m.currentMediaItem?.id;
    items = m.mediaItemStream.listen((item) {
      if (item != null && item.id != lastId) {
        lastId = item.id;
        reveal();
      }
    });
    scheduleHide();
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    items?.cancel();
    super.dispose();
  }

  void scheduleHide() {
    hideTimer?.cancel();
    hideTimer = Timer(widget.visibleFor, () {
      if (mounted) setState(() => expanded = false);
    });
  }

  void reveal() {
    if (!mounted) return;
    setState(() => expanded = true);
    scheduleHide();
  }

  void collapse() {
    hideTimer?.cancel();
    setState(() => expanded = false);
  }

  void drag(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -100) reveal();
    if (v > 100) collapse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<MediaItem?>(
      stream: m.mediaItemStream,
      initialData: m.currentMediaItem,
      builder: (c, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: drag,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: expanded ? card(c, item, scheme) : handle(scheme),
          ),
        );
      },
    );
  }

  Widget handle(ColorScheme scheme) => Semantics(
        button: true,
        label: 'Mini oynatıcıyı göster',
        child: InkWell(
          key: const ValueKey('mini-player-handle'),
          onTap: reveal,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 16,
            width: double.infinity,
            child: Center(
              child: StreamBuilder<bool>(
                stream: m.player.playingStream,
                builder: (c, s) => Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: (s.data ?? m.player.playing ? scheme.primary : scheme.onSurfaceVariant)
                        .withValues(alpha: .75),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget card(BuildContext c, MediaItem item, ColorScheme scheme) => ClipRRect(
        key: const ValueKey('mini-player-card'),
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: scheme.surfaceContainerHigh.withValues(alpha: .62),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.primary.withValues(alpha: .35))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                scheduleHide();
                openFullPlayer(c, music: m);
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 2, 4),
                    child: Row(children: [
                      Hero(
                          tag: 'global-player-art',
                          child: MediaArtwork(
                              id: int.tryParse(item.id), uri: item.artUri, label: item.title, size: 38, radius: 8)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(item.artist ?? 'Bilinmeyen sanatçı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                      ])),
                      const SizedBox(width: 4),
                      Listener(onPointerDown: (_) => scheduleHide(), child: PlayerPlayButton(music: m, size: 42)),
                      IconButton(
                          tooltip: 'Sonraki şarkı',
                          onPressed: () {
                            scheduleHide();
                            runMusicAction(c, m.next);
                          },
                          icon: const Icon(Icons.skip_next_rounded, size: 26)),
                      IconButton(
                          tooltip: 'Mini oynatıcıyı gizle',
                          visualDensity: VisualDensity.compact,
                          onPressed: collapse,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22)),
                    ])),
                StreamBuilder<Duration>(
                    stream: m.player.positionStream,
                    builder: (c, snapshot) {
                      final duration = m.player.duration?.inMilliseconds ?? 0;
                      final position = (snapshot.data ?? m.player.position).inMilliseconds;
                      return LinearProgressIndicator(
                          minHeight: 2,
                          value: duration <= 0 ? 0 : (position / duration).clamp(0, 1),
                          backgroundColor: scheme.primary.withValues(alpha: .08),
                          color: scheme.primary);
                    }),
              ]),
            ),
          ),
        ),
      );
}
