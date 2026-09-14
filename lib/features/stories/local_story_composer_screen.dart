import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/story_service.dart';
import '../../core/theme/app_theme.dart';

class LocalStoryComposerScreen extends StatefulWidget {
  const LocalStoryComposerScreen({super.key});

  @override
  State<LocalStoryComposerScreen> createState() => _LocalStoryComposerScreenState();
}

class _LocalStoryComposerScreenState extends State<LocalStoryComposerScreen> {
  final LocalMusicService _music = LocalMusicService.instance;
  bool _loading = true;
  String? _uploadingSongId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _music.requestPermissionAndLoad(request: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick(SongModel song) async {
    final durationMs = song.duration ?? 0;
    final totalSeconds = (durationMs / 1000).floor();
    final maxStart = totalSeconds > 15 ? totalSeconds - 15 : 0;
    double start = 0;

    final preview = AudioPlayer();
    Timer? previewTimer;
    bool previewReady = false;

    Future<void> playPreview(int second) async {
      previewTimer?.cancel();
      try {
        if (!previewReady) {
          await preview.setFilePath(song.data);
          previewReady = true;
        }
        await preview.seek(Duration(seconds: second));
        await preview.play();
        previewTimer = Timer(const Duration(seconds: 15), () {
          unawaited(preview.pause());
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('15 saniyelik önizleme başlatılamadı.')),
        );
      }
    }

    if (_music.player.playing) {
      await _music.pause();
    }
    unawaited(playPreview(0));

    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF11131F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2C2F45)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist ?? 'Bilinmeyen sanatçı',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text(
                  '15 saniyelik bölümü seç',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_time(start.round())} – ${_time(start.round() + 15)}',
                        style: const TextStyle(
                          color: AppColors.neonPurple,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => playPreview(start.round()),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('15 sn dinle'),
                    ),
                  ],
                ),
                Slider(
                  value: start.clamp(0, maxStart.toDouble()),
                  min: 0,
                  max: maxStart <= 0 ? 1 : maxStart.toDouble(),
                  activeColor: AppColors.neonPurple,
                  onChanged: maxStart <= 0
                      ? null
                      : (value) => setSheetState(() => start = value),
                  onChangeEnd: maxStart <= 0
                      ? null
                      : (value) => playPreview(value.round()),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, start.round()),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Bu Bölümü Hikâye Yap'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    previewTimer?.cancel();
    await preview.stop();
    await preview.dispose();

    if (selected == null || !mounted) return;
    await _uploadAndCreate(song, selected);
  }

  Future<void> _uploadAndCreate(SongModel song, int startSecond) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _uploadingSongId = song.id.toString());
    try {
      final file = File(song.data);
      if (!await file.exists()) {
        throw StateError('Müzik dosyasına erişilemedi.');
      }
      final bytes = await file.readAsBytes();
      final ext = _extension(song.data);
      final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}_${song.id}.$ext';
      await Supabase.instance.client.storage.from('story-audio').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              cacheControl: '3600',
              contentType: _contentType(ext),
            ),
          );
      final publicUrl = Supabase.instance.client.storage
          .from('story-audio')
          .getPublicUrl(path);

      await StoryService.instance.createStory(
        videoId: 'audio:$publicUrl',
        title: song.title,
        artist: song.artist ?? 'Bilinmeyen sanatçı',
        thumbnailUrl: '',
        startSecond: startSecond,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hikâye paylaşılamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingSongId = null);
    }
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'mp3';
    final ext = path.substring(dot + 1).toLowerCase();
    const allowed = {'mp3', 'm4a', 'aac', 'ogg', 'flac', 'wav'};
    return allowed.contains(ext) ? ext : 'mp3';
  }

  static String _contentType(String ext) {
    switch (ext) {
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'wav':
        return 'audio/wav';
      default:
        return 'audio/mpeg';
    }
  }

  static String _time(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Müzik Hikâyesi')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonPurple),
            )
          : _music.songs.isEmpty
              ? const Center(
                  child: Text('Telefonda kullanılabilir müzik bulunamadı.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                  itemCount: _music.songs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final song = _music.songs[index];
                    final busy = _uploadingSongId == song.id.toString();
                    return ListTile(
                      onTap: _uploadingSongId == null ? () => _pick(song) : null,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: Container(
                              color: const Color(0xFF21183F),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: AppColors.neonPurple,
                              ),
                            ),
                            artworkBorder: BorderRadius.zero,
                          ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist ?? 'Bilinmeyen sanatçı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                    );
                  },
                ),
    );
  }
}
