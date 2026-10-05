import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/services/local_video_engine.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/video_library.dart';
import '../../core/services/video_preferences.dart';
import '../../core/platform/media_files.dart';
import '../../core/platform/device_controls.dart';
import 'advanced_video_player.dart';
import 'video_player_controls.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key, required this.videos});
  final List<LocalVideo> videos;
  @override
  State<VideoFeedScreen> createState() => _FeedState();
}
class _FeedState extends State<VideoFeedScreen> with WidgetsBindingObserver {
  LocalVideoEngine? engine;
  Future<void> pending = Future.value();
  int index = 0, generation = 0;
  String? path, error;
  bool active = true;
  final pages = PageController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(DeviceControls.videoFullscreen(true));
    change(0);
  }
  void change(int next) {
    final token = ++generation;
    setState(() { index = next; error = null; path = null; });
    // Pause immediately; serialize teardown/open so rapid swipes cannot overlap audio.
    engine?.pause();
    pending = pending.catchError((_) {}).then((_) async {
      final old = engine;
      engine = null;
      if (mounted) setState(() {});
      if (old != null) {
        old.removeListener(refresh);
        await old.close();
      }
      if (!mounted || token != generation || widget.videos.isEmpty) return;
      try {
        await LocalMusicService.instance.pause();
        final file = await widget.videos[next].asset.file;
        if (file == null) throw StateError('Dosya erişilemiyor');
        if (!mounted || token != generation) return;
        final player = LocalVideoEngine(file.path);
        engine = player;
        path = file.path;
        player.addListener(refresh);
        await player.initialize();
        await player.setLooping(true);
        if (!mounted || token != generation || !active) return;
        await player.play();
        refresh();
      } catch (_) { if (mounted && token == generation) setState(() => error = 'Bu video açılamadı. Kaydırarak devam edebilirsin.'); }
    });
  }
  void refresh() { if (mounted) setState(() {}); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (!active) engine?.pause();
  }
  @override
  void dispose() {
    ++generation;
    WidgetsBinding.instance.removeObserver(this);
    final player = engine;
    player?.removeListener(refresh);
    pending.whenComplete(() => player?.close());
    pages.dispose();
    unawaited(DeviceControls.videoFullscreen(false));
    super.dispose();
  }
  Future<void> share() async {
    if (path == null) return;
    try { await MediaFiles.share(path!, widget.videos[index].title); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video paylaşılamadı'))); }
  }
  Future<void> details() async {
    if (path == null) return;
    await engine?.pause();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LocalVideoPlayerScreen(
      uri: path!, title: widget.videos[index].title, mediaId: widget.videos[index].asset.id)));
    if (mounted) await DeviceControls.videoFullscreen(true);
  }
  @override
  Widget build(BuildContext c) => Scaffold(backgroundColor: Colors.black, body: widget.videos.isEmpty
    ? const Center(child: Text('Video bulunamadı')) : Stack(children: [
      PageView.builder(controller: pages, scrollDirection: Axis.vertical,
        itemCount: widget.videos.length, onPageChanged: change, itemBuilder: (c, i) {
          final video = widget.videos[i];
          final current = i == index ? engine : null;
          final v = current?.value;
          return Stack(fit: StackFit.expand, children: [
            GestureDetector(behavior: HitTestBehavior.opaque,
              onTap: () { if (current != null) { v!.isPlaying ? current.pause() : current.play(); } },
              child: current == null ? const Center(child: CircularProgressIndicator())
                : Video(controller: current.controller, controls: NoVideoControls, fit: BoxFit.contain)),
            if (i == index && (error != null || v?.hasError == true))
              Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(error ?? 'Video oynatılamadı. Sonraki videoya kaydır.', textAlign: TextAlign.center))),
            if (v != null && v.isInitialized && !v.isPlaying && !v.hasError)
              const IgnorePointer(child: Center(child: Icon(Icons.play_arrow_rounded, size: 80, color: Colors.white70))),
            Positioned(left: 16, right: 16, bottom: 20, child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [Expanded(child: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
                IconButton(tooltip: 'Videoyu paylaş', onPressed: current == null ? null : share, icon: const Icon(Icons.share, color: Colors.white)),
                IconButton(tooltip: 'Tam oynatıcı', onPressed: current == null ? null : details, icon: const Icon(Icons.open_in_full, color: Colors.white)),
              ]),
              if (v != null && v.duration > Duration.zero) Row(children: [
                Text(videoTime(v.position), style: const TextStyle(color: Colors.white)),
                Expanded(child: Slider(value: v.position.inMilliseconds.toDouble().clamp(0, v.duration.inMilliseconds.toDouble()),
                  max: v.duration.inMilliseconds.toDouble(), onChanged: (value) => current!.seekTo(Duration(milliseconds: value.round())))),
                Text(videoTime(v.duration), style: const TextStyle(color: Colors.white)),
              ]),
            ]))),
          ]);
        }),
      Positioned(top: 0, left: 8, right: 16, child: SafeArea(child: Row(children: [
        const BackButton(color: Colors.white), const Text('Video akışı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const Spacer(), Text('${index + 1} / ${widget.videos.length}', style: const TextStyle(color: Colors.white)),
      ]))),
    ]));
}
