import 'dart:io';

import '../platform/device_controls.dart';
import 'local_music_service.dart';
import 'player_preferences.dart';

enum VoiceAction { next, previous, pause, play, shuffle, repeat, unknown }

/// Maps a recognised sentence (TR/EN/KU/AR keywords) to a player action.
VoiceAction parseVoiceCommand(String? heard) {
  final t = (heard ?? '').toLowerCase();
  bool has(List<String> words) => words.any(t.contains);
  if (has(['sonraki', 'ileri', 'geç', 'next', 'skip', 'piştî', 'التالي', 'دواتر'])) {
    return VoiceAction.next;
  }
  if (has(['önceki', 'geri', 'previous', 'back', 'berê', 'السابق', 'پێشوو'])) {
    return VoiceAction.previous;
  }
  if (has(['dur', 'durdur', 'duraklat', 'sus', 'pause', 'stop', 'raweste', 'توقف', 'ڕاگرتن'])) {
    return VoiceAction.pause;
  }
  if (has(['karıştır', 'karışık', 'shuffle', 'عشوائي'])) return VoiceAction.shuffle;
  if (has(['tekrar', 'repeat', 'تكرار'])) return VoiceAction.repeat;
  if (has(['çal', 'oynat', 'devam', 'başlat', 'play', 'resume', 'lêxe', 'تشغيل', 'لێدان'])) {
    return VoiceAction.play;
  }
  return VoiceAction.unknown;
}

Future<String?> listenVoiceCommand() async {
  if (!Platform.isAndroid) return null;
  const locales = {'tr': 'tr-TR', 'en': 'en-US', 'ku': 'ku', 'ckb': 'ckb', 'ar': 'ar'};
  final lang = PlayerPreferences.instance.text('language', 'tr');
  try {
    return await DeviceControls.channel
        .invokeMethod<String>('voiceCommand', locales[lang] ?? 'tr-TR');
  } catch (_) {
    return null;
  }
}

/// Listens once and runs the command. Returns the recognised action.
Future<VoiceAction?> runVoiceCommand(LocalMusicService m) async {
  final heard = await listenVoiceCommand();
  if (heard == null) return null;
  final action = parseVoiceCommand(heard);
  switch (action) {
    case VoiceAction.next:
      await m.next();
    case VoiceAction.previous:
      await m.previous();
    case VoiceAction.pause:
      await m.pause();
    case VoiceAction.play:
      if (!m.player.playing) await m.togglePlayPause();
    case VoiceAction.shuffle:
      await m.toggleShuffle();
    case VoiceAction.repeat:
      await m.cycleRepeatMode();
    case VoiceAction.unknown:
      break;
  }
  return action;
}
