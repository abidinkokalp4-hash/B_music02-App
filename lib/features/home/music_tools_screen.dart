import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/theme/app_theme.dart';

class MusicToolsScreen extends StatefulWidget {
  const MusicToolsScreen({super.key});

  @override
  State<MusicToolsScreen> createState() => _MusicToolsScreenState();
}

class _MusicToolsScreenState extends State<MusicToolsScreen> {
  final LocalMusicService _music = LocalMusicService.instance;
  final MusicInsightsService _insights = MusicInsightsService.instance;

  bool _loading = true;
  int _todayMinutes = 0;
  int _streak = 0;
  List<TrackInsight> _top = const [];
  List<TrackInsight> _recent = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<dynamic>([
      _insights.todayMinutes(),
      _insights.currentStreak(),
      _insights.topTracks(limit: 10),
      _insights.recentTracks(limit: 15),
    ]);
    if (!mounted) return;
    setState(() {
      _todayMinutes = values[0] as int;
      _streak = values[1] as int;
      _top = values[2] as List<TrackInsight>;
      _recent = values[3] as List<TrackInsight>;
      _loading = false;
    });
  }

  MediaItem? get _currentItem {
    final tag = _music.player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  Future<void> _shareCurrent() async {
    final item = _currentItem;
    if (item == null) {
      _message('Önce bir müzik çal.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        text: '🎵 B_music02\n${item.title}\n${item.artist ?? 'Bilinmeyen sanatçı'}',
        subject: 'B_music02 • Şu an dinliyorum',
      ),
    );
  }

  Future<void> _backup() async {
    try {
      await _insights.backupToCloud();
      _message('Müzik istatistikleri buluta yedeklendi.');
    } catch (_) {
      _message('Yedekleme tamamlanamadı. Oturumunu kontrol et.');
    }
  }

  Future<void> _restore() async {
    try {
      final restored = await _insights.restoreCloudInsights();
      _message(restored ? 'Bulut yedeği geri yüklendi.' : 'Bulut yedeği bulunamadı.');
      await _load();
    } catch (_) {
      _message('Yedek geri yüklenemedi.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openLyrics() async {
    final item = _currentItem;
    if (item == null) {
      _message('Önce bir müzik çal.');
      return;
    }

    SongModel? song;
    final id = int.tryParse(item.id);
    if (id != null) {
      for (final candidate in _music.songs) {
        if (candidate.id == id) {
          song = candidate;
          break;
        }
      }
    }

    String? lyrics;
    if (song != null) {
      lyrics = await _readSidecarLyrics(song);
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LyricsSheet(
        title: item.title,
        artist: item.artist,
        lyrics: lyrics,
      ),
    );
  }

  Future<String?> _readSidecarLyrics(SongModel song) async {
    try {
      final audioFile = File(song.data);
      final dot = audioFile.path.lastIndexOf('.');
      final base = dot > 0 ? audioFile.path.substring(0, dot) : audioFile.path;
      for (final extension in const ['.lrc', '.txt']) {
        final file = File('$base$extension');
        if (await file.exists()) {
          final raw = await file.readAsString();
          return raw
              .replaceAll(RegExp(r'\[[0-9]{1,2}:[0-9]{2}(?:\.[0-9]{1,3})?\]'), '')
              .replaceAll(RegExp(r'\[(ar|ti|al|by|offset):[^\]]*\]', caseSensitive: false), '')
              .trim();
        }
      }
    } catch (_) {}
    return null;
  }

  void _openSleepTimer() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              leading: Icon(Icons.bedtime_rounded, color: AppColors.gold),
              title: Text('Uyku zamanlayıcısı'),
              subtitle: Text('Süre dolunca müzik duraklatılır.'),
            ),
            for (final minutes in const [15, 30, 45, 60, 90])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$minutes dakika'),
                onTap: () {
                  _insights.startSleepTimer(Duration(minutes: minutes));
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ListTile(
              leading: const Icon(Icons.music_off_rounded),
              title: const Text('Şarkı bitince durdur'),
              onTap: () {
                _insights.stopAfterCurrentTrack();
                Navigator.pop(context);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Zamanlayıcıyı kapat'),
              onTap: () {
                _insights.cancelSleepTimer();
                Navigator.pop(context);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openQueue() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final state = _music.player.sequenceState;
        final items = state.sequence
            .map((source) => source.tag)
            .whereType<MediaItem>()
            .toList();
        final currentIndex = _music.player.currentIndex;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) => Column(
            children: [
              const ListTile(
                leading: Icon(Icons.queue_music_rounded, color: AppColors.gold),
                title: Text('Çalma kuyruğu'),
                subtitle: Text('Bir parçaya dokunarak doğrudan geç.'),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Kuyruk boş.'))
                    : ListView.builder(
                        controller: controller,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final selected = index == currentIndex;
                          return ListTile(
                            leading: Icon(
                              selected ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                              color: selected ? AppColors.gold : Colors.white38,
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.artist ?? 'Bilinmeyen sanatçı',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () async {
                              await _music.player.seek(Duration.zero, index: index);
                              if (context.mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCarMode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _CarModeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Müzik Merkezi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
                children: [
                  _hero(),
                  const SizedBox(height: 18),
                  _toolGrid(),
                  const SizedBox(height: 24),
                  _sectionTitle('Dinleme Özeti', Icons.insights_rounded),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _metric('Bugün', '$_todayMinutes dk', Icons.schedule_rounded)),
                      const SizedBox(width: 9),
                      Expanded(child: _metric('Seri', '$_streak gün', Icons.local_fire_department_rounded)),
                      const SizedBox(width: 9),
                      Expanded(child: _metric('Favori', '${_music.favoriteIds.length}', Icons.favorite_rounded)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('En Çok Dinlediklerin', Icons.workspace_premium_rounded),
                  const SizedBox(height: 8),
                  if (_top.isEmpty)
                    _empty('Dinledikçe kişisel sıralaman burada oluşacak.')
                  else
                    ..._top.asMap().entries.map((entry) {
                      final item = entry.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.gold.withValues(alpha: 0.10),
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900),
                          ),
                        ),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text('${item.plays} kez', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      );
                    }),
                  const SizedBox(height: 20),
                  _sectionTitle('Son Dinlenenler', Icons.history_rounded),
                  const SizedBox(height: 8),
                  if (_recent.isEmpty)
                    _empty('Son dinlediğin parçalar burada görünür.')
                  else
                    ..._recent.take(8).map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history_rounded, color: AppColors.gold),
                            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _hero() {
    final item = _currentItem;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2A10), Color(0xFF2D101B), Color(0xFF131313)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(Icons.equalizer_rounded, color: AppColors.gold, size: 32),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ŞU AN', style: TextStyle(color: AppColors.gold, fontSize: 8, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  item?.title ?? 'Müzik çalmıyor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                Text(
                  item?.artist ?? 'Müziklerimden bir parça seç',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolGrid() {
    final tools = <(IconData, String, VoidCallback)>[
      (Icons.bedtime_rounded, 'Uyku', _openSleepTimer),
      (Icons.queue_music_rounded, 'Kuyruk', _openQueue),
      (Icons.lyrics_rounded, 'Şarkı Sözü', _openLyrics),
      (Icons.share_rounded, 'Paylaş', _shareCurrent),
      (Icons.directions_car_rounded, 'Araba Modu', _openCarMode),
      (Icons.cloud_upload_rounded, 'Yedekle', _backup),
      (Icons.cloud_download_rounded, 'Yedeği Al', _restore),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.93,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];
        return InkWell(
          onTap: tool.$3,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.$1, color: AppColors.gold, size: 23),
                const SizedBox(height: 7),
                FittedBox(
                  child: Text(
                    tool.$2,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      height: 95,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 18),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 19),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _empty(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    );
  }
}

class _LyricsSheet extends StatelessWidget {
  const _LyricsSheet({
    required this.title,
    required this.artist,
    required this.lyrics,
  });

  final String title;
  final String? artist;
  final String? lyrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 45,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(artist ?? 'Bilinmeyen sanatçı', style: const TextStyle(color: AppColors.gold, fontSize: 11)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                lyrics ?? 'Bu parçanın yanında .lrc veya .txt şarkı sözü dosyası bulunamadı.\n\nTelifli şarkı sözlerini izinsiz internetten çekmiyoruz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: lyrics == null ? Colors.white38 : Colors.white,
                  fontSize: lyrics == null ? 12 : 18,
                  height: lyrics == null ? 1.5 : 1.9,
                  fontWeight: lyrics == null ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarModeScreen extends StatelessWidget {
  const _CarModeScreen();

  @override
  Widget build(BuildContext context) {
    final music = LocalMusicService.instance;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Araba Modu'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: StreamBuilder<bool>(
              stream: music.player.playingStream,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? music.player.playing;
                final tag = music.player.sequenceState.currentSource?.tag;
                final item = tag is MediaItem ? tag : null;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_filled_rounded, color: AppColors.gold, size: 70),
                    const SizedBox(height: 25),
                    Text(
                      item?.title ?? 'Müzik seçilmedi',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item?.artist ?? 'B_music02',
                      style: const TextStyle(color: AppColors.gold, fontSize: 16),
                    ),
                    const SizedBox(height: 55),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          onPressed: music.previous,
                          iconSize: 58,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        GestureDetector(
                          onTap: music.togglePlayPause,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 72,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: music.next,
                          iconSize: 58,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Büyük kontroller sürüş sırasında ekrana daha az bakman için tasarlandı. Trafikte telefonu kullanma.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
