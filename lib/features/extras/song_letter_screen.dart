import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_text.dart';
import '../../core/platform/device_controls.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/music_catalog.dart';
import '../../core/services/playlist_qr.dart';
import '../../core/services/safe_audio_query.dart';
import '../../core/services/song_letters.dart';
import '../home/full_player_screen.dart';
import '../home/widgets/music_widgets.dart';
import 'clip_window_picker.dart';
import 'feature_sheets.dart' show importSharedPlaylist;

const _purple = Color(0xFFB65CFF);
const _surface = Color(0xFF101116);
const _border = Color(0xFF30253F);
const _muted = Color(0xFFA1A4B5);

void openSongLetter(BuildContext context, {SongModel? song}) =>
    Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => SongLetterComposer(song: song)));

/// Şarkı mektubu yaz (mockup 08). The sender name is typed by the user and is
/// never filled in automatically.
class SongLetterComposer extends StatefulWidget {
  const SongLetterComposer({super.key, this.song});
  final SongModel? song;
  @override
  State<SongLetterComposer> createState() => _ComposerState();
}

class _ComposerState extends State<SongLetterComposer> {
  final sender = TextEditingController();
  final message = TextEditingController();
  SongModel? song;
  var start = Duration.zero;
  var includeClip = true;
  var sending = false;

  @override
  void initState() {
    super.initState();
    song = widget.song ?? LocalMusicService.instance.currentSong;
    _resetStart();
    message.addListener(() => setState(() {}));
    sender.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    sender.dispose();
    message.dispose();
    super.dispose();
  }

  Duration get total => Duration(milliseconds: song?.duration ?? 0);

  void _resetStart() {
    final t = total;
    start = t > const Duration(seconds: 60)
        ? Duration(milliseconds: (t.inMilliseconds * .3).round())
        : Duration.zero;
  }

  Future<void> pickSong() async {
    final picked = await pickLetterSong(context);
    if (picked != null) {
      setState(() {
        song = picked;
        _resetStart();
      });
    }
  }

  bool get canSend =>
      !sending &&
      song != null &&
      sender.text.trim().isNotEmpty &&
      message.text.trim().isNotEmpty;

  Future<void> send() async {
    final s = song;
    if (s == null) return;
    setState(() => sending = true);
    try {
      File? clip;
      if (includeClip && total > Duration.zero) {
        var end = start + clipLength;
        if (end > total) end = total;
        try {
          final path = await DeviceControls.extractAudioClip(s.data, start, end);
          if (path != null) clip = File(path);
        } catch (_) {/* Letter still goes out without the clip. */}
      }
      Uint8List? cover;
      try {
        cover = await SafeAudioQuery.artwork(s.id, size: 200, priority: true);
      } catch (_) {}
      final artist = knownMetadata(s.artist, '');
      final id = await SongLetters.instance.send(
          sender: sender.text,
          message: message.text,
          title: s.title,
          artist: artist,
          clip: clip,
          cover: cover,
          clipStart: start.inMilliseconds);
      final link = SongLetters.webLink(id);
      await SharePlus.instance.share(ShareParams(
          text: '${tf('{0} sana bir şarkı mektubu gönderdi 💌', [sender.text.trim()])}\n$link'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('Mektup hazır, bağlantı paylaşıldı')));
        Navigator.pop(context);
      }
    } on LetterException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  InputDecoration _box(String hint) => InputDecoration(
        hintText: tr(hint),
        filled: true,
        fillColor: const Color(0xFF1B1C25),
        counterStyle: const TextStyle(color: _muted),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _purple, width: 1.6)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: AppText(text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    final s = song;
    return Scaffold(
      appBar: AppBar(
          title: const AppText('Şarkı mektubu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          _label('Şarkı'),
          Material(
            color: _surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: pickSong,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  if (s != null)
                    MediaArtwork(id: s.id, size: 60, radius: 12)
                  else
                    Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                            color: const Color(0xFF271139),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.music_note_rounded)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: s == null
                        ? const AppText('Bir şarkı seç',
                            style: TextStyle(fontWeight: FontWeight.w700))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(
                                    '${songArtist(s)} · ${formatMusicTime(total)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _muted, fontSize: 12)),
                              ]),
                  ),
                  AppText(s == null ? 'Seç' : 'Değiştir',
                      style: const TextStyle(
                          color: _purple, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
          _label('Adın (gönderen)'),
          TextField(
            controller: sender,
            maxLength: SongLetters.maxSender,
            textCapitalization: TextCapitalization.words,
            autofillHints: const <String>[],
            enableSuggestions: false,
            autocorrect: false,
            decoration: _box('Adını yaz'),
          ),
          _label('Mesajın'),
          TextField(
            controller: message,
            maxLength: SongLetters.maxMessage,
            minLines: 4,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: _box('Bu şarkı seni hatırlatıyor 💛'),
          ),
          Row(children: [
            const Expanded(
                child: AppText('15 saniyelik kısım (isteğe bağlı)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
            Switch(
                value: includeClip,
                activeTrackColor: _purple,
                onChanged: total > Duration.zero
                    ? (v) => setState(() => includeClip = v)
                    : null),
          ]),
          if (s != null && total > Duration.zero) ...[
            const SizedBox(height: 4),
            Opacity(
              opacity: includeClip ? 1 : .4,
              child: ClipWindowPicker(
                key: ValueKey(s.id),
                total: total,
                start: start,
                seed: s.id,
                previewPath: s.data,
                enabled: includeClip,
                onChanged: (v) => setState(() => start = v),
              ),
            ),
            const SizedBox(height: 8),
            const AppText('Karşı taraf mektupla bu 15 saniyeyi dinleyebilir.',
                style: TextStyle(color: _muted, fontSize: 12)),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: canSend ? send : null,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.mail_rounded),
            label: const AppText('Mektubu gönder',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          const AppText('WhatsApp, mesaj veya e-posta ile bir link paylaşılır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12)),
        ]),
      ),
    );
  }
}

Future<SongModel?> pickLetterSong(BuildContext context) async {
  final music = LocalMusicService.instance;
  if (music.songs.isEmpty) await music.requestPermissionAndLoad();
  if (!context.mounted) return null;
  var query = '';
  return showModalBottomSheet<SongModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(builder: (c, update) {
      final q = normalizeMusicSearch(query);
      final list = music.songs
          .where((s) =>
              q.isEmpty ||
              normalizeMusicSearch('${s.title} ${s.artist ?? ''}').contains(q))
          .take(300)
          .toList();
      return SizedBox(
        height: MediaQuery.of(c).size.height * .8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search), hintText: tr('Ara')),
                onChanged: (v) => update(() => query = v)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (c, i) => ListTile(
                leading: MediaArtwork(id: list[i].id),
                title: Text(list[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(songArtist(list[i]), maxLines: 1),
                onTap: () => Navigator.pop(c, list[i]),
              ),
            ),
          ),
        ]),
      );
    }),
  );
}

