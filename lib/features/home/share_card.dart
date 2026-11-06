import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_text.dart';
import '../../core/platform/device_controls.dart';
import '../../core/services/player_preferences.dart';
import 'video_player_controls.dart' show videoTime;

/// "Şu an dinliyorum" kartı: kapak + şarkı + sanatçı ile 1080×1920 görsel
/// üretir ve paylaşım menüsünü açar (Instagram hikâyesi, WhatsApp...).
Future<void> shareNowPlayingCard(
    {required String title, String? artist, Uri? artwork}) async {
  final lang = PlayerPreferences.instance.text('language', 'tr');
  final heading = translate('Şu an B Music’te dinliyorum', lang);
  File? file;
  try {
    file = await renderShareCard(
        title: title, artist: artist, artwork: artwork, heading: heading);
  } catch (_) {/* Görsel üretilemezse yalnızca metin paylaşılır. */}
  final text = '$heading 🎶\n$title${artist == null ? '' : ' – $artist'}\n'
      'https://play.google.com/store/apps/details?id=com.bmusic.app';
  await SharePlus.instance.share(ShareParams(
      text: text, files: file == null ? null : [XFile(file.path)]));
}

/// Video paylaşım kartı: kullanıcı 15 sn ses penceresini kaydırarak seçer,
/// kart görseli + ses klibi birlikte paylaşılır.
Future<void> shareVideoCard(
  BuildContext context, {
  required String path,
  required String title,
  required Duration duration,
  Uri? artwork,
}) async {
  if (duration <= Duration.zero) {
    await shareNowPlayingCard(title: title, artwork: artwork);
    return;
  }
  final clipStart = await pickFifteenSecondWindow(context, duration);
  if (clipStart == null || !context.mounted) return;
  final lang = PlayerPreferences.instance.text('language', 'tr');
  final heading = translate('Şu an B Music’te dinliyorum', lang);
  showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
              content: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 18),
            Expanded(child: AppText('Ses klibi hazırlanıyor…'))
          ])));
  File? image;
  String? audioPath;
  try {
    image = await renderShareCard(
        title: title, artwork: artwork, heading: heading);
    audioPath = await DeviceControls.extractAudioClip(
        path, clipStart, clipStart + const Duration(seconds: 15));
  } catch (_) {}
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  final files = <XFile>[
    if (image != null) XFile(image.path),
    if (audioPath != null) XFile(audioPath, mimeType: 'audio/mp4'),
  ];
  final text = '$heading 🎶\n$title\n'
      'https://play.google.com/store/apps/details?id=com.bmusic.app';
  if (files.isEmpty) {
    await SharePlus.instance.share(ShareParams(text: text));
    return;
  }
  await SharePlus.instance.share(ShareParams(text: text, files: files));
}

/// Returns the start of a fixed 15-second window the user scrubbed to, or null.
Future<Duration?> pickFifteenSecondWindow(
    BuildContext context, Duration total) async {
  const window = Duration(seconds: 15);
  final totalMs = total.inMilliseconds.toDouble();
  final windowMs = window.inMilliseconds
      .clamp(1000, total.inMilliseconds)
      .toDouble();
  var startMs = 0.0;
  if (totalMs <= windowMs) {
    return Duration.zero;
  }
  return showModalBottomSheet<Duration>(
    context: context,
    backgroundColor: const Color(0xFF17131F),
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, update) {
        final start = Duration(milliseconds: startMs.round());
        final end = Duration(milliseconds: (startMs + windowMs).round());
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('Paylaşım kartı + 15 sn ses',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const AppText('15 saniyelik sesi kaydırarak seç',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                AppText(
                    '${tr('Başlangıç')} ${videoTime(start)}  →  ${videoTime(end)}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                Slider(
                  value: startMs,
                  min: 0,
                  max: (totalMs - windowMs).clamp(0, totalMs),
                  activeColor: const Color(0xFFB94BFF),
                  onChanged: (v) => update(() => startMs = v),
                ),
                // Fixed-length window indicator (crop feel).
                LayoutBuilder(builder: (c, box) {
                  final maxStart = (totalMs - windowMs).clamp(1, totalMs);
                  final left = (startMs / maxStart) * (box.maxWidth - 24);
                  final width =
                      (windowMs / totalMs).clamp(0.08, 1.0) * box.maxWidth;
                  return SizedBox(
                    height: 28,
                    child: Stack(children: [
                      Container(
                          height: 8,
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4))),
                      Positioned(
                          left: left.clamp(0, box.maxWidth - width),
                          top: 4,
                          child: Container(
                              width: width,
                              height: 20,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFB94BFF)
                                      .withValues(alpha: .85),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white70)))),
                    ]),
                  );
                }),
                const SizedBox(height: 16),
                Row(children: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const AppText('İptal')),
                  const Spacer(),
                  FilledButton.icon(
                      onPressed: () => Navigator.pop(
                          c, Duration(milliseconds: startMs.round())),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const AppText('Paylaş')),
                ]),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<File> renderShareCard(
    {required String title,
    String? artist,
    Uri? artwork,
    required String heading}) async {
  const w = 1080.0, h = 1920.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
  canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(w, h),
            const [Color(0xFF0B1F4D), Color(0xFF1A0B2E), Color(0xFF000000)],
            const [0, .6, 1]));
  const art = Rect.fromLTWH(140, 380, 800, 800);
  final rrect = RRect.fromRectAndRadius(art, const Radius.circular(48));
  ui.Image? image;
  if (artwork != null && artwork.scheme == 'file') {
    try {
      final codec = await ui.instantiateImageCodec(
          await File.fromUri(artwork).readAsBytes(),
          targetWidth: 800,
          targetHeight: 800);
      image = (await codec.getNextFrame()).image;
    } catch (_) {}
  }
  if (image != null) {
    canvas.save();
    canvas.clipRRect(rrect);
    paintImage(canvas: canvas, rect: art, image: image, fit: BoxFit.cover);
    canvas.restore();
  } else {
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF271139));
    final icon = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
            text: String.fromCharCode(Icons.music_note_rounded.codePoint),
            style: TextStyle(
                fontSize: 360,
                fontFamily: Icons.music_note_rounded.fontFamily,
                color: const Color(0xFFFFD400))))
      ..layout();
    icon.paint(canvas,
        Offset(art.center.dx - icon.width / 2, art.center.dy - icon.height / 2));
  }
  void line(String text, double y, double size, Color color,
      {FontWeight weight = FontWeight.w600}) {
    final p = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
        text: TextSpan(
            text: text,
            style: TextStyle(fontSize: size, color: color, fontWeight: weight)))
      ..layout(maxWidth: w - 160);
    p.paint(canvas, Offset((w - p.width) / 2, y));
  }

  line(heading, 220, 46, const Color(0xFFFFD400));
  line(title, 1260, 68, Colors.white, weight: FontWeight.w800);
  if (artist != null && artist.isNotEmpty) {
    line(artist, 1440, 48, Colors.white70);
  }
  line('B Music 💛💙', 1720, 44, const Color(0xFFFFD400),
      weight: FontWeight.w800);
  final picture = recorder.endRecording();
  final png = await (await picture.toImage(w.toInt(), h.toInt()))
      .toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final out = File('${dir.path}/b_music_now_playing.png');
  await out.writeAsBytes(png!.buffer.asUint8List(), flush: true);
  return out;
}
