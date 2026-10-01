import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../../core/services/artwork_palette.dart';
import '../../../core/services/local_music_service.dart';

class ArtworkSurface extends StatelessWidget {
  const ArtworkSurface({super.key, required this.music, required this.child});
  final LocalMusicService music;
  final Widget child;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
        stream: music.mediaItemStream,
        initialData: music.currentMediaItem,
        builder: (context, snapshot) => FutureBuilder<Color?>(
          future: ArtworkPalette.forArtwork(snapshot.data?.artUri),
          builder: (context, palette) {
            final theme = Theme.of(context);
            final colour = palette.data ?? theme.colorScheme.primary;
            final dark = theme.brightness == Brightness.dark;
            return AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0, .55, 1],
                  colors: [
                    Color.lerp(theme.scaffoldBackgroundColor, colour,
                        dark ? .32 : .13)!,
                    Color.lerp(theme.scaffoldBackgroundColor, colour,
                        dark ? .12 : .04)!,
                    theme.scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: child,
            );
          },
        ),
      );
}
