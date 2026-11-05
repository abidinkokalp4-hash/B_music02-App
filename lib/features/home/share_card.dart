import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_text.dart';
import '../../core/services/player_preferences.dart';

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
