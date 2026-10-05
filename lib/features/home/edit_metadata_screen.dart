import 'dart:io';
import 'dart:isolate';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/platform/media_files.dart';
import '../../core/services/local_music_service.dart';

class EditMetadataScreen extends StatefulWidget {
  const EditMetadataScreen({super.key, required this.song});
  final SongModel song;
  @override
  State<EditMetadataScreen> createState() => _EditState();
}
class _EditState extends State<EditMetadataScreen> {
  late final title = TextEditingController(text: widget.song.title);
  late final artist = TextEditingController(text: widget.song.artist == '<unknown>' ? '' : widget.song.artist);
  late final album = TextEditingController(text: widget.song.album == '<unknown>' ? '' : widget.song.album);
  String? cover, error;
  bool working = false;
  String get extension => widget.song.data.split('.').last.toLowerCase();
  bool get supported => ['mp3', 'm4a', 'mp4', 'flac', 'wav', 'ape'].contains(extension);
  Future<void> save() async {
    if (working || !supported) return;
    if (title.text.trim().isEmpty) { setState(() => error = 'Şarkı adı boş olamaz'); return; }
    setState(() { working = true; error = null; });
    Directory? temporary;
    try {
      temporary = await Directory((await getTemporaryDirectory()).path).createTemp('b-music-tags-');
      final target = '${temporary.path}/edited.$extension';
      await File(widget.song.data).copy(target);
      final name = title.text.trim(), singer = artist.text.trim(), record = album.text.trim(), picture = cover;
      await Isolate.run(() {
        updateMetadata(File(target), (metadata) {
          metadata.setTitle(name); metadata.setArtist(singer); metadata.setAlbum(record);
          if (picture != null) metadata.setPictures([Picture(File(picture).readAsBytesSync(),
            picture.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg', PictureType.coverFront)]);
        });
        final check = readMetadata(File(target), getImage: false);
        if (check.title != name) throw StateError('Bilgiler doğrulanamadı');
      });
      final saved = await MediaFiles.saveCopy(target, '${name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.$extension');
      if (!mounted) return;
      if (saved) {
        await LocalMusicService.instance.refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Düzenlenen müzik kaydedildi. Orijinal dosya korundu.')));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Kaydedilemedi. Boş alanı ve dosya erişimini kontrol edin. Orijinal dosya değiştirilmedi.');
    } finally {
      if (temporary != null && await temporary.exists()) await temporary.delete(recursive: true);
      if (mounted) setState(() => working = false);
    }
  }
  @override
  void dispose() { title.dispose(); artist.dispose(); album.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => PopScope(canPop: !working, child: Scaffold(
    appBar: AppBar(title: const Text('Dosya bilgilerini düzenle')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Değişiklikler yeni bir müzik dosyasına yazılır. Orijinal kayıt korunur; kaydetme konumunu sen seçersin.'),
      const SizedBox(height: 24),
      if (!supported) const Text('Bu dosya biçiminde bilgi yazma desteklenmiyor. MP3, M4A, MP4, FLAC, WAV ve APE düzenlenebilir.'),
      for (final field in [(title, 'Şarkı adı'), (artist, 'Sanatçı'), (album, 'Albüm')])
        Padding(padding: const EdgeInsets.only(bottom: 18), child: TextField(controller: field.$1, enabled: supported && !working,
          decoration: InputDecoration(labelText: field.$2))),
      if (cover != null) ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(cover!), height: 180, fit: BoxFit.contain)),
      OutlinedButton.icon(onPressed: !supported || working ? null : () async {
        final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 90);
        if (image != null && mounted) setState(() => cover = image.path);
      }, icon: const Icon(Icons.image_outlined), label: const Text('Kapak seç')),
      if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(error!, style: TextStyle(color: Theme.of(c).colorScheme.error))),
      const SizedBox(height: 16), FilledButton(onPressed: working || !supported ? null : save,
        child: Text(working ? 'Kaydediliyor…' : 'Düzenlenmiş kopyayı kaydet')),
    ])));
}
