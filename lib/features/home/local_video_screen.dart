import 'widgets/reference_design.dart';
import '../../core/l10n/app_text.dart';

import 'dart:io';
import '../../core/platform/device_controls.dart';
import '../../core/services/local_music_service.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'advanced_video_player.dart';
export 'advanced_video_player.dart' show LocalVideoPlayerScreen;

import '../../core/services/video_library.dart';
import '../../core/services/player_preferences.dart';
import '../../core/services/video_preferences.dart';
import 'video_player_controls.dart';
import '../../core/theme/app_theme.dart';

class LocalVideoScreen extends StatefulWidget {
  const LocalVideoScreen({super.key, this.library, this.scanOnOpen = true, this.initialFolder = 'Tümü', this.initialRecent = false, this.initialNew = false, this.initialMostWatched = false});
  final String initialFolder;
  final bool initialRecent, initialNew, initialMostWatched;
  final VideoLibrary? library;
  final bool scanOnOpen;
  @override
  State<LocalVideoScreen> createState() => _VideoState();
}

class _VideoState extends State<LocalVideoScreen> with WidgetsBindingObserver {
  late final library = widget.library ?? VideoLibrary.instance;
  final search = FocusNode();
  String query = '', folder = 'Tümü';
  bool searching = false;

  /// 'Dosyalarım': browse device folders as a list, then one folder's videos.
  bool myFiles = false;
  bool favoritesOnly = false,
      listView = false,
      recentOnly = false,
      newOnly = false,
      mostWatched = false;
  final preferences = VideoPreferences.instance;
  VideoSort sort = VideoSort.newest;
  @override
  void initState() {
    super.initState();
    folder = widget.initialFolder;
    myFiles = folder != 'Tümü';
    recentOnly = widget.initialRecent;
    newOnly = widget.initialNew;
    mostWatched = widget.initialMostWatched;
    listView =
        PlayerPreferences.instance.flag('videoListView', fallback: false);
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
    if (state == AppLifecycleState.resumed) library.refreshNew();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    library.removeListener(changed);
    preferences.removeListener(changed);
    search.dispose();
    super.dispose();
  }

