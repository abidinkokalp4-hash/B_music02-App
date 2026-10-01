import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_catalog.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/services/player_preferences.dart';
import '../../core/services/sleep_timer.dart';
import 'queue_sheet.dart';
import 'widgets/music_widgets.dart';
import 'widgets/artwork_surface.dart';

void openFullPlayer(BuildContext context, {LocalMusicService? music}) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => FullPlayerScreen(music: music),
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child),
  ));
}

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key, this.music});
  final LocalMusicService? music;

  @override
  Widget build(BuildContext context) {
    final m = music ?? LocalMusicService.instance;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ArtworkSurface(
        music: m,
        child: SafeArea(
            child: AnimatedBuilder(
          animation: m,
          builder: (c, _) => StreamBuilder<MediaItem?>(
            stream: m.mediaItemStream,
            initialData: m.currentMediaItem,
            builder: (c, snapshot) {
              final item = snapshot.data;
              if (item == null)
                return Column(children: [
                  Align(alignment: Alignment.topLeft, child: CloseButton()),
                  const Expanded(
                      child: Center(
                          child: MusicEmptyState(
                              icon: Icons.headphones_rounded,
                              title: 'Bir şarkı seç',
                              description:
                                  'Müzik arşivinden bir şarkı açtığında oynatıcı burada hazır.'))),
                ]);
              final song = m.currentSong;
              return LayoutBuilder(
                  key: ValueKey(item.id),
                  builder: (c, constraints) {
                    final artworkSize = (constraints.maxWidth - 64)
                        .clamp(
                            160.0,
                            constraints.maxHeight * .43 > 160
                                ? constraints.maxHeight * .43
                                : 160.0)
                        .clamp(160.0, 380.0);
                    return ListView(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
                        children: [
                          Row(children: [
                            IconButton(
                                tooltip: 'Oynatıcıyı küçült',
                                onPressed: () => Navigator.pop(c),
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 30)),
                            Expanded(
                                child: Column(children: [
                              Text('ŞİMDİ ÇALIYOR',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSurfaceVariant,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(item.album ?? 'Müzik arşivi',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ])),
                            IconButton(
                                tooltip: 'Şarkı seçenekleri',
                                onPressed: song == null
                                    ? null
                                    : () => showSongActions(c, m, song),
                                icon: const Icon(Icons.more_horiz_rounded)),
                          ]),
                          const SizedBox(height: 24),
                          Center(
                              child: GestureDetector(
                            onVerticalDragUpdate:
                                PlayerPreferences.instance.flag('gestures')
                                    ? (details) {
                                        unawaited(m.player.setVolume(
                                            (m.player.volume -
                                                    details.delta.dy / 300)
                                                .clamp(0, 1)));
                                      }
                                    : null,
                            child: Hero(
                                tag: 'global-player-art',
                                child: Container(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                            color: scheme.primary
                                                .withValues(alpha: .22),
                                            blurRadius: 60,
                                            offset: const Offset(0, 18))
                                      ]),
                                  child: MediaArtwork(
                                      id: int.tryParse(item.id),
                                      uri: item.artUri,
                                      label: item.title,
                                      size: artworkSize,
                                      radius: 30),
                                )),
                          )),
                          const SizedBox(height: 28),
                          Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                          letterSpacing: -.6)),
                                  const SizedBox(height: 7),
                                  Text(
                                      knownMetadata(
                                          item.artist, 'Bilinmeyen sanatçı'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant)),
                                ])),
                            IconButton(
                                tooltip: song != null && m.isFavorite(song)
                                    ? 'Favorilerden çıkar'
                                    : 'Favorilere ekle',
                                onPressed: song == null
                                    ? null
                                    : () => runMusicAction(c, () async {
                                          await m.toggleFavorite(song);
                                        }),
                                icon: Icon(
                                    song != null && m.isFavorite(song)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: song != null && m.isFavorite(song)
                                        ? scheme.primary
                                        : scheme.onSurface)),
                          ]),
                          const SizedBox(height: 24),
                          MusicSeekBar(music: m),
                          const SizedBox(height: 14),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StreamBuilder<bool>(
                                    stream: m.player.shuffleModeEnabledStream,
                                    builder: (c, snapshot) {
                                      final selected = snapshot.data ??
                                          m.player.shuffleModeEnabled;
                                      return IconButton(
                                          tooltip: selected
                                              ? 'Karışık çalmayı kapat'
                                              : 'Karışık çal',
                                          onPressed: () => runMusicAction(
                                              c, m.toggleShuffle),
                                          icon: Icon(Icons.shuffle_rounded,
                                              color: selected
                                                  ? scheme.primary
                                                  : scheme.onSurfaceVariant));
                                    }),
                                IconButton(
                                    tooltip: 'Önceki şarkı',
                                    style: IconButton.styleFrom(
                                        padding: EdgeInsets.zero),
                                    onPressed: () =>
                                        runMusicAction(c, m.previous),
                                    icon: const Icon(
                                        Icons.skip_previous_rounded,
                                        size: 38)),
                                PlayerPlayButton(music: m, size: 72),
                                IconButton(
                                    tooltip: 'Sonraki şarkı',
                                    style: IconButton.styleFrom(
                                        padding: EdgeInsets.zero),
                                    onPressed: () => runMusicAction(c, m.next),
                                    icon: const Icon(Icons.skip_next_rounded,
                                        size: 38)),
                                StreamBuilder<LoopMode>(
                                    stream: m.player.loopModeStream,
                                    builder: (c, snapshot) {
                                      final mode =
                                          snapshot.data ?? m.player.loopMode;
                                      return IconButton(
                                          tooltip: switch (mode) {
                                            LoopMode.off => 'Tekrar kapalı',
                                            LoopMode.all =>
                                              'Tüm sırayı tekrar et',
                                            LoopMode.one =>
                                              'Bu şarkıyı tekrar et',
                                          },
                                          onPressed: () => runMusicAction(
                                              c, m.cycleRepeatMode),
                                          icon: Icon(
                                              mode == LoopMode.one
                                                  ? Icons.repeat_one_rounded
                                                  : Icons.repeat_rounded,
                                              color: mode == LoopMode.off
                                                  ? scheme.onSurfaceVariant
                                                  : scheme.primary));
                                    }),
                              ]),
                          const SizedBox(height: 16),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    tooltip: '10 saniye geri',
                                    onPressed: () => runMusicAction(
                                        c, () => m.seekRelative(-10)),
                                    icon: const Icon(Icons.replay_10_rounded,
                                        size: 24)),
                                StreamBuilder<double>(
                                    stream: m.player.speedStream,
                                    builder: (c, snapshot) => TextButton(
                                        onPressed: () => _speed(c, m),
                                        child: Text(
                                            '${(snapshot.data ?? m.player.speed).toStringAsFixed(2).replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), "")}×',
                                            style: TextStyle(
                                                color:
                                                    scheme.onSurfaceVariant)))),
                                IconButton(
                                    tooltip: '10 saniye ileri',
                                    onPressed: () => runMusicAction(
                                        c, () => m.seekRelative(10)),
                                    icon: const Icon(Icons.forward_10_rounded,
                                        size: 24)),
                              ]),
                          const SizedBox(height: 14),
                          DecoratedBox(
                              decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: scheme.outline
                                          .withValues(alpha: .55))),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _PlayerTool(
                                        icon: Icons.volume_up_rounded,
                                        label: 'Ses',
                                        onTap: () => _volume(c, m)),
                                    _PlayerTool(
                                        icon: Icons.bedtime_outlined,
                                        label: 'Uyku',
                                        onTap: () => showSleepTimer(c)),
                                    _PlayerTool(
                                        icon: Icons.queue_music_rounded,
                                        label: 'Çalma sırası',
                                        onTap: () => showPlaybackQueue(c, m)),
                                  ])),
                        ]);
                  });
            },
          ),
        )),
      ),
    );
  }

  Future<void> _speed(BuildContext context, LocalMusicService music) =>
      showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (c) => SafeArea(
                child: StreamBuilder<double>(
                    stream: music.player.speedStream,
                    builder: (c, snapshot) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListTile(
                                title: Text('Oynatma hızı',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800))),
                            for (final speed in [.5, .75, 1.0, 1.25, 1.5, 2.0])
                              ListTile(
                                  title: Text(
                                      speed == 1 ? 'Normal · 1×' : '$speed×'),
                                  trailing:
                                      (snapshot.data ?? music.player.speed) ==
                                              speed
                                          ? const Icon(Icons.check_rounded)
                                          : null,
                                  onTap: () async {
                                    await runMusicAction(
                                        c, () => music.player.setSpeed(speed));
                                    if (c.mounted) Navigator.pop(c);
                                  }),
                          ],
                        )),
              ));

  Future<void> _volume(BuildContext context, LocalMusicService music) =>
      showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (c) => SafeArea(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: StreamBuilder<double>(
                      stream: music.player.volumeStream,
                      builder: (c, snapshot) {
                        final volume = snapshot.data ?? music.player.volume;
                        return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Uygulama sesi · ${(volume * 100).round()}%',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 18),
                              Slider(
                                  value: volume.clamp(0, 1),
                                  onChanged: (value) =>
                                      music.player.setVolume(value),
                                  onChangeEnd: (value) => PlayerPreferences
                                      .instance
                                      .set('volume', value)),
                              Text(
                                  'Telefonunun ses tuşları cihaz sesini yönetir.',
                                  style: TextStyle(
                                      color: Theme.of(c)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ]);
                      },
                    )),
              ));
}

