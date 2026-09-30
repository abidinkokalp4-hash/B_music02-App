import 'dart:io';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/local_music_service.dart';
import '../../../core/services/music_catalog.dart';

Future<void> runMusicAction(
    BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('İşlem tamamlanamadı. Dosya ve erişim izinlerini kontrol et.'),
      ));
    }
  }
}

class MediaArtwork extends StatelessWidget {
  const MediaArtwork(
      {super.key,
      this.id,
      this.uri,
      this.label = '',
      this.size = 52,
      this.radius = 14});
  final int? id;
  final Uri? uri;
  final String label;
  final double size, radius;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final hue = ((id ?? label.hashCode).abs() * 37) % 360;
    final color = HSVColor.fromAHSV(1, hue.toDouble(), .48, .45).toColor();
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, Color.lerp(color, accent, .25)!.withValues(alpha: .6)],
      )),
      child: Center(
          child: Icon(Icons.album_rounded,
              color: Colors.white.withValues(alpha: .8), size: size * .43)),
    );
    Widget artwork = fallback;
    if (id != null) {
      artwork = QueryArtworkWidget(
        key: ValueKey(id),
        id: id!,
        type: ArtworkType.AUDIO,
        size: size > 180 ? 700 : 200,
        artworkWidth: size,
        artworkHeight: size,
        artworkFit: BoxFit.cover,
        artworkBorder: BorderRadius.zero,
        keepOldArtwork: true,
        nullArtworkWidget: fallback,
      );
    } else if (uri?.scheme == 'file') {
      artwork = Image.file(File.fromUri(uri!),
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    }
    return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.square(dimension: size, child: artwork));
  }
}

class MusicEmptyState extends StatelessWidget {
  const MusicEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      this.action,
      this.actionLabel});
  final IconData icon;
  final String title, description;
  final VoidCallback? action;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(24)),
              child: Icon(icon, size: 34, color: scheme.primary)),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(description,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
          if (action != null) ...[
            const SizedBox(height: 20),
            FilledButton(
                onPressed: action, child: Text(actionLabel ?? 'Devam et')),
          ],
        ]));
  }
}

class MusicSectionTitle extends StatelessWidget {
  const MusicSectionTitle(
      {super.key, required this.title, this.subtitle, this.onAll});
  final String title;
  final String? subtitle;
  final VoidCallback? onAll;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6)),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle!,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant))),
        ])),
        if (onAll != null)
          TextButton(onPressed: onAll, child: const Text('Tümü')),
      ]));
}

class MusicSongTile extends StatelessWidget {
  const MusicSongTile(
      {super.key,
      required this.song,
      required this.onPlay,
      required this.music,
      this.subtitle,
      this.trailing});
  final SongModel song;
  final LocalMusicService music;
  final Future<void> Function() onPlay;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = music.currentMediaItem?.id == song.id.toString();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      selected: selected,
      selectedTileColor: scheme.primary.withValues(alpha: .07),
      leading: Stack(children: [
        MediaArtwork(id: song.id, label: song.title),
        if (selected)
          Positioned.fill(
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .38),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.graphic_eq_rounded,
                      color: Colors.white))),
      ]),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? scheme.primary : scheme.onSurface)),
      subtitle: Text(
          subtitle ??
              '${songArtist(song)} · ${formatMusicTime(Duration(milliseconds: song.duration ?? 0))}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      onTap: () => runMusicAction(context, onPlay),
      trailing: trailing ??
          IconButton(
              tooltip: 'Şarkı seçenekleri',
              onPressed: () => showSongActions(context, music, song),
              icon: const Icon(Icons.more_horiz_rounded)),
    );
  }
}

Future<String?> askPlaylistName(BuildContext context, {String? current}) async {
  final controller = TextEditingController(text: current);
  final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
            title: Text(current == null
                ? 'Yeni çalma listesi'
                : 'Liste adını değiştir'),
            content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                decoration:
                    const InputDecoration(hintText: 'Örneğin: Uzun yol'),
                onSubmitted: (name) {
                  if (name.trim().isNotEmpty) Navigator.pop(c, name.trim());
                }),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Vazgeç')),
              FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty)
                      Navigator.pop(c, controller.text.trim());
                  },
                  child: const Text('Kaydet')),
            ],
          ));
  // The route may keep the text field alive through its exit animation.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return name;
}

Future<void> addSongsToList(BuildContext context, LocalMusicService music,
    List<SongModel> songs) async {
  final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .7),
              child: ListView(shrinkWrap: true, children: [
                const ListTile(
                    title: Text('Çalma listesine ekle',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 19))),
                ListTile(
                    leading: const Icon(Icons.add_rounded),
                    title: const Text('Yeni liste oluştur'),
                    onTap: () => Navigator.pop(c, '\u0000new')),
                for (final entry in music.playlists.entries)
                  ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(entry.key),
                      subtitle: Text('${entry.value.length} şarkı'),
                      onTap: () => Navigator.pop(c, entry.key)),
                const SizedBox(height: 12),
              ]))));
  if (selected == null || !context.mounted) return;
  String name = selected;
  if (selected == '\u0000new') {
    final created = await askPlaylistName(context);
    if (created == null || !context.mounted) return;
    name = created;
    try {
      await music.createPlaylist(name);
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bu adla bir liste var. Farklı bir ad seç.')));
      return;
    }
  }
  await music.addSongsToPlaylist(name, songs);
  if (context.mounted)
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name listesine eklendi.')));
}

Future<void> showSongActions(
    BuildContext context, LocalMusicService music, SongModel song) async {
  final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
            ListTile(
                leading: MediaArtwork(id: song.id),
                title: Text(song.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(songArtist(song))),
            const Divider(indent: 20, endIndent: 20),
            for (final row in <(String, IconData, String)>[
              ('next', Icons.playlist_play_rounded, 'Sonraki çal'),
              ('queue', Icons.queue_music_rounded, 'Sıranın sonuna ekle'),
              (
                'favorite',
                music.isFavorite(song)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                music.isFavorite(song)
                    ? 'Favorilerden çıkar'
                    : 'Favorilere ekle'
              ),
              ('playlist', Icons.playlist_add_rounded, 'Çalma listesine ekle'),
              ('share', Icons.ios_share_rounded, 'Müzik dosyasını paylaş'),
              ('info', Icons.info_outline_rounded, 'Dosya bilgileri'),
            ])
              ListTile(
                  leading: Icon(row.$2),
                  title: Text(row.$3),
                  onTap: () => Navigator.pop(c, row.$1)),
            const SizedBox(height: 12),
          ])));
  if (result == null || !context.mounted) return;
  await runMusicAction(context, () async {
    switch (result) {
      case 'next':
      case 'queue':
        await music.enqueue(song, next: result == 'next');
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result == 'next'
                  ? 'Sonraki şarkı olarak eklendi.'
                  : 'Çalma sırasına eklendi.')));
        break;
      case 'favorite':
        await music.toggleFavorite(song);
        break;
      case 'playlist':
        await addSongsToList(context, music, [song]);
        break;
      case 'share':
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(ShareParams(
            files: [XFile(song.data)],
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size));
        break;
      case 'info':
        await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
                  title: const Text('Dosya bilgileri'),
                  content: SelectableText(
                      '${song.title}\n\nSanatçı: ${songArtist(song)}\nAlbüm: ${songAlbum(song)}\n'
                      'Süre: ${formatMusicTime(Duration(milliseconds: song.duration ?? 0))}\n'
                      'Boyut: ${(song.size / 1048576).toStringAsFixed(1)} MB\n\n${song.data}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Tamam'))
                  ],
                ));
        break;
    }
  });
}
