import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/l10n/app_text.dart';
import '../home/share_card.dart';
import 'song_letter_screen.dart';
import 'story_share_sheet.dart';

/// Full player share button: story video, song letter or the still card.
Future<void> showShareChoices(
    BuildContext context, MediaItem item, SongModel? song) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (song != null) ...[
          ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFB65CFF)),
              title: const AppText('Hikâyede paylaş'),
              subtitle: const AppText('15 saniyelik sesli video · Instagram, WhatsApp'),
              onTap: () => Navigator.pop(c, 'story')),
          ListTile(
              leading: const Icon(Icons.mail_outline_rounded, color: Color(0xFFB65CFF)),
              title: const AppText('Şarkı mektubu gönder'),
              subtitle: const AppText('Mesajını yaz, link olarak gönder'),
              onTap: () => Navigator.pop(c, 'letter')),
        ],
        ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const AppText('Paylaşım kartı'),
            subtitle: const AppText('“Şu an dinliyorum” görseli'),
            onTap: () => Navigator.pop(c, 'card')),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'story':
      await showStoryShare(context,
          path: song!.data,
          title: item.title,
          artist: item.artist,
          artwork: item.artUri,
          duration: Duration(milliseconds: song.duration ?? 0),
          seed: song.id);
    case 'letter':
      openSongLetter(context, song: song);
    case 'card':
      await shareNowPlayingCard(
          title: item.title, artist: item.artist, artwork: item.artUri);
  }
}