class _PlayerTool extends StatelessWidget {
  const _PlayerTool(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(children: [
                Icon(icon, size: 22),
                const SizedBox(height: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600))
              ]))));
}

class PlayerPlayButton extends StatelessWidget {
  const PlayerPlayButton({super.key, required this.music, this.size = 48});
  final LocalMusicService music;
  final double size;
  @override
  Widget build(BuildContext context) => StreamBuilder<PlayerState>(
        stream: music.player.playerStateStream,
        builder: (c, snapshot) {
          final state = snapshot.data ?? music.player.playerState;
          final loading = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
          final playing = state.playing &&
              state.processingState != ProcessingState.completed;
          return SizedBox.square(
              dimension: size,
              child: IconButton.filled(
                tooltip: playing ? 'Duraklat' : 'Oynat',
                onPressed: () => runMusicAction(c, music.togglePlayPause),
                style: IconButton.styleFrom(padding: EdgeInsets.zero),
                icon: loading
                    ? SizedBox.square(
                        dimension: size * .32,
                        child: const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: size * .52),
              ));
        },
      );
}

class MusicSeekBar extends StatefulWidget {
  const MusicSeekBar({super.key, required this.music});
  final LocalMusicService music;
  @override
  State<MusicSeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<MusicSeekBar> {
  double? _drag;
  @override
  Widget build(BuildContext context) => StreamBuilder<Duration?>(
        stream: widget.music.player.durationStream,
        builder: (c, durationSnapshot) => StreamBuilder<Duration>(
          stream: widget.music.player.positionStream,
          builder: (c, snapshot) {
            final duration = durationSnapshot.data ??
                widget.music.player.duration ??
                Duration.zero;
            final max =
                duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
            final value = (_drag ??
                    (snapshot.data ?? widget.music.player.position)
                        .inMilliseconds
                        .toDouble())
                .clamp(0.0, max);
            return Column(children: [
              SliderTheme(
                  data: SliderTheme.of(c).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16)),
                  child: Slider(
                      value: value,
                      max: max,
                      semanticFormatterCallback: (v) =>
                          formatMusicTime(Duration(milliseconds: v.round())),
                      onChanged: duration == Duration.zero
                          ? null
                          : (v) => setState(() => _drag = v),
                      onChangeEnd: (v) async {
                        await runMusicAction(
                            c,
                            () => widget.music
                                .seek(Duration(milliseconds: v.round())));
                        if (mounted) setState(() => _drag = null);
                      })),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(formatMusicTime(Duration(milliseconds: value.round())),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(c).colorScheme.onSurfaceVariant)),
                Text(formatMusicTime(duration),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(c).colorScheme.onSurfaceVariant)),
              ]),
            ]);
          },
        ),
      );
}

