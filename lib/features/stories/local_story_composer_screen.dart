import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

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
                Text(song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(song.artist ?? 'Bilinmeyen sanatçı',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 18),
                const Text('15 saniyelik bölümü seç',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text('${_time(start.round())} – ${_time(start.round() + 15)}',
                    style: const TextStyle(color: AppColors.neonPurple, fontWeight: FontWeight.w800)),
                Slider(
                  value: start.clamp(0, maxStart.toDouble()),
                  min: 0,
                  max: maxStart <= 0 ? 1 : maxStart.toDouble(),
                  activeColor: AppColors.neonPurple,
                  onChanged: maxStart <= 0 ? null : (value) => setSheetState(() => start = value),
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

    if (selected == null) return;
    await StoryService.instance.createStory(
      videoId: 'local:${song.id}',
      title: song.title,
      artist: song.artist ?? 'Bilinmeyen sanatçı',
      thumbnailUrl: '',
      startSecond: selected,
    );
    if (mounted) Navigator.pop(context, true);
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonPurple))
          : _music.songs.isEmpty
              ? const Center(child: Text('Telefonda kullanılabilir müzik bulunamadı.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                  itemCount: _music.songs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final song = _music.songs[index];
                    return ListTile(
                      onTap: () => _pick(song),
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
                              child: const Icon(Icons.music_note_rounded, color: AppColors.neonPurple),
                            ),
                            artworkBorder: BorderRadius.zero,
                          ),
                        ),
                      ),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.artist ?? 'Bilinmeyen sanatçı', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    );
                  },
                ),
    );
  }
}
