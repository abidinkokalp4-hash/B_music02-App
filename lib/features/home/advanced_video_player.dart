import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/platform/device_controls.dart';
import '../../core/platform/media_files.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/local_video_engine.dart';
import '../../core/services/video_library.dart';
import '../../core/services/video_preferences.dart';
import 'video_player_controls.dart';

/// Flutter video player (used for formats the native player cannot decode,
/// such as many MPEG-2 .mpg files, and for opened links). With a [playlist]
/// it works like reels: swipe vertically in the middle to change video.
class LocalVideoPlayerScreen extends StatefulWidget {
  const LocalVideoPlayerScreen({
    super.key,
    this.file,
    this.uri,
    this.title = 'Video',
    this.mediaId,
    this.playlist,
    this.index = 0,
  });
  final File? file;
  final String? uri;
  final String title;
  final String? mediaId;
  final List<LocalVideo>? playlist;
  final int index;
  @override
  State<LocalVideoPlayerScreen> createState() => _AdvancedVideoPlayerState();
}

class _AdvancedVideoPlayerState extends State<LocalVideoPlayerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  LocalVideoEngine? engine;
  Future<void> pending = Future.value();
  int generation = 0, at = 0;
  String? path, error, feedback, seekLabel;
  late String title = widget.title;
  late String mediaId = widget.mediaId ?? widget.uri ?? widget.file?.path ?? '';
  Timer? hideTimer, feedbackTimer, levelTimer;
  bool controls = true, locked = false, fitCover = false, menuOpen = false;
  bool rotating = false, exiting = false, holding = false, levelVisible = false;
  double? scrub;
  int lastSavedSecond = -1;
  // Gestures.
  Offset doubleTap = Offset.zero, dragStart = Offset.zero;
  VideoDrag? drag;
  bool zooming = false;
  double zoom = 1, baseZoom = 1, startLevel = .5, brightness = -1;
  double pageOffset = 0, previousSpeed = 1;
  Duration seekStart = Duration.zero, seekTarget = Duration.zero;
  VideoDrag levelKind = VideoDrag.volume;
  double levelValue = 0;
  late final AnimationController slide = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 180))
    ..addListener(
        () => setState(() => pageOffset = slideTween.evaluate(slide)));
  Tween<double> slideTween = Tween(begin: 0, end: 0);

  List<LocalVideo> get playlist => widget.playlist ?? const [];
  bool get reels => playlist.length > 1;
  bool get ready => engine?.value.isInitialized == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    at = widget.playlist == null
        ? 0
        : widget.index.clamp(0, playlist.length - 1);
    unawaited(enterFullscreen());
    unawaited(DeviceControls.brightness().then((v) => brightness = v));
    open(at, file: widget.file);
  }

  Future<void> enterFullscreen() async {
    try {
      await DeviceControls.videoFullscreen(true);
    } catch (_) {}
    // Immersive: the video fills the screen; system bars return on an edge swipe.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> savePosition() async {
    final player = engine;
    if (player == null || !player.value.isInitialized || mediaId.isEmpty)
      return;
    try {
      await VideoPreferences.instance
          .record(mediaId, player.value.position, player.value.duration);
    } catch (_) {/* Playback remains available if history cannot be saved. */}
  }

  /// Opens list item [index] (or the single file/uri), serialising teardown so
  /// fast swipes never play two videos at once.
  void open(int index, {File? file}) {
    final token = ++generation;
    engine?.pause();
    final previous = engine;
    if (previous != null) unawaited(savePosition());
    setState(() {
      at = index;
      error = null;
      if (widget.playlist != null) {
        title = playlist[index].title;
        mediaId = playlist[index].asset.id;
      }
    });
    pending = pending.catchError((_) {}).then((_) async {
      engine = null;
      if (previous != null) {
        previous.removeListener(changed);
        await previous.close();
      }
      if (!mounted || token != generation) return;
      try {
        await LocalMusicService.instance.pause();
        await VideoPreferences.instance.load();
        String? source = widget.uri;
        if (widget.playlist != null) {
          final video = playlist[index];
          source = (file ?? await video.asset.file)?.path;
          if (index != widget.index) {
            await VideoPreferences.instance.markSeen(video.asset.id);
            await VideoPreferences.instance.countPlay(video.asset.id);
          }
        } else {
          source ??= widget.file?.path;
        }
        if (source == null) throw StateError('Dosya erişilemiyor');
        if (!mounted || token != generation) return;
        final player = LocalVideoEngine(source);
        engine = player;
        path = source;
        player.addListener(changed);
        await player.initialize(
            start: VideoPreferences.instance.position(mediaId));
        if (!mounted || token != generation || exiting) return;
        await player.play();
        lastSavedSecond = -1;
        unawaited(savePosition());
        scheduleHide();
        if (mounted) setState(() {});
      } catch (_) {
        if (mounted && token == generation) {
          setState(() => error = reels
              ? 'Bu video açılamadı. Kaydırarak diğer videolara geçebilirsin.'
              : 'Video açılamadı. Dosya bozuk, silinmiş veya biçimi desteklenmiyor olabilir.');
        }
      }
    });
  }

  void changed() {
    final player = engine;
    if (player == null) return;
    if (player.value.isInitialized &&
        (player.value.position.inSeconds - lastSavedSecond).abs() >= 5) {
      lastSavedSecond = player.value.position.inSeconds;
      debugPrint('[BMusic feature] software-position=${lastSavedSecond}s');
      unawaited(savePosition());
    }
    if (mounted) {
      setState(() {});
      if (!player.value.isPlaying && !locked && drag == null && !holding)
        controls = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(savePosition());
      engine?.pause();
    }
    if (state == AppLifecycleState.resumed && !exiting)
      unawaited(enterFullscreen());
  }

  Future<void> restoreDisplay() async {
    await SystemChrome.setPreferredOrientations([]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await DeviceControls.setBrightness(null);
    try {
      await DeviceControls.videoFullscreen(false);
    } catch (_) {}
  }

  Future<void> exitPlayer() async {
    if (exiting) return;
    exiting = true;
    await engine?.pause();
    await savePosition();
    try {
      await restoreDisplay();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    ++generation;
    WidgetsBinding.instance.removeObserver(this);
    hideTimer?.cancel();
    feedbackTimer?.cancel();
    levelTimer?.cancel();
    unawaited(savePosition());
    final player = engine;
    player?.removeListener(changed);
    pending.whenComplete(() => player?.close());
    slide.dispose();
    if (!exiting) unawaited(restoreDisplay());
    super.dispose();
  }

  void scheduleHide() {
    hideTimer?.cancel();
    if (engine?.value.isPlaying == true && !menuOpen && scrub == null) {
      hideTimer = Timer(const Duration(milliseconds: 3500), () {
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
    final player = engine;
    if (player == null || !ready) return;
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
    final player = engine;
    if (player == null || !ready || locked) return;
    await player.seekTo(boundedVideoPosition(
        player.value.position + Duration(seconds: seconds),
        player.value.duration));
    showFeedback(seconds < 0 ? '−10 saniye' : '+10 saniye');
    scheduleHide();
  }

  // ---- Gestures -----------------------------------------------------------
  void showLevel(VideoDrag kind, double value) {
    levelTimer?.cancel();
    setState(() {
      levelKind = kind;
      levelValue = value;
      levelVisible = true;
    });
    levelTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => levelVisible = false);
    });
  }

  void dragStarted(ScaleStartDetails d) {
    if (locked) return;
    zooming = d.pointerCount > 1;
    baseZoom = zoom;
    dragStart = d.localFocalPoint;
    drag = null;
  }

  void dragUpdated(ScaleUpdateDetails d, Size size) {
    if (locked) return;
    if (zooming || d.pointerCount > 1) {
      if (drag == VideoDrag.page) return;
      zooming = true;
      setState(() => zoom = (baseZoom * d.scale).clamp(1.0, 5.0));
      return;
    }
    final delta = d.localFocalPoint - dragStart;
    final player = engine;
    if (drag == null) {
      if (delta.distance < 18 || slide.isAnimating) return;
      drag = videoDragFor(
          startX: dragStart.dx,
          width: size.width,
          dx: delta.dx,
          dy: delta.dy,
          reels: reels);
      hideTimer?.cancel();
      switch (drag!) {
        case VideoDrag.seek:
          seekStart = player?.value.position ?? Duration.zero;
        case VideoDrag.brightness:
          startLevel = brightness < 0 ? .5 : brightness;
        case VideoDrag.volume:
          startLevel = player?.value.volume ?? 1;
        case VideoDrag.page:
          break;
      }
    }
    switch (drag!) {
      case VideoDrag.seek:
        if (player == null || !ready) return;
        final total = player.value.duration;
        final window = Duration(
            milliseconds: (total.inMilliseconds ~/ 20).clamp(30000, 180000));
        seekTarget = boundedVideoPosition(
            seekStart + window * (delta.dx / size.width), total);
        final change = (seekTarget - seekStart).inSeconds;
        setState(() => seekLabel =
            '${change >= 0 ? '+' : ''}$change sn • ${videoTime(seekTarget)}');
      case VideoDrag.brightness:
        final level =
            (startLevel - delta.dy / size.height * 1.5).clamp(.02, 1.0);
        brightness = level;
        unawaited(DeviceControls.setBrightness(level));
        showLevel(VideoDrag.brightness, level);
      case VideoDrag.volume:
        final level =
            (startLevel - delta.dy / size.height * 1.5).clamp(0.0, 1.0);
        unawaited(player?.setVolume(level));
        showLevel(VideoDrag.volume, level);
      case VideoDrag.page:
        final edge = (at == 0 && delta.dy > 0) ||
            (at == playlist.length - 1 && delta.dy < 0);
        setState(() => pageOffset = edge ? delta.dy / 4 : delta.dy);
    }
  }

  void dragEnded(ScaleEndDetails d, Size size) {
    final mode = drag;
    drag = null;
    zooming = false;
    if (mode == VideoDrag.seek) {
      unawaited(engine?.seekTo(seekTarget));
      setState(() => seekLabel = null);
    } else if (mode == VideoDrag.page) {
      final direction = pageOffset < 0 ? 1 : -1;
      final target = at + direction;
      final fast = d.velocity.pixelsPerSecond.dy.abs() > 900;
      if ((pageOffset.abs() > size.height * .18 || fast) &&
          target >= 0 &&
          target < playlist.length) {
        animatePage(-direction * size.height, () {
          open(target);
          pageOffset = direction * size.height;
          animatePage(0, null);
        });
      } else {
        if (pageOffset.abs() > size.height * .18)
          showFeedback(direction > 0 ? 'Listenin sonu' : 'Listenin başı');
        animatePage(0, null);
      }
    }
    scheduleHide();
  }

  void animatePage(double to, VoidCallback? done) {
    slideTween = Tween(begin: pageOffset, end: to);
    slide.forward(from: 0).whenComplete(() {
      if (mounted) done?.call();
    });
  }

  void holdStarted(LongPressStartDetails d, Size size) {
    final player = engine;
    if (locked ||
        player == null ||
        !ready ||
        d.localPosition.dx < size.width / 2) return;
    previousSpeed = player.value.playbackSpeed;
    holding = true;
    unawaited(player.setPlaybackSpeed(2));
    setState(() {});
  }

  void holdEnded() {
    if (!holding) return;
    holding = false;
    unawaited(engine?.setPlaybackSpeed(previousSpeed));
    setState(() {});
  }

  // ---- Tools ----------------------------------------------------------------
  Future<void> rotate() async {
    if (rotating) return;
    rotating = true;
    hideTimer?.cancel();
    try {
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      await SystemChrome.setPreferredOrientations(landscape
          ? [DeviceOrientation.portraitUp]
          : [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight
            ]);
      setState(() => zoom = 1);
      await enterFullscreen();
    } finally {
      rotating = false;
      scheduleHide();
    }
  }

  Future<void> speedMenu() async {
    final player = engine;
    if (player == null) return;
    menuOpen = true;
    hideTimer?.cancel();
    final speed = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF17131F),
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
                title: Text('Oynatma hızı',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [.25, .5, .75, 1.0, 1.25, 1.5, 1.75, 2.0]
                    .map((v) => ChoiceChip(
                        label: Text('$v×'),
                        selected: player.value.playbackSpeed == v,
                        onSelected: (_) => Navigator.pop(c, v)))
                    .toList()),
            const SizedBox(height: 24),
          ]),
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

  Future<void> shareVideo() async {
    if (path == null) return;
    try {
      await MediaFiles.share(path!, title);
    } catch (_) {
      if (mounted)
        showFeedback('Video paylaşılamadı. Dosya erişimini kontrol edin.');
    }
  }

  Future<void> capture() async {
    final player = engine;
    if (player == null || !ready) return;
    try {
      final bytes = await player.screenshot();
      if (bytes == null) throw StateError('Kare yok');
      await MediaFiles.saveImage(bytes);
      if (mounted) showFeedback('Fotoğraf galeriye kaydedildi');
    } catch (_) {
      if (mounted)
        showFeedback('Bu kare kaydedilemedi. Videoyu oynatıp tekrar deneyin.');
    }
  }

  /// Kes: choose any start/end, preview it and save it as a new MP4.
  Future<void> trim() async {
    final player = engine;
    final source = path;
    if (player == null || !ready || source == null) return;
    final total = player.value.duration;
    if (total <= Duration.zero)
      return showFeedback('Önce videonun açılmasını bekleyin');
    await player.pause();
    menuOpen = true;
    hideTimer?.cancel();
    final totalMs = total.inMilliseconds.toDouble();
    var range = RangeValues(
      player.value.position.inMilliseconds.toDouble().clamp(0, totalMs),
      (player.value.position.inMilliseconds + 30000)
          .toDouble()
          .clamp(0, totalMs),
    );
    if (range.end - range.start < 1000)
      range = RangeValues((totalMs - 30000).clamp(0, totalMs), totalMs);
    if (!mounted) return;
    final save = await showModalBottomSheet<RangeValues>(
      context: context,
      backgroundColor: const Color(0xFF17131F),
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
          builder: (c, update) => SafeArea(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Videoyu kes',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                          'Başlangıç ${videoTime(Duration(milliseconds: range.start.round()))} • Bitiş ${videoTime(Duration(milliseconds: range.end.round()))}\n'
                          'Seçilen süre ${videoTime(Duration(milliseconds: (range.end - range.start).round()))}',
                          style: const TextStyle(color: Colors.white70)),
                      RangeSlider(
                        values: range,
                        min: 0,
                        max: totalMs,
                        activeColor: const Color(0xFFB94BFF),
                        labels: RangeLabels(
                            videoTime(
                                Duration(milliseconds: range.start.round())),
                            videoTime(
                                Duration(milliseconds: range.end.round()))),
                        onChanged: (v) {
                          if (v.end - v.start < 500) return;
                          update(() => range = v);
                          unawaited(player.seekTo(Duration(
                              milliseconds:
                                  (v.start != range.start ? v.start : v.end)
                                      .round())));
                        },
                      ),
                      Row(children: [
                        TextButton.icon(
                            onPressed: () async {
                              await player.seekTo(
                                  Duration(milliseconds: range.start.round()));
                              await player.play();
                              final end =
                                  Duration(milliseconds: range.end.round());
                              void stopAtEnd() {
                                if (player.value.position >= end) {
                                  player.removeListener(stopAtEnd);
                                  unawaited(player.pause());
                                }
                              }

                              player.addListener(stopAtEnd);
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Önizle')),
                        const Spacer(),
                        TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('İptal')),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                            onPressed: () => Navigator.pop(c, range),
                            icon: const Icon(Icons.content_cut),
                            label: const Text('Kaydet')),
                      ]),
                    ]),
              ))),
    );
    menuOpen = false;
    await player.pause();
    if (save == null || !mounted) return scheduleHide();
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
                content: Row(children: [
              CircularProgressIndicator(),
              SizedBox(width: 18),
              Expanded(child: Text('Klip hazırlanıyor…'))
            ])));
    String message;
    try {
      final name = await DeviceControls.trimVideo(
          source,
          Duration(milliseconds: save.start.round()),
          Duration(milliseconds: save.end.round()));
      message = 'Klip kaydedildi: ${name ?? 'Movies/BMusic'}';
      unawaited(VideoLibrary.instance.refreshNew());
    } on PlatformException catch (e) {
      message = e.message ?? 'Video kesilemedi';
    } catch (_) {
      message = 'Video kesme bu cihazda kullanılamıyor';
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    showFeedback(message);
    scheduleHide();
  }

  Future<void> audioOnly() async {
    final player = engine;
    if (player == null || path == null) return;
    await player.pause();
    try {
      await LocalMusicService.instance
          .playExternal(path!, title, position: player.value.position);
      await exitPlayer();
    } catch (_) {
      if (mounted)
        showFeedback('Bu videonun sesi müzik oynatıcısında desteklenmiyor.');
    }
  }

  Widget button(IconData icon, String label, VoidCallback? action,
          {bool active = false}) =>
      IconButton(
        tooltip: label,
        onPressed: action,
        icon:
            Icon(icon, color: active ? const Color(0xFFCF64FF) : Colors.white),
        style: IconButton.styleFrom(backgroundColor: Colors.black26),
      );

  Widget levelBar() {
    final brightnessBar = levelKind == VideoDrag.brightness;
    return Align(
      alignment: brightnessBar ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: levelVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Semantics(
              label: brightnessBar ? 'Parlaklık' : 'Ses',
              value: '%${(levelValue * 100).round()}',
              child: Container(
                width: 42,
                height: 180,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(21)),
                child: Column(children: [
                  Icon(
                      brightnessBar
                          ? Icons.brightness_6
                          : (levelValue == 0
                              ? Icons.volume_off
                              : Icons.volume_up),
                      color: Colors.white,
                      size: 20),
                  const SizedBox(height: 8),
                  Expanded(
                      child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                        width: 6,
                        child:
                            Stack(alignment: Alignment.bottomCenter, children: [
                          const ColoredBox(
                              color: Colors.white24, child: SizedBox.expand()),
                          FractionallySizedBox(
                              heightFactor: levelValue.clamp(0, 1),
                              child: const ColoredBox(
                                  color: Color(0xFFCF64FF),
                                  child: SizedBox.expand())),
                        ])),
                  )),
                  const SizedBox(height: 6),
                  Text('${(levelValue * 100).round()}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget pill(String text, {double size = 18}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xBF000000),
            borderRadius: BorderRadius.circular(14)),
        child:
            Text(text, style: TextStyle(color: Colors.white, fontSize: size)),
      );

  @override
  Widget build(BuildContext context) {
    final player = engine;
    final v = player?.value;
    final failed = error != null || v?.hasError == true;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (locked) {
          setState(() {
            locked = false;
            controls = true;
          });
          scheduleHide();
        } else {
          exitPlayer();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(builder: (context, size) {
          final compact = size.maxHeight < 420;
          final area = Size(size.maxWidth, size.maxHeight);
          return Stack(fit: StackFit.expand, children: [
            // Video layer (follows the finger while paging) and the gesture surface.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: toggleControls,
                onDoubleTapDown: (d) => doubleTap = d.localPosition,
                onDoubleTap: locked
                    ? null
                    : () => seekBy(doubleTap.dx < size.maxWidth / 2 ? -10 : 10),
                onLongPressStart: (d) => holdStarted(d, area),
                onLongPressEnd: (_) => holdEnded(),
                onLongPressCancel: holdEnded,
                onScaleStart: dragStarted,
                onScaleUpdate: (d) => dragUpdated(d, area),
                onScaleEnd: (d) => dragEnded(d, area),
                child: ClipRect(
                  child: Transform.translate(
                    offset: Offset(0, pageOffset),
                    child: player != null && v != null && !failed
                        ? Transform.scale(
                            scale: zoom,
                            child: SizedBox.expand(
                              child: FittedBox(
                                fit: fitCover ? BoxFit.cover : BoxFit.contain,
                                child: SizedBox(
                                  width: v.size.width,
                                  height: v.size.height,
                                  child: Video(
                                      controller: player.controller,
                                      controls: NoVideoControls),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            if (!ready && !failed)
              const IgnorePointer(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFCF64FF)))),
            if (failed)
              Center(
                  child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white70, size: 48),
                  const SizedBox(height: 16),
                  Text(error ?? 'Bu video oynatılamadı.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: exitPlayer,
                      child: const Text('Videolara dön')),
                ]),
              )),
            if (ready && v!.isBuffering)
              const IgnorePointer(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFCF64FF)))),
            if (feedback != null || seekLabel != null)
              IgnorePointer(
                  child: Align(
                alignment: const Alignment(0, -.35),
                child: pill(seekLabel ?? feedback!,
                    size: seekLabel != null ? 15 : 18),
              )),
            levelBar(),
            if (holding)
              IgnorePointer(
                  child: SafeArea(
                      child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                    padding: const EdgeInsets.only(top: 56),
                    child: Semantics(
                        label: '2× hız', child: pill('2×  ▶▶', size: 14))),
              ))),
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
                            colors: [Colors.black87, Colors.transparent])),
                    child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
                          child: Row(children: [
                            button(Icons.arrow_back, 'Geri', exitPlayer),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16))),
                            button(Icons.share, 'Videoyu paylaş', shareVideo),
                            button(Icons.lock_open, 'Ekranı kilitle', () {
                              setState(() => locked = true);
                              scheduleHide();
                            }),
                          ]),
                        )),
                  )),
              if (ready && !failed)
                Align(
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      button(
                          Icons.replay_10, '10 saniye geri', () => seekBy(-10)),
                      SizedBox(width: compact ? 24 : 36),
                      IconButton.filled(
                        tooltip: v!.isPlaying ? 'Duraklat' : 'Oynat',
                        iconSize: compact ? 40 : 52,
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xBFA53CFF),
                            padding: const EdgeInsets.all(12)),
                        onPressed: togglePlay,
                        icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white),
                      ),
                      SizedBox(width: compact ? 24 : 36),
                      button(Icons.forward_10, '10 saniye ileri',
                          () => seekBy(10)),
                    ])),
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
                              colors: [Colors.transparent, Colors.black87])),
                      child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                12, compact ? 12 : 24, 12, 8),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(children: [
                                    Text(
                                        videoTime(Duration(
                                            milliseconds: (scrub ??
                                                    v!.position.inMilliseconds
                                                        .toDouble())
                                                .round())),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12)),
                                    Expanded(
                                        child: Slider(
                                      activeColor: const Color(0xFFB94BFF),
                                      inactiveColor: Colors.white24,
                                      value: (scrub ??
                                              v!.position.inMilliseconds
                                                  .toDouble())
                                          .clamp(
                                              0,
                                              v!.duration.inMilliseconds
                                                  .toDouble()
                                                  .clamp(1, double.infinity)),
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
                                        await player!.seekTo(Duration(
                                            milliseconds: value.round()));
                                        if (mounted)
                                          setState(() => scrub = null);
                                        scheduleHide();
                                      },
                                    )),
                                    Text(videoTime(v.duration),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12)),
                                  ]),
                                  SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(children: [
                                        button(Icons.photo_camera_outlined,
                                            'Fotoğraf al', capture),
                                        button(Icons.content_cut, 'Videoyu kes',
                                            trim),
                                        button(Icons.headphones,
                                            'Ses olarak dinle', audioOnly),
                                        TextButton(
                                            onPressed: speedMenu,
                                            child: Text('${v.playbackSpeed}×',
                                                style: const TextStyle(
                                                    color: Colors.white))),
                                        button(
                                            fitCover
                                                ? Icons.crop
                                                : Icons.fit_screen,
                                            fitCover
                                                ? 'Ekrana sığdır'
                                                : 'Ekranı doldur', () {
                                          setState(() {
                                            fitCover = !fitCover;
                                            zoom = 1;
                                          });
                                          showFeedback(fitCover
                                              ? 'Ekranı doldur'
                                              : 'Ekrana sığdır');
                                          scheduleHide();
                                        }, active: fitCover),
                                        button(Icons.zoom_out_map,
                                            'Yakınlaştırmayı sıfırla', () {
                                          setState(() => zoom = 1);
                                          showFeedback(
                                              'Yakınlaştırma sıfırlandı');
                                          scheduleHide();
                                        }),
                                        button(Icons.repeat, 'Tekrar oynat',
                                            () {
                                          player!.setLooping(!v.isLooping);
                                          scheduleHide();
                                        }, active: v.isLooping),
                                        button(
                                            v.volume == 0
                                                ? Icons.volume_off
                                                : Icons.volume_up,
                                            'Sesi aç/kapat', () {
                                          player!
                                              .setVolume(v.volume == 0 ? 1 : 0);
                                          scheduleHide();
                                        }),
                                        button(Icons.screen_rotation,
                                            'Yatay / dikey döndür', rotate),
                                      ])),
                                ]),
                          )),
                    )),
            ],
            if (locked && controls)
              Positioned(
                  right: 16,
                  top: 16,
                  child: SafeArea(
                      child: button(Icons.lock, 'Kilidi aç', () {
                    setState(() => locked = false);
                    scheduleHide();
                  }, active: true))),
            if ((!ready || failed) && !controls)
              Positioned(
                  top: 16,
                  left: 16,
                  child: SafeArea(
                      child: button(Icons.arrow_back, 'Geri', exitPlayer))),
          ]);
        }),
      ),
    );
  }
}
