import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/l10n/app_text.dart';
import '../../../core/services/local_video_engine.dart';
import '../../../core/services/video_library.dart';
import '../../../core/services/video_preferences.dart';
import '../../../core/theme/aurora.dart';

/// Long-press a video: a small muted window plays a few seconds of it.
Future<void> showVideoPreview(BuildContext context, LocalVideo video) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (c) => VideoPreviewDialog(video: video),
  );
}

class VideoPreviewDialog extends StatefulWidget {
  const VideoPreviewDialog({super.key, required this.video, this.seconds = 6});
  final LocalVideo video;
  final int seconds;
  @override
  State<VideoPreviewDialog> createState() => _PreviewState();
}

class _PreviewState extends State<VideoPreviewDialog> {
  mk.Player? player;
  VideoController? controller;
  String? error;
  Timer? limit;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(start());
  }

  Future<void> start() async {
    try {
      MediaKitInit.ensure();
      final file = await widget.video.asset.file;
      if (file == null || !await file.exists()) {
        if (mounted) setState(() => error = 'Video açılamadı. Dosyayı ve izinleri kontrol edin.');
        return;
      }
      final startAt = VideoPreferences.instance.position(widget.video.asset.id);
      final native = mk.Player(
        configuration: const mk.PlayerConfiguration(bufferSize: 4 * 1024 * 1024),
      );
      final view = VideoController(native);
      player = native;
      controller = view;
      await native.setVolume(0);
      await native.open(
        mk.Media(file.uri.toString(), start: startAt),
        play: true,
      );
      if (!mounted) {
        await native.dispose();
        return;
      }
      setState(() => ready = true);
      limit = Timer(Duration(seconds: widget.seconds), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    } on Object catch (_) {
      if (mounted) setState(() => error = 'Video açılamadı. Dosyayı ve izinleri kontrol edin.');
    }
  }

  @override
  void dispose() {
    limit?.cancel();
    final p = player;
    player = null;
    if (p != null) unawaited(p.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video.title;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: 20,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: AppText(error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70)),
                        ),
                      )
                    : !ready || controller == null
                        ? const Center(child: CircularProgressIndicator())
                        : Video(controller: controller!, controls: NoVideoControls, fill: Colors.black),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(children: [
              const Icon(Icons.volume_off_rounded, size: 16, color: Aurora.textMuted),
              const SizedBox(width: 6),
              const AppText('Önizleme',
                  style: TextStyle(fontSize: 11, color: Aurora.textMuted)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              IconButton(
                tooltip: tr('Sayfayı kapat'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}