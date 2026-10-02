import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_catalog.dart';
import '../../core/services/player_preferences.dart';

import 'widgets/music_widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen(
      {super.key,
      this.music,
      this.focusSearch = false,
      this.favoritesOnly = false});
  final LocalMusicService? music;
  final bool focusSearch, favoritesOnly;
  @override
  State<LibraryScreen> createState() => _LibraryState();
}

class _LibraryState extends State<LibraryScreen> with WidgetsBindingObserver {
  late final LocalMusicService music =
      widget.music ?? LocalMusicService.instance;
  final search = TextEditingController();
  final focus = FocusNode();
  MusicSort sort = MusicSort.title;
  int tab = 0;
  String? groupKey;
  bool loading = true;
  static const labels = [
    'Şarkılar',
    'Favoriler',
    'Sanatçılar',
    'Albümler',
    'Klasörler'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    music.addListener(changed);
    final stored = PlayerPreferences.instance.number('librarySort', 0).toInt();
    sort = MusicSort.values[stored.clamp(0, MusicSort.values.length - 1)];
    tab = widget.favoritesOnly ? 1 : 0;
    load();
    if (widget.focusSearch)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus.requestFocus();
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    music.removeListener(changed);
    search.dispose();
    focus.dispose();
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> load({bool request = false}) async {
    await music.requestPermissionAndLoad(request: request);
    if (mounted) setState(() => loading = false);
  }

  void selectTab(int index) => setState(() {
        tab = index;
        groupKey = null;
      });

  Future<void> playAll(List<SongModel> songs, {bool shuffled = false}) async {
    if (songs.isEmpty) return;
    await music.player.setShuffleModeEnabled(shuffled);
    await music.playSong(songs[shuffled ? Random().nextInt(songs.length) : 0],
        from: songs);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = selectMusic(tab == 1 ? music.favoriteSongs : music.songs,
        query: search.text, sort: sort);
    final groups = tab < 2
        ? <String, List<SongModel>>{}
        : groupMusic(selected, MusicGroup.values[tab - 2]);
    final songs =
        groupKey == null ? selected : groups[groupKey] ?? <SongModel>[];
    final detailTitle = groupKey == null
        ? null
        : tab == 4
            ? folderLabel(groupKey!)
            : groupKey!.split('\u0000').first;
    return PopScope(
        canPop: groupKey == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => groupKey = null);
        },
        child: Scaffold(
            body: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: load,
                  child: CustomScrollView(
                      key: const PageStorageKey('music-library'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            sliver: SliverToBoxAdapter(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          const Text('Müziklerim',
                                              style: TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -1)),
                                          const SizedBox(height: 4),
                                          Text(
                                              '${music.songs.length} şarkı · Her zaman yanında',
                                              style: TextStyle(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  fontSize: 12)),
                                        ])),
                                    PopupMenuButton<String>(
                                        tooltip: 'Arşiv seçenekleri',
                                        icon: const Icon(Icons.tune_rounded),
                                        onSelected: (value) {
                                          if (value == 'scan') {
                                            unawaited(load(request: true));
                                          } else {
                                            setState(() => sort = MusicSort
                                                .values[int.parse(value)]);
                                            unawaited(PlayerPreferences.instance
                                                .set(
                                                    'librarySort', sort.index));
                                          }
                                        },
                                        itemBuilder: (_) => [
                                              for (final value
                                                  in MusicSort.values)
                                                CheckedPopupMenuItem(
                                                    value: '${value.index}',
                                                    checked: value == sort,
                                                    child: Text(musicSortLabels[
                                                        value.index])),
                                              const PopupMenuDivider(),
                                              const PopupMenuItem(
                                                  value: 'scan',
                                                  child: Text(
                                                      'Müzikleri yeniden tara')),
                                            ]),
                                  ]),
                                  const SizedBox(height: 22),
                                  TextField(
                                      controller: search,
                                      focusNode: focus,
                                      onChanged: (_) => changed(),
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                          hintText:
                                              'Şarkı, sanatçı veya albüm ara',
                                          prefixIcon:
                                              const Icon(Icons.search_rounded),
                                          suffixIcon: search.text.isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: 'Aramayı temizle',
                                                  onPressed: () {
                                                    search.clear();
                                                    changed();
                                                  },
                                                  icon: const Icon(
                                                      Icons.close_rounded)))),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                      height: 42,
                                      child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: labels.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 8),
                                          itemBuilder: (c, i) => ChoiceChip(
                                              label: Text(labels[i]),
                                              selected: tab == i,
                                              showCheckmark: false,
                                              onSelected: (_) =>
                                                  selectTab(i)))),
                                  const SizedBox(height: 16),
                                  if (music.libraryError != null)
                                    Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: scheme.errorContainer,
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        child: Text(music.libraryError!,
                                            style: TextStyle(
                                                color:
                                                    scheme.onErrorContainer))),
                                  if (groupKey != null)
                                    Row(children: [
                                      IconButton(
                                          tooltip: 'Gruplara dön',
                                          onPressed: () =>
                                              setState(() => groupKey = null),
                                          icon: const Icon(
                                              Icons.arrow_back_rounded)),
                                      Expanded(
                                          child: Text(detailTitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight:
                                                      FontWeight.w800))),
                                    ]),
                                  if (music.hasPermission &&
                                      (tab < 2 || groupKey != null) &&
                                      songs.isNotEmpty)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Row(children: [
                                          Expanded(
                                              child: Text(
                                                  '${songs.length} şarkı · ${musicDurationLabel(songs)}',
                                                  style: TextStyle(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                      fontSize: 12))),
                                          IconButton(
                                              tooltip: 'Tümünü çal',
                                              onPressed: () => runMusicAction(
                                                  context,
                                                  () => playAll(songs)),
                                              icon: Icon(
                                                  Icons
                                                      .play_circle_fill_rounded,
                                                  color: scheme.primary,
                                                  size: 36)),
                                          IconButton(
                                              tooltip: 'Karışık çal',
                                              onPressed: () => runMusicAction(
                                                  context,
                                                  () => playAll(songs,
                                                      shuffled: true)),
                                              icon: const Icon(
                                                  Icons.shuffle_rounded)),
                                        ])),
                                ]))),
                        if (loading)
                          const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: CircularProgressIndicator()))
                        else if (!music.hasPermission)
                          SliverFillRemaining(
                              hasScrollBody: false,
                              child: MusicEmptyState(
                                  icon: Icons.library_music_outlined,
                                  title: 'Müzik arşivini aç',
                                  description:
                                      'Telefonundaki ses dosyalarını göstermek için müzik erişim izni gerekiyor.',
                                  actionLabel: 'Müziklere erişim ver',
                                  action: () async {
                                    await load(request: true);
                                    if (!music.hasPermission)
                                      await openAppSettings();
                                  }))
                        else if (selected.isEmpty ||
                            (groupKey != null && songs.isEmpty))
                          SliverFillRemaining(
                              hasScrollBody: false,
                              child: MusicEmptyState(
                                  icon: search.text.isNotEmpty
                                      ? Icons.search_off_rounded
                                      : tab == 1
                                          ? Icons.favorite_border_rounded
                                          : Icons.music_note_rounded,
                                  title: search.text.isNotEmpty
                                      ? 'Eşleşen müzik bulunamadı'
                                      : tab == 1
                                          ? 'Sevdiğin şarkılar burada'
                                          : 'Arşivin henüz boş',
                                  description: search.text.isNotEmpty
                                      ? 'Başka bir şarkı, sanatçı veya albüm adı dene.'
                                      : tab == 1
                                          ? 'Şarkı menüsündeki kalbe dokunarak favorilerine ekle.'
                                          : 'Telefonuna müzik ekledikten sonra yeniden tara.',
                                  actionLabel: search.text.isNotEmpty
                                      ? 'Aramayı temizle'
                                      : 'Yeniden tara',
                                  action: search.text.isNotEmpty
                                      ? () {
                                          search.clear();
                                          changed();
                                        }
                                      : () => load(request: true)))
                        else if (tab < 2 || groupKey != null)
                          SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList.builder(
                                  itemCount: songs.length,
                                  itemBuilder: (c, i) => MusicSongTile(
                                      song: songs[i],
                                      music: music,
                                      onPlay: () => music.playSong(songs[i],
                                          from: songs))))
                        else
                          SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList.builder(
                                  itemCount: groups.length,
                                  itemBuilder: (c, i) {
                                    final entry = groups.entries.elementAt(i);
                                    final name = tab == 4
                                        ? folderLabel(entry.key)
                                        : entry.key.split('\u0000').first;
                                    return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 6),
                                        leading: tab == 4
                                            ? Container(
                                                width: 54,
                                                height: 54,
                                                decoration: BoxDecoration(
                                                    color: scheme.primary
                                                        .withValues(alpha: .1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14)),
                                                child: Icon(Icons.folder_rounded,
                                                    color: scheme.primary))
                                            : MediaArtwork(
                                                id: entry.value.first.id),
                                        title: Text(name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        subtitle: Text(
                                            tab == 3 ? '${songArtist(entry.value.first)} · ${entry.value.length} şarkı' : '${entry.value.length} şarkı · ${musicDurationLabel(entry.value)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        trailing: const Icon(Icons.chevron_right_rounded),
                                        onTap: () => setState(() => groupKey = entry.key));
                                  })),
                        const SliverToBoxAdapter(child: SizedBox(height: 140)),
                      ]),
                ))));
  }
}
