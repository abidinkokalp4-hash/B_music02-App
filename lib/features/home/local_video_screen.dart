import '../../core/l10n/app_text.dart';

import 'dart:io';
import '../../core/platform/device_controls.dart';
import '../../core/services/local_music_service.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'advanced_video_player.dart';
import 'video_feed_screen.dart';
export 'advanced_video_player.dart' show LocalVideoPlayerScreen;

import '../../core/services/video_library.dart';
import '../../core/services/video_preferences.dart';
import 'video_player_controls.dart';
import '../../core/theme/app_theme.dart';

class LocalVideoScreen extends StatefulWidget {
  const LocalVideoScreen({super.key, this.library, this.scanOnOpen = true});
  final VideoLibrary? library;
  final bool scanOnOpen;
  @override
  State<LocalVideoScreen> createState() => _VideoState();
}

class _VideoState extends State<LocalVideoScreen> with WidgetsBindingObserver {
  late final library = widget.library ?? VideoLibrary.instance;
  final search = FocusNode();
  String query = '', folder = 'Tümü';
  bool favoritesOnly = false, listView = false, recentOnly = false, newOnly = false;
  final preferences = VideoPreferences.instance;
  VideoSort sort = VideoSort.newest;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    library.addListener(changed);
    preferences.addListener(changed);
    if (widget.scanOnOpen) library.scan();
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
    preferences.removeListener(changed);
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = library
        .filter(query, folder, sort)
        .where((v) => !newOnly || preferences.isNew(v.asset.id))
        .where((v) => !favoritesOnly || preferences.isFavorite(v.asset.id))
        .where((v) => !recentOnly || preferences.recent.contains(v.asset.id))
        .toList();
    if (recentOnly)
      entries.sort((a, b) => preferences.recent
          .indexOf(a.asset.id)
          .compareTo(preferences.recent.indexOf(b.asset.id)));
    return Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Videolar',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(tooltip: 'Video akışı', icon: const Icon(Icons.swipe_vertical_rounded),
            onPressed: entries.isEmpty ? null : () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => VideoFeedScreen(videos: List.of(entries))))),
          IconButton(
              tooltip: listView ? 'Kart görünümü' : 'Liste görünümü',
              onPressed: () => setState(() => listView = !listView),
              icon: Icon(listView
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded)),
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
            onPressed:
                library.loading ? null : () => library.scan(request: true, force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${library.videos.length} video · Cihaz arşivi')),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                FilterChip(label: const Text('Yalnız yeniler'), selected: newOnly, onSelected: (v) => setState(() => newOnly = v)),
                const SizedBox(width: 8),
                FilterChip(
                    label: const Text('Favoriler'),
                    avatar: const Icon(Icons.favorite_outline, size: 17),
                    selected: favoritesOnly,
                    onSelected: (v) => setState(() => favoritesOnly = v)),
                const SizedBox(width: 8),
                FilterChip(
                    label: const Text('Son izlenenler'),
                    avatar: const Icon(Icons.history_rounded, size: 17),
                    selected: recentOnly,
                    onSelected: (v) => setState(() => recentOnly = v)),
              ])),
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
                      onPressed: () => library.scan(request: true, force: true),
                      child: Text(library.error!),
                    ),
                  )
                : !library.allowed && !library.loading
                    ? Center(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await library.scan(request: true, force: true);
                            if (!library.allowed)
                              await PhotoManager.openSetting();
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
                        : listView
                            ? ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 16, 160),
                                itemCount: entries.length,
                                itemBuilder: (c, i) => SizedBox(
                                    height: 250,
                                    child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: _VideoCard(video: entries[i]))))
                            : GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 16, 160),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.02 /
                                      MediaQuery.textScalerOf(context)
                                          .scale(1)
                                          .clamp(1, 1.8),
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: entries.length,
                                itemBuilder: (c, i) =>
                                    _VideoCard(video: entries[i]),
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
      await VideoPreferences.instance.markSeen(widget.video.asset.id);
      final f = await widget.video.asset.file;
      if (f == null) throw StateError('Dosya açılamadı');
      if (Platform.isAndroid) {
        await LocalMusicService.instance.pause();
        final result = await DeviceControls.openVideo(f.path, widget.video.title,
            VideoPreferences.instance.position(widget.video.asset.id).inMilliseconds);
        if (result?['fallback'] == true) {
          if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => LocalVideoPlayerScreen(file: f, title: widget.video.title, mediaId: widget.video.asset.id)));
          return;
        }
        if (result != null) {
          await VideoPreferences.instance.record(widget.video.asset.id,
              Duration(milliseconds: (result['position'] as num?)?.toInt() ?? 0),
              Duration(milliseconds: (result['duration'] as num?)?.toInt() ?? 0));
        }
        await VideoLibrary.instance.scan(force: true);
        return;
      }
      if (mounted)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocalVideoPlayerScreen(
                file: f,
                title: widget.video.title,
                mediaId: widget.video.asset.id),
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
                  if (VideoPreferences.instance.isNew(v.asset.id))
                    Positioned(left: 8, top: 36, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFA53CFF), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Yeni', style: TextStyle(color: Colors.white, fontSize: 11)))),
                  if (VideoPreferences.instance.isFavorite(v.asset.id))
                    const Positioned(
                        left: 10,
                        top: 10,
                        child: Icon(Icons.favorite_rounded,
                            color: Color(0xFFFF8BBE), size: 22)),
                  if (VideoPreferences.instance.position(v.asset.id) >
                      Duration.zero)
                    Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(
                                'Devam: ${videoTime(VideoPreferences.instance.position(v.asset.id))}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)))),
                  const Center(
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.play_arrow, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    right: 5,
                    top: 5,
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
                  tooltip: '${v.title} seçenekleri',
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  onSelected: (s) async {
                    if (s == 'play') {
                      await open();
                    } else if (s == 'favorite') {
                      await VideoPreferences.instance
                          .toggleFavorite(v.asset.id);
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
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'play', child: AppText('Oynat')),
                    PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                            VideoPreferences.instance.isFavorite(v.asset.id)
                                ? 'Favorilerden çıkar'
                                : 'Favorilere ekle')),
                    const PopupMenuItem(
                        value: 'share', child: AppText('Paylaş')),
                    const PopupMenuItem(
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
