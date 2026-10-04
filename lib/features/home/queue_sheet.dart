import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/local_music_service.dart';
import 'widgets/music_widgets.dart';

Future<void> showPlaybackQueue(BuildContext context, LocalMusicService music) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _QueueSheet(music: music));

class _QueueSheet extends StatelessWidget {
  const _QueueSheet({required this.music});
  final LocalMusicService music;
  @override
  Widget build(BuildContext context) => SafeArea(
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: StreamBuilder<SequenceState>(
            stream: music.player.sequenceStateStream,
            builder: (c, _) {
              final items = music.queueItems;
              final current = music.player.currentIndex;
              return Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Çalma sırası',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w800)),
                            Text('${items.length} şarkı · Sürükleyerek düzenle',
                                style: TextStyle(
                                    color: Theme.of(c)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12)),
                          ])),
                      IconButton(tooltip: 'Sırayı listeye kaydet', icon: const Icon(Icons.playlist_add),
                        onPressed: items.isEmpty ? null : () async {
                          final text = TextEditingController();
                          final name = await showDialog<String>(context: c, builder: (d) => AlertDialog(
                            title: const Text('Sırayı listeye kaydet'),
                            content: TextField(controller: text, autofocus: true, decoration: const InputDecoration(labelText: 'Yeni liste adı')),
                            actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Vazgeç')),
                              FilledButton(onPressed: () => Navigator.pop(d, text.text), child: const Text('Kaydet'))]));
                          // Dispose after the dialog route has completed its closing transition.
                          Future<void>.delayed(const Duration(seconds: 1), text.dispose);
                          if (name != null && c.mounted) await runMusicAction(c, () => music.saveQueueAsPlaylist(name));
                        }),
                      TextButton(
                          onPressed: items.length < 2
                              ? null
                              : () => runMusicAction(c, music.clearUpcoming),
                          child: const Text('Temizle')),
                    ])),
                if (music.player.shuffleModeEnabled)
                  const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                          'Sırayı elle değiştirdiğinde karışık çalma kapanır.',
                          style: TextStyle(fontSize: 12))),
                Expanded(
                    child: items.isEmpty
                        ? const MusicEmptyState(
                            icon: Icons.queue_music_rounded,
                            title: 'Sıra boş',
                            description:
                                'Şarkı seçeneklerinden çalma sırasına müzik ekleyebilirsin.')
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: items.length,
                            onReorderItem: (from, to) => runMusicAction(
                                c, () => music.moveQueueItem(from, to)),
                            itemBuilder: (c, i) {
                              final item = items[i];
                              final selected = current == i;
                              return ListTile(
                                key: ValueKey('queue-$i-${item.id}'),
                                selected: selected,
                                selectedTileColor: Theme.of(c)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: .1),
                                leading: MediaArtwork(
                                    id: int.tryParse(item.id),
                                    uri: item.artUri,
                                    size: 46),
                                title: Text(item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                subtitle: Text(
                                    selected
                                        ? 'Şimdi çalıyor'
                                        : item.artist ?? 'Bilinmeyen sanatçı',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () => runMusicAction(
                                    c, () => music.playQueueIndex(i)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                          tooltip: 'Sıradan kaldır',
                                          onPressed: () => runMusicAction(c,
                                              () => music.removeQueueItem(i)),
                                          icon: const Icon(Icons.close_rounded,
                                              size: 19)),
                                      ReorderableDragStartListener(
                                          index: i,
                                          child: const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Icon(
                                                  Icons.drag_handle_rounded))),
                                    ]),
                              );
                            },
                          )),
              ]);
            },
          )));
}
