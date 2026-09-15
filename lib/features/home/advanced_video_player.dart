import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/platform/device_controls.dart';
import '../../core/services/local_music_service.dart';
import 'video_player_controls.dart';

class LocalVideoPlayerScreen extends StatefulWidget {
  const LocalVideoPlayerScreen({
    super.key,
    required this.file,
    required this.title,
  });
  final File file;
  final String title;
  @override
  State<LocalVideoPlayerScreen> createState() => _AdvancedVideoPlayerState();
}

class _AdvancedVideoPlayerState extends State<LocalVideoPlayerScreen>
    with WidgetsBindingObserver {
  late final VideoPlayerController player;
  final transform = TransformationController();
  Timer? hideTimer, feedbackTimer;
  bool controls = true,
      locked = false,
      fitCover = false,
      menuOpen = false,
      rotating = false,
      exiting = false;
  double? scrub;
  String? error, feedback;
  Offset doubleTap = Offset.zero;
  bool get ready => player.value.isInitialized;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    player = VideoPlayerController.file(
      widget.file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    player.addListener(changed);
    initialize();
  }

  Future<void> initialize() async {
    try {
      await DeviceControls.videoFullscreen(true);
      // Keep the existing music queue and position, but avoid simultaneous audio.
      await LocalMusicService.instance.pause();
      await player.initialize();
      if (!mounted || exiting) return;
      await player.play();
      scheduleHide();
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Video açılamadı. Dosya bozuk, silinmiş veya biçimi desteklenmiyor olabilir.',
        );
    }
  }

  void changed() {
    if (mounted) {
      setState(() {});
      if (!player.value.isPlaying && !locked) controls = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      player.pause();
    }
    if (state == AppLifecycleState.resumed && !exiting) {
      unawaited(DeviceControls.videoFullscreen(true));
    }
  }

  Future<void> restoreDisplay() async {
    await SystemChrome.setPreferredOrientations([]);
    await DeviceControls.videoFullscreen(false);
  }

  Future<void> exitPlayer() async {
    if (exiting) return;
    exiting = true;
    await player.pause();
    try {
      await restoreDisplay();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    hideTimer?.cancel();
    feedbackTimer?.cancel();
    player.removeListener(changed);
    player.dispose();
    transform.dispose();
    if (!exiting) unawaited(restoreDisplay());
    super.dispose();
  }

  void scheduleHide() {
    hideTimer?.cancel();
    if (player.value.isPlaying && !menuOpen && scrub == null) {
      hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => controls = false);
      });
    }
  }

  void toggleControls() {
    setState(() => controls = !controls);
    if (controls) scheduleHide();
  }

  void showFeedback(String text) {
    feedbackTimer?.cancel();
    setState(() => feedback = text);
    feedbackTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => feedback = null);
    });
  }

  Future<void> togglePlay() async {
    if (!ready) return;
    if (player.value.isPlaying) {
      await player.pause();
    } else {
      if (player.value.position >= player.value.duration)
        await player.seekTo(Duration.zero);
      await player.play();
    }
    setState(() => controls = true);
    scheduleHide();
  }

  Future<void> seekBy(int seconds) async {
    if (!ready || locked) return;
    await player.seekTo(
      boundedVideoPosition(
        player.value.position + Duration(seconds: seconds),
        player.value.duration,
      ),
    );
    showFeedback(seconds < 0 ? '−10 saniye' : '+10 saniye');
    scheduleHide();
  }

  Future<void> rotate() async {
    if (rotating) return;
    rotating = true;
    hideTimer?.cancel();
    try {
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      await SystemChrome.setPreferredOrientations(
        landscape
            ? [DeviceOrientation.portraitUp]
            : [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
      );
      transform.value = Matrix4.identity();
      await DeviceControls.videoFullscreen(true);
    } finally {
      rotating = false;
      scheduleHide();
    }
  }

  Future<void> speedMenu() async {
    menuOpen = true;
    hideTimer?.cancel();
    final speed = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF17131F),
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Oynatma hızı',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [.25, .5, .75, 1.0, 1.25, 1.5, 1.75, 2.0]
                    .map(
                      (v) => ChoiceChip(
                        label: Text('${v}×'),
                        selected: player.value.playbackSpeed == v,
                        onSelected: (_) => Navigator.pop(c, v),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    menuOpen = false;
    if (speed != null) {
      try {
        await player.setPlaybackSpeed(speed);
      } catch (_) {
        showFeedback('Bu hız cihazda desteklenmiyor.');
      }
    }
    scheduleHide();
  }

  Widget button(
    IconData icon,
    String label,
    VoidCallback? action, {
    bool active = false,
  }) => IconButton(
    tooltip: label,
    onPressed: action,
    icon: Icon(icon, color: active ? const Color(0xFFCF64FF) : Colors.white),
    style: IconButton.styleFrom(backgroundColor: Colors.black26),
  );
  @override
  Widget build(BuildContext context) {
    final v = player.value;
    final failed = error != null || v.hasError;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (locked) {
            setState(() {
              locked = false;
              controls = true;
            });
            scheduleHide();
          } else {
            exitPlayer();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, size) {
            final compact = size.maxHeight < 420;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (ready && !failed)
                  Positioned.fill(
                    child: ClipRect(
                      child: InteractiveViewer(
                        transformationController: transform,
                        minScale: 1,
                        maxScale: 5,
                        panEnabled: !locked,
                        scaleEnabled: !locked,
                        onInteractionStart: (_) {
                          hideTimer?.cancel();
                        },
                        onInteractionEnd: (_) => scheduleHide(),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: toggleControls,
                          onDoubleTapDown: (d) => doubleTap = d.localPosition,
                          onDoubleTap: locked
                              ? null
                              : () => seekBy(
                                  doubleTap.dx < size.maxWidth / 2 ? -10 : 10,
                                ),
                          child: SizedBox.expand(
                            child: FittedBox(
                              fit: fitCover ? BoxFit.cover : BoxFit.contain,
                              child: SizedBox(
                                width: v.size.width,
                                height: v.size.height,
                                child: VideoPlayer(player),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!ready && !failed)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFFCF64FF)),
                  ),
                if (failed)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white70,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            error ?? 'Bu video oynatılamadı.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: exitPlayer,
                            child: const Text('Videolara dön'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (ready && v.isBuffering)
                  const IgnorePointer(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFCF64FF),
                      ),
                    ),
                  ),
                if (feedback != null)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xBF000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          feedback!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (controls && !locked) ...[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
                          child: Row(
                            children: [
                              button(Icons.arrow_back, 'Geri', exitPlayer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              button(Icons.lock_open, 'Ekranı kilitle', () {
                                setState(() => locked = true);
                                scheduleHide();
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (ready && !failed)
                    Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          button(
                            Icons.replay_10,
                            '10 saniye geri',
                            () => seekBy(-10),
                          ),
                          SizedBox(width: compact ? 24 : 36),
                          IconButton.filled(
                            tooltip: v.isPlaying ? 'Duraklat' : 'Oynat',
                            iconSize: compact ? 40 : 52,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xBFA53CFF),
                              padding: const EdgeInsets.all(12),
                            ),
                            onPressed: togglePlay,
                            icon: Icon(
                              v.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: compact ? 24 : 36),
                          button(
                            Icons.forward_10,
                            '10 saniye ileri',
                            () => seekBy(10),
                          ),
                        ],
                      ),
                    ),
                  if (ready && !failed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              12,
                              compact ? 12 : 24,
                              12,
                              8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      videoTime(
                                        Duration(
                                          milliseconds:
                                              (scrub ??
                                                      v.position.inMilliseconds
                                                          .toDouble())
                                                  .round(),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        activeColor: const Color(0xFFB94BFF),
                                        inactiveColor: Colors.white24,
                                        value:
                                            (scrub ??
                                                    v.position.inMilliseconds
                                                        .toDouble())
                                                .clamp(
                                                  0,
                                                  v.duration.inMilliseconds
                                                      .toDouble(),
                                                ),
                                        max: v.duration.inMilliseconds
                                            .toDouble()
                                            .clamp(1, double.infinity),
                                        onChangeStart: (value) {
                                          hideTimer?.cancel();
                                          setState(() => scrub = value);
                                        },
                                        onChanged: (value) =>
                                            setState(() => scrub = value),
                                        onChangeEnd: (value) async {
                                          await player.seekTo(
                                            boundedVideoPosition(
                                              Duration(
                                                milliseconds: value.round(),
                                              ),
                                              v.duration,
                                            ),
                                          );
                                          if (mounted)
                                            setState(() => scrub = null);
                                          scheduleHide();
                                        },
                                      ),
                                    ),
                                    Text(
                                      videoTime(v.duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: speedMenu,
                                        child: Text(
                                          '${v.playbackSpeed}×',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      button(
                                        fitCover
                                            ? Icons.crop
                                            : Icons.fit_screen,
                                        fitCover
                                            ? 'Ekrana sığdır'
                                            : 'Ekranı doldur',
                                        () {
                                          setState(() => fitCover = !fitCover);
                                          transform.value = Matrix4.identity();
                                          showFeedback(
                                            fitCover
                                                ? 'Ekranı doldur'
                                                : 'Ekrana sığdır',
                                          );
                                          scheduleHide();
                                        },
                                        active: fitCover,
                                      ),
                                      button(
                                        Icons.zoom_out_map,
                                        'Yakınlaştırmayı sıfırla',
                                        () {
                                          transform.value = Matrix4.identity();
                                          showFeedback(
                                            'Yakınlaştırma sıfırlandı',
                                          );
                                          scheduleHide();
                                        },
                                      ),
                                      button(Icons.repeat, 'Tekrar oynat', () {
                                        player.setLooping(!v.isLooping);
                                        scheduleHide();
                                      }, active: v.isLooping),
                                      button(
                                        v.volume == 0
                                            ? Icons.volume_off
                                            : Icons.volume_up,
                                        'Sesi aç/kapat',
                                        () {
                                          player.setVolume(
                                            v.volume == 0 ? 1 : 0,
                                          );
                                          scheduleHide();
                                        },
                                      ),
                                      button(
                                        Icons.screen_rotation,
                                        'Yatay / dikey döndür',
                                        rotate,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!compact)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'İki parmakla yakınlaştır • Çift dokunarak 10 sn sar',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                if (locked && controls)
                  Positioned(
                    right: 16,
                    top: 16,
                    child: SafeArea(
                      child: button(Icons.lock, 'Kilidi aç', () {
                        setState(() => locked = false);
                        scheduleHide();
                      }, active: true),
                    ),
                  ),
                if (!ready && !controls)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: SafeArea(
                      child: button(Icons.arrow_back, 'Geri', exitPlayer),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
