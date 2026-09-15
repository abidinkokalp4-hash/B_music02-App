import '../../core/l10n/app_text.dart';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_insights_service.dart';

class PlaylistsHub extends StatefulWidget {
  const PlaylistsHub({super.key});
  @override
  State<PlaylistsHub> createState() => _Playlists();
}

class _Playlists extends State<PlaylistsHub> {
  final music = LocalMusicService.instance;
  String? selected;
  String? collection;
  List<SongModel> history = [];
  @override
  void initState() {
    super.initState();
    music.addListener(changed);
  }

  @override
  void dispose() {
    music.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> nameDialog({String? old}) async {
    final controller = TextEditingController(text: old);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(old == null ? 'Yeni Liste' : 'Listeyi yeniden adlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Liste adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const AppText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const AppText('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      if (old == null) {
        await music.createPlaylist(name);
      } else {
        await music.renamePlaylist(old, name);
        if (selected == old) selected = name;
      }
      changed();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Farklı ve boş olmayan bir liste adı girin.'),
          ),
        );
    }
  }

  Future<void> stats(String name) async {
    final entries = name == 'Son Dinlenenler'
        ? await MusicInsightsService.instance.recentTracks(limit: 40)
        : await MusicInsightsService.instance.topTracks(limit: 100);
    final byId = {for (final s in music.songs) s.id.toString(): s};
    history = entries.map((e) => byId[e.id]).whereType<SongModel>().toList();
    if (mounted) setState(() => collection = name);
  }

  Future<void> remove(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: AppText('$name silinsin mi?'),
        content: const AppText(
          'Sadece çalma listesi kaldırılır. Şarkı dosyaları korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const AppText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const AppText('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await music.deletePlaylist(name);
      if (selected == name) selected = null;
      changed();
    }
  }

  Future<void> addSongs() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .7,
            child: ListView(
              children: [
                const ListTile(title: AppText('Listeye şarkı ekle')),
                ...music.songs.map(
                  (s) => CheckboxListTile(
                    title: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: music.playlists[selected]?.contains(s.id) ?? false,
                    onChanged: (value) async {
                      if (value == true) {
                        await music.addToPlaylist(selected!, s);
                      } else {
                        await music.removeFromPlaylist(selected!, s);
                      }
                      refresh(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final detail = selected != null || collection != null;
    final songs = selected != null
        ? music.playlistSongs(selected!)
        : collection == 'Favoriler'
        ? music.favoriteSongs
        : history;
    return PopScope(
      canPop: !detail,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop)
          setState(() {
            selected = null;
            collection = null;
          });
      },
      child: Scaffold(
        appBar: AppBar(
          leading: detail
              ? BackButton(
                  onPressed: () => setState(() {
                    selected = null;
                    collection = null;
                  }),
                )
              : null,
          title: Text(selected ?? collection ?? 'Listelerim'),
          actions: [
            if (selected != null)
              IconButton(
                tooltip: 'Şarkı ekle',
                onPressed: addSongs,
                icon: const Icon(Icons.playlist_add),
              )
            else if (!detail)
              TextButton.icon(
                onPressed: () => nameDialog(),
                icon: const Icon(Icons.add),
                label: const AppText('Yeni Liste'),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 160),
          children: detail
              ? [
                  if (songs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: AppText('Bu listede henüz şarkı yok.'),
                    ),
                  ...songs.map(
                    (s) => ListTile(
                      leading: QueryArtworkWidget(
                        id: s.id,
                        type: ArtworkType.AUDIO,
                        nullArtworkWidget: const Icon(Icons.music_note),
                      ),
                      title: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        s.artist ?? 'Bilinmeyen sanatçı',
                        maxLines: 1,
                      ),
                      onTap: () => music.playSong(s, from: songs),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'remove') {
                            await music.removeFromPlaylist(selected!, s);
                          } else {
                            await music.toggleFavorite(s);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'favorite',
                            child: Text(
                              music.isFavorite(s)
                                  ? 'Favorilerden çıkar'
                                  : 'Favorilere ekle',
                            ),
                          ),
                          if (selected != null)
                            const PopupMenuItem(
                              value: 'remove',
                              child: AppText('Listeden çıkar'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ]
              : [
                  Row(
                    children: [
                      stat(
                        Icons.favorite,
                        'Favoriler',
                        '${music.favoriteIds.length} şarkı',
                        () => setState(() => collection = 'Favoriler'),
                      ),
                      const SizedBox(width: 8),
                      stat(
                        Icons.history,
                        'Son Dinlenenler',
                        'Geçmiş',
                        () => stats('Son Dinlenenler'),
                      ),
                      const SizedBox(width: 8),
                      stat(
                        Icons.bar_chart,
                        'En Çok',
                        'Dinlenenler',
                        () => stats('En Çok Dinlenenler'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const AppText(
                    'Çalma Listelerim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  if (music.playlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: TextButton.icon(
                        onPressed: () => nameDialog(),
                        icon: const Icon(Icons.playlist_add),
                        label: const AppText('İlk çalma listeni oluştur'),
                      ),
                    ),
                  ...music.playlists.entries.map(
                    (entry) => ListTile(
                      leading: const Icon(Icons.queue_music, size: 36),
                      title: Text(entry.key),
                      subtitle: AppText('${entry.value.length} şarkı'),
                      onTap: () => setState(() => selected = entry.key),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => v == 'rename'
                            ? nameDialog(old: entry.key)
                            : remove(entry.key),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: AppText('Yeniden adlandır'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: AppText('Listeyi sil'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  Widget stat(IconData icon, String title, String subtitle, VoidCallback tap) =>
      Expanded(
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 112,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      );
}
