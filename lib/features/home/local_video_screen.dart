import '../../core/l10n/app_text.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/video_library.dart';
import '../../core/theme/app_theme.dart';

class LocalVideoScreen extends StatefulWidget {
  const LocalVideoScreen({super.key});
  @override
  State<LocalVideoScreen> createState() => _VideoState();
}

class _VideoState extends State<LocalVideoScreen> with WidgetsBindingObserver {
  final library = VideoLibrary.instance;
  final search = FocusNode();
  String query = '', folder = 'Tümü';
  VideoSort sort = VideoSort.newest;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    library.addListener(changed);
    library.scan();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) library.scan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    library.removeListener(changed);
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = library.filter(query, folder, sort);
    return Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Videolarım',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Ara',
            onPressed: search.requestFocus,
            icon: const Icon(Icons.search),
          ),
          PopupMenuButton<VideoSort>(
            tooltip: 'Sırala',
            icon: Icon(
              Icons.filter_list,
              color: Theme.of(context).colorScheme.primary,
            ),
            onSelected: (v) => setState(() => sort = v),
            itemBuilder: (_) => VideoSort.values
                .map(
                  (v) => CheckedPopupMenuItem(
                    value: v,
                    checked: v == sort,
                    child: AppText(videoSortLabels[v.index]),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: library.loading
                ? null
                : () => library.scan(request: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppText('Cihazınızdaki tüm videolar'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              focusNode: search,
              onChanged: (s) => setState(() => query = s),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Videolarda ara...',
              ),
            ),
          ),
          if (library.allowed)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['Tümü', ...library.folders]
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: folder == f,
                          onSelected: (_) => setState(() => folder = f),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (library.limited)
            TextButton(
              onPressed: () => PhotoManager.presentLimited(),
              child: const AppText('Sınırlı erişim • Video seçimini değiştir'),
            ),
          if (library.loading) const LinearProgressIndicator(),
          Expanded(
            child: library.error != null
                ? Center(
                    child: TextButton(
                      onPressed: () => library.scan(request: true),
                      child: Text(library.error!),
                    ),
                  )
                : !library.allowed && !library.loading
                ? Center(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await library.scan(request: true);
                        if (!library.allowed) await PhotoManager.openSetting();
                      },
                      icon: const Icon(Icons.video_library),
                      label: const AppText('Video erişimine izin ver'),
                    ),
                  )
                : entries.isEmpty
                ? Center(
                    child: Text(
                      library.loading
                          ? 'Videolar taranıyor...'
                          : 'Video bulunamadı',
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 160),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.02,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                        ),
                    itemCount: entries.length,
                    itemBuilder: (c, i) => _VideoCard(video: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({required this.video});
  final LocalVideo video;
  @override
  State<_VideoCard> createState() => _CardState();
}

class _CardState extends State<_VideoCard> {
  late Future<Uint8List?> thumbnail;
  @override
  void initState() {
    super.initState();
    loadThumbnail();
  }

  void loadThumbnail() {
    thumbnail = widget.video.asset.thumbnailDataWithSize(
      const ThumbnailSize(480, 270),
      quality: 75,
    );
  }

  @override
  void didUpdateWidget(covariant _VideoCard old) {
    super.didUpdateWidget(old);
    if (old.video.asset.id != widget.video.asset.id) loadThumbnail();
  }

  Future<void> open() async {
    try {
      final f = await widget.video.asset.file;
      if (f == null) throw StateError('Dosya açılamadı');
      if (mounted)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                LocalVideoPlayerScreen(file: f, title: widget.video.title),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Video açılamadı. Dosyayı ve izinleri kontrol edin.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext c) {
    final v = widget.video;
    final date = v.asset.createDateTime;
    final duration =
        '${v.asset.duration ~/ 60}:${(v.asset.duration % 60).toString().padLeft(2, '0')}';
    final details =
        '${date.day}.${date.month}.${date.year} • ${v.bytes == null ? 'Boyut bilinmiyor' : '${(v.bytes! / 1048576).toStringAsFixed(1)} MB'}';
    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List?>(
                    future: thumbnail,
                    builder: (c, s) => s.hasData
                        ? Image.memory(s.data!, fit: BoxFit.cover)
                        : const ColoredBox(
                            color: AppColors.surfaceAlt,
                            child: Icon(Icons.movie_outlined),
                          ),
                  ),
                  const Center(
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.play_arrow, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  v.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                height: 32,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  onSelected: (s) async {
                    if (s == 'play') {
                      await open();
                    } else if (s == 'share') {
                      final f = await v.asset.file;
                      if (f != null)
                        await SharePlus.instance.share(
                          ShareParams(files: [XFile(f.path)]),
                        );
                    } else {
                      if (c.mounted)
                        showDialog<void>(
                          context: c,
                          builder: (c) => AlertDialog(
                            title: Text(v.title),
                            content: AppText(
                              '$details\nSüre: $duration\n${v.folders.join(', ')}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const AppText('Tamam'),
                              ),
                            ],
                          ),
                        );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'play', child: AppText('Oynat')),
                    PopupMenuItem(value: 'share', child: AppText('Paylaş')),
                    PopupMenuItem(
                      value: 'info',
                      child: AppText('Dosya bilgileri'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(c).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class LocalVideoPlayerScreen extends StatefulWidget {
  const LocalVideoPlayerScreen({
    super.key,
    required this.file,
    required this.title,
  });
  final File file;
  final String title;
  @override
  State<LocalVideoPlayerScreen> createState() => _P();
}

class _P extends State<LocalVideoPlayerScreen> {
  late final VideoPlayerController p;
  String? error;
  @override
  void initState() {
    super.initState();
    p = VideoPlayerController.file(widget.file)
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() {});
              p.play();
            }
          })
          .catchError((Object e) {
            if (mounted)
              setState(
                () => error = 'Video oynatılamadı. Dosya bozuk veya biçimi desteklenmiyor olabilir.',
              );
          });
    p.addListener(tick);
  }

  @override
  void dispose() {
    p.removeListener(tick);
    p.dispose();
    super.dispose();
  }

  void tick() {
    if (mounted) setState(() {});
  }

  String t(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: Center(
      child: error != null || p.value.hasError
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error ?? 'Video oynatılamadı.',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : !p.value.isInitialized
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AspectRatio(
                  aspectRatio: p.value.aspectRatio,
                  child: VideoPlayer(p),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Slider(
                        value: p.value.position.inMilliseconds.toDouble().clamp(
                          0,
                          p.value.duration.inMilliseconds.toDouble(),
                        ),
                        max: p.value.duration.inMilliseconds.toDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        onChanged: (v) =>
                            p.seekTo(Duration(milliseconds: v.toInt())),
                      ),
                      Row(
                        children: [
                          Text(t(p.value.position)),
                          const Spacer(),
                          Text(t(p.value.duration)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => p.seekTo(
                              p.value.position - const Duration(seconds: 10),
                            ),
                            icon: const Icon(Icons.replay_10_rounded),
                          ),
                          IconButton(
                            iconSize: 58,
                            onPressed: () =>
                                p.value.isPlaying ? p.pause() : p.play(),
                            icon: Icon(
                              p.value.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                            ),
                          ),
                          IconButton(
                            onPressed: () => p.seekTo(
                              p.value.position + const Duration(seconds: 10),
                            ),
                            icon: const Icon(Icons.forward_10_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
