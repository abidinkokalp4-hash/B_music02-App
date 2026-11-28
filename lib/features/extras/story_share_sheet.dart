import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_text.dart';
import '../../core/platform/device_controls.dart';
import '../../core/platform/feature_bridge.dart';
import '../../core/services/player_preferences.dart';
import '../home/share_card.dart';
import 'clip_window_picker.dart';

const _purple = Color(0xFFFF9A3C);
const _sheet = Color(0xFF1F1812);

/// Hikâyede paylaş (mockup 01): the chosen 15 s of the song become an MP4 with
/// sound + cover + B Music icon, sent to Instagram / WhatsApp / share sheet.
Future<void> showStoryShare(BuildContext context,
    {required String path,
    required String title,
    String? artist,
    Uri? artwork,
    required Duration duration,
    int seed = 7}) async {
  final choice = await showModalBottomSheet<(Duration, Duration, String?)>(
    context: context,
    backgroundColor: _sheet,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => _StorySheet(
        path: path,
        title: title,
        artist: artist,
        artwork: artwork,
        duration: duration,
        seed: seed),
  );
  if (choice == null || !context.mounted) return;
  final (start, length, target) = choice;
  var end = start + length;
  if (duration > Duration.zero && end > duration) end = duration;
  final lang = PlayerPreferences.instance.text('language', 'tr');
  final heading = translate('Şu an B Music’te dinliyorum', lang);
  final text =
      '$heading 🎶\n$title${artist == null || artist.isEmpty ? '' : ' – $artist'}\n'
      'https://play.google.com/store/apps/details?id=com.bmusic.app';
  showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
              content: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 18),
            Expanded(child: AppText('Sesli video hazırlanıyor…'))
          ])));
  File? image;
  String? video;
  try {
    image = await renderShareCard(
        title: title,
        artist: artist,
        artwork: artwork,
        heading: heading,
        badge: '🎵 ${length.inMilliseconds / 1000} sn',
        fileName: 'b_music_story_card.png');
    video = await FeatureBridge.storyVideo(
        image: image.path, audio: path, start: start, end: end);
  } catch (e) {
    debugPrint('[BMusic feature] story-video failed: $e');
  }
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  if (video != null) {
    final direct = await FeatureBridge.shareFile(video,
        mime: 'video/mp4', target: target, text: text);
    if (!direct && target != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: AppText(target == 'instagram'
              ? 'Instagram bulunamadı, paylaşım menüsü açıldı'
              : 'WhatsApp bulunamadı, paylaşım menüsü açıldı')));
    }
    return;
  }
  // Fallback (very old phones / unsupported codecs): card + separate audio clip.
  String? audio;
  try {
    audio = await DeviceControls.extractAudioClip(path, start, end);
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            AppText('Video oluşturulamadı; görsel ve ses ayrı paylaşıldı')));
  }
  await SharePlus.instance.share(ShareParams(text: text, files: [
    if (image != null) XFile(image.path),
    if (audio != null) XFile(audio, mimeType: 'audio/mp4'),
  ]));
}

class _StorySheet extends StatefulWidget {
  const _StorySheet(
      {required this.path,
      required this.title,
      this.artist,
      this.artwork,
      required this.duration,
      required this.seed});
  final String path, title;
  final String? artist;
  final Uri? artwork;
  final Duration duration;
  final int seed;
  @override
  State<_StorySheet> createState() => _StorySheetState();
}

class _StorySheetState extends State<_StorySheet> {
  var start = Duration.zero;
  late Duration length = initialClip(widget.duration);

  @override
  void initState() {
    super.initState();
    // Start a bit into the song (intros are often quiet), like the mockup.
    final total = widget.duration;
    if (total > const Duration(seconds: 60)) {
      start = Duration(milliseconds: (total.inMilliseconds * .3).round());
    }
  }

  void done(String? target) => Navigator.pop(context, (start, length, target));

  @override
  Widget build(BuildContext context) {
    final art = widget.artwork;
    return SafeArea(
      child: SingleChildScrollView(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('Hikâyede paylaş',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const AppText(
                'En fazla 30 saniyelik bir bölüm seç. Sesli kısa video olarak dışa aktarılır.',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 96,
                height: 164,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0B1F4D),
                          Color(0xFF1F1812),
                          Colors.black
                        ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                          alignment: Alignment.topRight,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                  '${(length.inMilliseconds / 1000).toStringAsFixed(1)} sn',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)))),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                            width: 84,
                            height: 72,
                            child: art != null && art.scheme == 'file'
                                ? Image.file(File.fromUri(art),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _artFallback())
                                : _artFallback()),
                      ),
                      const SizedBox(height: 5),
                      Text(widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                      Text(widget.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 9)),
                      const Spacer(),
                      Row(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                                'assets/images/b_music02_logo.png',
                                width: 16,
                                height: 16)),
                        const Spacer(),
                        const AppText('Sesli video',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 9)),
                      ]),
                    ]),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('Dışa aktarma önizlemesi',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      AppText(
                          'Seçtiğin bölüm, kapak görseliyle birlikte sesli video olarak paylaşılır.',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
              ),
            ]),
            const SizedBox(height: 16),
            ClipWindowPicker(
              total: widget.duration,
              start: start,
              length: length,
              seed: widget.seed,
              previewPath: widget.path,
              onChanged: (v, n) => setState(() {
                start = v;
                length = n;
              }),
            ),
            const SizedBox(height: 16),
            Row(children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const AppText('İptal',
                      style: TextStyle(
                          color: _purple, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50)),
                    onPressed: () => done(null),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const AppText('Paylaş')),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44)),
                      onPressed: () => done('instagram'),
                      child: const AppText('Instagram Hikâyesi'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44)),
                      onPressed: () => done('whatsapp'),
                      child: const AppText('WhatsApp Durumu'))),
            ]),
          ],
        ),
      )),
    );
  }

  Widget _artFallback() => Container(
      color: const Color(0xFF1F1812),
      child: const Icon(Icons.music_note_rounded, color: Color(0xFFFFD400)));
}