  Future<void> showFilters() async {
    var draftSort = sort;
    var draftList = listView;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
          builder: (c, update) => SafeArea(
                child: SizedBox(
                    height: MediaQuery.sizeOf(c).height * .82,
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(children: [
                            const Expanded(
                                child: Text('Filtrele',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800))),
                            TextButton(
                                onPressed: () => update(() {
                                      draftSort = VideoSort.newest;
                                      draftList = false;
                                    }),
                                child: const Text('Sıfırla')),
                          ])),
                      Expanded(
                          child: ListView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              children: [
                            const Text('Görünüm'),
                            const SizedBox(height: 10),
                            SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                      value: false,
                                      icon: Icon(Icons.grid_view_rounded),
                                      label: Text('Izgara')),
                                  ButtonSegment(
                                      value: true,
                                      icon: Icon(Icons.view_list_rounded),
                                      label: Text('Liste')),
                                ],
                                selected: {
                                  draftList
                                },
                                onSelectionChanged: (v) =>
                                    update(() => draftList = v.first)),
                            const SizedBox(height: 22),
                            const Text('Sıralama'),
                            for (final value in VideoSort.values)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: Icon(
                                      value == draftSort
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: value == draftSort
                                          ? Theme.of(c).colorScheme.primary
                                          : null),
                                  title: Text(videoSortLabels[value.index]),
                                  onTap: () => update(() => draftSort = value)),
                          ])),
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                              width: double.infinity,
                              child: GlowButton(
                                  label: 'Uygula',
                                  onTap: () {
                                    setState(() {
                                      sort = draftSort;
                                      listView = draftList;
                                    });
                                    Navigator.pop(sheetContext);
                                  }))),
                    ])),
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = library
        .filter(query, folder, sort)
        .where((v) => !newOnly || preferences.isNew(v.asset.id))
        .where((v) => !favoritesOnly || preferences.isFavorite(v.asset.id))
        .where((v) => !recentOnly || preferences.recent.contains(v.asset.id))
        .where((v) => !mostWatched || preferences.plays(v.asset.id) > 0)
        .toList();
    if (mostWatched) {
      final order = preferences.mostWatched;
      entries.sort((a, b) => order.indexOf(a.asset.id).compareTo(order.indexOf(b.asset.id)));
    }
    if (recentOnly)
      entries.sort((a, b) => preferences.recent
          .indexOf(a.asset.id)
          .compareTo(preferences.recent.indexOf(b.asset.id)));
    return PopScope(
        canPop: !(myFiles && folder != 'Tümü'),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => folder = 'Tümü');
        },
        child: Scaffold(
          appBar: AppBar(
            title: const AppText(
              'Videolar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                  tooltip: 'Videolarda ara',
                  onPressed: () => setState(() => searching = !searching),
                  icon: const Icon(Icons.search)),
              IconButton(
                  tooltip: listView ? 'Kart görünümü' : 'Liste görünümü',
                  onPressed: () => setState(() => listView = !listView),
                  icon: Icon(listView
                      ? Icons.grid_view_rounded
                      : Icons.view_list_rounded)),
              IconButton(
                  tooltip: 'Filtrele',
                  onPressed: showFilters,
                  icon: const Icon(Icons.tune_rounded)),
              IconButton(
                tooltip: 'Yenile',
                onPressed: library.loading
                    ? null
                    : () => library.scan(request: true, force: true),
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
                    FilterChip(
                        label: const Text('Tümü'),
                        selected: !newOnly &&
                            !favoritesOnly &&
                            !recentOnly &&
                            !mostWatched,
                        onSelected: (_) => setState(() {
                              newOnly = favoritesOnly =
                                  recentOnly = mostWatched = false;
                              folder = 'Tümü';
                            })),
                    const SizedBox(width: 8),
                    FilterChip(
                        label: const Text('Yeni'),
                        selected: newOnly,
                        onSelected: (v) => setState(() => newOnly = v)),
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
                    const SizedBox(width: 8),
                    FilterChip(
                        label: const Text('En çok izlenenler'),
                        avatar: const Icon(Icons.trending_up_rounded, size: 17),
                        selected: mostWatched,
                        onSelected: (v) => setState(() => mostWatched = v)),
                  ])),
              if (searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: !myFiles,
                      onSelected: (_) => setState(() {
                        myFiles = false;
                        folder = 'Tümü';
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Dosyalarım'),
                      avatar: const Icon(Icons.folder_outlined, size: 17),
                      selected: myFiles,
                      onSelected: (_) => setState(() {
                        myFiles = true;
                        folder = 'Tümü';
                      }),
                    ),
                  ]),
                ),
              if (library.allowed && myFiles && folder != 'Tümü')
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(children: [
                    IconButton(
                      tooltip: 'Klasörlere dön',
                      onPressed: () => setState(() => folder = 'Tümü'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Icon(Icons.folder_rounded, color: Color(0xFFBB62FF)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800))),
                    Text('${entries.length} video'),
                  ]),
                ),
              if (library.limited)
                TextButton(
                  onPressed: () => PhotoManager.presentLimited(),
                  child:
                      const AppText('Sınırlı erişim • Video seçimini değiştir'),
                ),
              if (library.loading) const LinearProgressIndicator(),
              Expanded(
                child: library.error != null
                    ? Center(
                        child: TextButton(
                          onPressed: () =>
                              library.scan(request: true, force: true),
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
                        : myFiles && folder == 'Tümü'
                            ? _FolderList(
                                counts: library.folderCounts,
                                onOpen: (name) => setState(() => folder = name))
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
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 14, 16, 160),
                                        itemCount: entries.length,
                                        itemBuilder: (c, i) => SizedBox(
                                            height: 250,
                                            child: Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 16),
                                                child: _VideoCard(
                                                    video: entries[i],
                                                    playlist: entries))))
                                    : GridView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 14, 16, 160),
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
                                        itemBuilder: (c, i) => _VideoCard(
                                            video: entries[i],
                                            playlist: entries),
                                      ),
              ),
            ],
          ),
        ));
  }
}

