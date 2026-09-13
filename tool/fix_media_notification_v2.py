from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

main = ROOT / 'lib/main.dart'
text = main.read_text(encoding='utf-8')
old = """  await AudioService.init(\n    builder: () => LocalMusicService.instance.createHandler(),\n    config: AudioServiceConfig(\n      androidNotificationChannelId: 'com.example.b_music02.media.playback.v3',\n      androidNotificationChannelName: 'B_music02 Müzik',\n      androidNotificationChannelDescription:\n          'Çalan müzik ve kilit ekranı medya kontrolleri',\n      androidNotificationOngoing: true,\n      androidNotificationClickStartsActivity: true,\n      androidStopForegroundOnPause: false,\n      androidNotificationIcon: 'drawable/ic_stat_music',\n    ),\n  );\n"""
new = """  final AudioHandler audioHandler = await AudioService.init(\n    builder: () => LocalMusicService.instance.createHandler(),\n    config: const AudioServiceConfig(\n      androidNotificationChannelId: 'com.example.b_music02.media.playback.v4',\n      androidNotificationChannelName: 'B_music02 Müzik',\n      androidNotificationChannelDescription:\n          'Çalan müzik ve kilit ekranı medya kontrolleri',\n      androidNotificationOngoing: true,\n      androidNotificationClickStartsActivity: true,\n      androidStopForegroundOnPause: false,\n    ),\n  );\n  LocalMusicService.instance.attachAudioHandler(audioHandler);\n"""
if old not in text:
    raise SystemExit('main AudioService block not found')
text = text.replace(old, new, 1)
main.write_text(text, encoding='utf-8')

service = ROOT / 'lib/core/services/local_music_service.dart'
text = service.read_text(encoding='utf-8')
old = """    _localAudioHandler = handler;\n    _audioHandler = handler;\n    return handler;\n  }\n\n  Future<void> _loadPreferences() async {\n"""
new = """    _localAudioHandler = handler;\n    return handler;\n  }\n\n  void attachAudioHandler(AudioHandler handler) {\n    _audioHandler = handler;\n  }\n\n  Future<void> _loadPreferences() async {\n"""
if old not in text:
    raise SystemExit('service handler assignment block not found')
text = text.replace(old, new, 1)
service.write_text(text, encoding='utf-8')

print('Media notification v2 patch applied.')