Future<void> showSleepTimer(BuildContext context, {SleepTimer? timer}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      showDragHandle: true,
      builder: (c) {
        final insights = MusicInsightsService.instance;
        final sleep = timer ?? insights.sleepTimer;
        return SafeArea(
            child: SingleChildScrollView(
                child: StreamBuilder<void>(
                    stream: insights.changes,
                    builder: (c, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListTile(
                                leading: Icon(Icons.bedtime_outlined),
                                title: Text('Uyku zamanlayıcısı',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800))),
                            if (sleep.endsAt != null)
                              ListTile(
                                  subtitle: Text(
                                      'Müzik ${formatMusicTime(sleep.endsAt!.difference(DateTime.now()))} sonra duraklayacak.')),
                            if (sleep.afterTrack)
                              const ListTile(
                                  subtitle: Text(
                                      'Bu şarkının sonunda duraklayacak.')),
                            for (final minutes in [
                              15,
                              30,
                              45,
                              60,
                              90,
                              120,
                              180
                            ])
                              ListTile(
                                  title: Text('$minutes dakika'),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () {
                                    sleep.start(Duration(minutes: minutes));
                                    Navigator.pop(c);
                                  }),
                            ListTile(
                                leading: const Icon(Icons.music_note_rounded),
                                title: const Text('Bu şarkı bitince durdur'),
                                onTap: () {
                                  sleep.stopAfterTrack();
                                  Navigator.pop(c);
                                }),
                            if (sleep.isActive)
                              ListTile(
                                  leading: const Icon(Icons.close_rounded),
                                  title: const Text('Zamanlayıcıyı iptal et'),
                                  onTap: () {
                                    sleep.cancel();
                                    Navigator.pop(c);
                                  }),
                            const SizedBox(height: 12),
                          ],
                        ))));
      },
    );