/// Recipient side inside the app (mockup 09), opened from a letter link.
class SongLetterView extends StatefulWidget {
  const SongLetterView({super.key, required this.id});
  final String id;
  @override
  State<SongLetterView> createState() => _LetterViewState();
}

class _LetterViewState extends State<SongLetterView> {
  SongLetter? letter;
  String? error;
  final player = AudioPlayer(handleInterruptions: false);
  bool playing = false;

  @override
  void initState() {
    super.initState();
    _load();
    player.playingStream.listen((p) {
      if (mounted) setState(() => playing = p);
    });
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) {
        player.pause();
        player.seek(Duration.zero);
      }
    });
  }

  Future<void> _load() async {
    try {
      final l = await SongLetters.instance.fetch(widget.id);
      if (!mounted) return;
      setState(() => letter = l);
      final clip = l.clip;
      if (clip != null) {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/b_music_letter_${l.id}.m4a');
        await f.writeAsBytes(clip, flush: true);
        await player.setFilePath(f.path);
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Mektup bulunamadı veya silinmiş.');
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> listenInApp() async {
    final l = letter;
    if (l == null) return;
    await player.pause();
    final music = LocalMusicService.instance;
    if (music.songs.isEmpty) await music.requestPermissionAndLoad();
    final found = PlaylistQr.match(
        SharedPlaylist('', [(l.title, l.artist)]), music.songs);
    if (!mounted) return;
    if (found.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: AppText('Bu şarkı telefonunda yok; mektup klibini dinleyebilirsin.')));
      return;
    }
    await runMusicAction(context, () => music.playSong(found.first));
    if (mounted) openFullPlayer(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = letter;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset('assets/images/b_music02_logo.png',
                    width: 28, height: 28)),
            const SizedBox(width: 8),
            const Text('B Music',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          AppText(
              error ?? (l == null ? 'Mektup açılıyor…' : 'Sana bir şarkı mektubu geldi'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 24),
          if (l == null && error == null)
            const Center(child: CircularProgressIndicator()),
          if (l != null) _card(l),
          const SizedBox(height: 16),
          if (l != null)
            const AppText('Linki açan kişi şarkıyı dinler ve istersen uygulamayı indirir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _card(SongLetter l) => Stack(clipBehavior: Clip.none, children: [
        Column(children: [
          ClipPath(
            clipper: _FlapClipper(),
            child: Container(
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: const Color(0xFF2A2438)),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border)),
            child: Column(children: [
              const AppText('GÖNDEREN',
                  style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(l.sender,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Text(l.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.45)),
              const SizedBox(height: 16),
              const Divider(color: _border, height: 1),
              const SizedBox(height: 14),
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: l.cover != null
                      ? Image.memory(Uint8List.fromList(l.cover!),
                          width: 56, height: 56, fit: BoxFit.cover)
                      : Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFF271139),
                          child: const Icon(Icons.music_note_rounded,
                              color: Color(0xFFFFD400))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    if (l.artist.isNotEmpty)
                      Text(l.artist,
                          maxLines: 1,
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    if (l.clip != null)
                      const AppText('15 sn · mektup klibi',
                          style: TextStyle(
                              color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (l.clip != null)
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(48, 48)),
                    onPressed: () => playing ? player.pause() : player.play(),
                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 28),
                  ),
              ]),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: listenInApp,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const AppText('B Music’te dinle'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44)),
                onPressed: () => launchUrl(
                    Uri.parse('https://play.google.com/store/apps/details?id=com.bmusic.app'),
                    mode: LaunchMode.externalApplication),
                child: const AppText('Uygulamayı indir'),
              ),
            ]),
          ),
        ]),
        Positioned(
          top: 18,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surface,
                  border: Border.all(color: _purple, width: 2)),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                  child: Image.asset('assets/images/b_music02_logo.png')),
            ),
          ),
        ),
      ]);
}

class _FlapClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height)
    ..lineTo(size.width / 2, 0)
    ..lineTo(size.width, size.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Opens a bmusic:// or web link (letters, QR playlists) handed over by Android.
Future<void> openFeatureLink(BuildContext context, String link) async {
  final letterId = SongLetters.idFromLink(link);
  if (letterId != null) {
    await Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => SongLetterView(id: letterId)));
    return;
  }
  final shared = PlaylistQr.decode(link);
  if (shared != null && context.mounted) {
    await importSharedPlaylist(context, shared);
  }
}