/// Opens [video] in the player. [playlist] is the list it was tapped in;
/// the player then allows reels-style vertical swiping to the previous and
/// next video. Only a window around the tapped video is passed along so very
/// large archives stay light.
Future<void> openLocalVideo(BuildContext context, LocalVideo video,
    {List<LocalVideo>? playlist}) async {
  var list = playlist ?? [video];
  var index = list.indexWhere((v) => v.asset.id == video.asset.id);
  if (index < 0) {
    list = [video];
    index = 0;
  }
  const radius = 100;
  final from = (index - radius).clamp(0, list.length);
  final to = (index + radius + 1).clamp(0, list.length);
  list = list.sublist(from, to);
  index -= from;
  final prefs = VideoPreferences.instance;
  try {
    await prefs.markSeen(video.asset.id);
    await prefs.countPlay(video.asset.id);
    final f = await video.asset.file;
    if (f == null) throw StateError('Dosya açılamadı');
    if (Platform.isAndroid) {
      await LocalMusicService.instance.pause();
      final result = await DeviceControls.openVideo(
          f.path, video.title, prefs.position(video.asset.id).inMilliseconds,
          favorite: prefs.isFavorite(video.asset.id),
          playlist: [
            for (final v in list)
              {
                'id': v.asset.id,
                'title': v.title,
                'favorite': prefs.isFavorite(v.asset.id),
                'position': prefs.position(v.asset.id).inMilliseconds
              },
          ],
          index: index);
      if (result == null) return;
      final failed = result['fallback'] == true
          ? ((result['index'] as num?)?.toInt() ?? index)
          : -1;
      await applyNativeVideoResult(result, list, index, failed: failed);
      if (failed >= 0) {
        if (context.mounted) {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LocalVideoPlayerScreen(
                      file: failed == index ? f : null,
                      title: list[failed].title,
                      mediaId: list[failed].asset.id,
                      playlist: list,
                      index: failed)));
        }
        return;
      }
      if (result['edited'] == true) {
        await VideoLibrary.instance.scan(force: true);
      } else {
        await VideoLibrary.instance.refreshNew();
      }
      return;
    }
    if (context.mounted) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LocalVideoPlayerScreen(
                  file: f,
                  title: video.title,
                  mediaId: video.asset.id,
                  playlist: list,
                  index: index)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              AppText('Video açılamadı. Dosyayı ve izinleri kontrol edin.')));
    }
  }
}

/// Applies what the native player reports for every video visited while
/// swiping: progress, favourites and watch history/counts.
Future<void> applyNativeVideoResult(
    Map<String, dynamic> result, List<LocalVideo> list, int first,
    {int failed = -1}) async {
  final prefs = VideoPreferences.instance;
  final visited = (result['visited'] as List?)?.cast<bool>();
  final favorites = (result['favorites'] as List?)?.cast<bool>();
  final positions = (result['positions'] as List?)?.cast<num>();
  final durations = (result['durations'] as List?)?.cast<num>();
  if (visited == null ||
      favorites == null ||
      positions == null ||
      durations == null) {
    if (failed >= 0) return;
    final id = list[first].asset.id;
    if (result['favorite'] is bool &&
        result['favorite'] != prefs.isFavorite(id))
      await prefs.toggleFavorite(id);
    await prefs.record(
        id,
        Duration(milliseconds: (result['position'] as num?)?.toInt() ?? 0),
        Duration(milliseconds: (result['duration'] as num?)?.toInt() ?? 0));
    return;
  }
  for (var i = 0; i < list.length && i < visited.length; i++) {
    if (!visited[i] || i == failed) continue;
    final id = list[i].asset.id;
    if (i != first) {
      await prefs.markSeen(id);
      await prefs.countPlay(id);
    }
    if (i < favorites.length && favorites[i] != prefs.isFavorite(id))
      await prefs.toggleFavorite(id);
    if (i < positions.length && i < durations.length) {
      await prefs.record(id, Duration(milliseconds: positions[i].toInt()),
          Duration(milliseconds: durations[i].toInt()));
    }
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({required this.counts, required this.onOpen});
  final Map<String, int> counts;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final names = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (names.isEmpty) return const Center(child: Text('Klasör bulunamadı'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
      itemCount: names.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (c, i) => ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: const Color(0x22BB62FF),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.folder_rounded, color: Color(0xFFBB62FF)),
        ),
        title: Text(names[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${counts[names[i]]} video'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => onOpen(names[i]),
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({required this.video, this.playlist});
  final LocalVideo video;
  final List<LocalVideo>? playlist;
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

  Future<void> open() =>
      openLocalVideo(context, widget.video, playlist: widget.playlist);

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
