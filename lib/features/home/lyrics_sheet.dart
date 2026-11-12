import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_text.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/music_catalog.dart';
import '../../core/theme/aurora.dart';
import 'widgets/music_widgets.dart';

Future<void> showLyricsSheet(BuildContext context, {LocalMusicService? music}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => LyricsSheet(music: music ?? LocalMusicService.instance),
  );
}

class LyricsSheet extends StatefulWidget {
  const LyricsSheet({super.key, required this.music, this.service});
  final LocalMusicService music;
  final LyricsService? service;
  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  LyricsResult? result;
  bool loading = true;
  String? askedFor;
  final keys = <int, GlobalKey>{};
  int highlighted = -1;
  StreamSubscription<Duration>? positions;

  LyricsService get service => widget.service ?? LyricsService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(load());
    positions = widget.music.player.positionStream.listen(sync);
    widget.music.addListener(onMusic);
  }

  void onMusic() {
    final id = widget.music.currentMediaItem?.id;
    if (id != null && id != askedFor) unawaited(load());
  }

  @override
  void dispose() {
    positions?.cancel();
    widget.music.removeListener(onMusic);
    super.dispose();
  }

  Future<void> load() async {
    final item = widget.music.currentMediaItem;
    if (item == null) {
      if (mounted) setState(() { loading = false; result = LyricsResult.notFound; });
      return;
    }
    askedFor = item.id;
    if (mounted) setState(() { loading = true; result = null; highlighted = -1; });
    final fetched = await service.fetch(
      title: item.title,
      artist: knownMetadata(item.artist, ''),
      duration: widget.music.player.duration ?? item.duration,
    );
    if (!mounted || askedFor != item.id) return;
    setState(() { loading = false; result = fetched; });
    sync(widget.music.player.position);
  }

  void sync(Duration position) {
    final lines = result?.synced ?? const <LyricsLine>[];
    if (lines.isEmpty) return;
    final i = LyricsService.activeIndex(lines, position);
    if (i == highlighted) return;
    highlighted = i;
    if (mounted) setState(() {});
    final key = keys[i];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.music.currentMediaItem;
    final height = MediaQuery.sizeOf(context).height * .88;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFF120B28),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              IconButton(
                  tooltip: tr('Sayfayı kapat'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded)),
              const Expanded(
                  child: AppText('Sözler',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(
                  tooltip: tr('Yenile'),
                  onPressed: loading ? null : () => load(),
                  icon: const Icon(Icons.refresh_rounded)),
            ]),
          ),
          if (item != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                MediaArtwork(id: int.tryParse(item.id), uri: item.artUri, size: 44, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      AppText(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      AppText(knownMetadata(item.artist, 'Bilinmeyen sanatçı'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Aurora.textMuted)),
                    ])),
              ]),
            ),
          const Divider(height: 1),
          Expanded(child: body()),
        ]),
      ),
    );
  }

  Widget body() {
    if (loading) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        AppText('Sözler yükleniyor…'),
      ]));
    }
    final data = result;
    if (data == null || !data.found) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lyrics_outlined, size: 48, color: Aurora.textMuted),
          SizedBox(height: 14),
          AppText('Söz bulunamadı',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          AppText('Bu şarkı için söz bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Aurora.textMuted)),
        ]),
      ));
    }
    if (data.isSynced) {
      final lines = data.synced;
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        itemCount: lines.length,
        itemBuilder: (c, i) {
          keys[i] = keys[i] ?? GlobalKey();
          final active = i == highlighted;
          return InkWell(
            key: keys[i],
            onTap: () => runMusicAction(c, () => widget.music.seek(lines[i].time)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                lines[i].text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: active ? 20 : 16,
                  height: 1.4,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? Colors.white : Aurora.textMuted,
                ),
              ),
            ),
          );
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      children: [
        SelectableText(
          data.displayPlain,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white),
        ),
      ],
    );
  }
}
