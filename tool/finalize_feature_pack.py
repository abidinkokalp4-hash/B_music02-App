from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding='utf-8')
    if new in text:
        print(f'{label}: already applied')
        return
    if old not in text:
        raise SystemExit(f'{label}: target not found in {path}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'{label}: applied')


# 1) Restore favorites/playlists/repeat/shuffle from cloud backup.
music = ROOT / 'lib/core/services/local_music_service.dart'
replace_once(
    music,
    """  Future<void> _savePlaylists() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistsKey, jsonEncode(_playlists));
    notifyListeners();
  }

  Future<void> stop() async {
""",
    """  Future<void> _savePlaylists() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistsKey, jsonEncode(_playlists));
    notifyListeners();
  }

  Future<void> restoreLibraryPreferences(Map<String, dynamic> payload) async {
    await _loadPreferences();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final dynamic favorites = payload['favorites'];
    if (favorites is List) {
      favoriteIds
        ..clear()
        ..addAll(
          favorites
              .map((value) => int.tryParse(value.toString()))
              .whereType<int>(),
        );
      await prefs.setStringList(
        _favoritesKey,
        favoriteIds.map((id) => id.toString()).toList(),
      );
    }

    final dynamic playlists = payload['playlists'];
    if (playlists is Map) {
      _playlists.clear();
      for (final entry in playlists.entries) {
        final name = entry.key.toString().trim();
        final values = entry.value;
        if (name.isEmpty || values is! List) continue;
        _playlists[name] = values
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>()
            .toSet()
            .toList();
      }
      await prefs.setString(_playlistsKey, jsonEncode(_playlists));
    }

    final repeatMode = int.tryParse(payload['repeatMode']?.toString() ?? '');
    if (repeatMode != null &&
        repeatMode >= 0 &&
        repeatMode < LoopMode.values.length) {
      await player.setLoopMode(LoopMode.values[repeatMode]);
    }

    final shuffle = payload['shuffle'];
    if (shuffle is bool) {
      if (shuffle) {
        await player.shuffle();
      }
      await player.setShuffleModeEnabled(shuffle);
    }

    notifyListeners();
  }

  Future<void> stop() async {
""",
    'cloud library restore',
)

insights = ROOT / 'lib/core/services/music_insights_service.dart'
replace_once(
    insights,
    """      'listeningDays': prefs.getStringList(_daysKey) ?? <String>[],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
""",
    """      'listeningDays': prefs.getStringList(_daysKey) ?? <String>[],
      'repeatMode': _music.player.loopMode.index,
      'shuffle': _music.player.shuffleModeEnabled,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
""",
    'backup playback preferences',
)
replace_once(
    insights,
    """    if (days is List) {
      await prefs.setStringList(
        _daysKey,
        days.map((value) => value.toString()).toList(),
      );
    }
    _changes.add(null);
""",
    """    if (days is List) {
      await prefs.setStringList(
        _daysKey,
        days.map((value) => value.toString()).toList(),
      );
    }
    await _music.restoreLibraryPreferences(payload);
    _changes.add(null);
""",
    'restore favorites and playlists',
)

# 2) Finish voice-message recording/upload/playback in music rooms.
rooms = ROOT / 'lib/features/chat/group_rooms_v2_screen.dart'
replace_once(
    rooms,
    """import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
""",
    """import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
""",
    'voice imports',
)
replace_once(
    rooms,
    """  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  Map<String, SocialProfile> _profiles = <String, SocialProfile>{};
  Map<String, dynamic>? _replyTo;
  bool _sending = false;
""",
    """  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();

  Map<String, SocialProfile> _profiles = <String, SocialProfile>{};
  Map<String, dynamic>? _replyTo;
  bool _sending = false;
  bool _recordingVoice = false;
  String? _playingVoiceId;
""",
    'voice state',
)
replace_once(
    rooms,
    """  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
""",
    """  void initState() {
    super.initState();
    _loadProfiles();
    _voicePlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingVoiceId = null);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _recorder.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
""",
    'voice lifecycle',
)
replace_once(
    rooms,
    """  Future<void> _sendText() async {
""",
    """  Future<void> _toggleVoiceRecording() async {
    if (_recordingVoice) {
      final path = await _recorder.stop();
      if (mounted) setState(() => _recordingVoice = false);
      if (path != null && path.isNotEmpty) {
        await _sendVoiceMessage(path);
      }
      return;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _message('Sesli mesaj için mikrofon izni gerekli.');
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/b_music02_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (mounted) setState(() => _recordingVoice = true);
    } catch (error) {
      _message('Ses kaydı başlatılamadı: $error');
    }
  }

  Future<void> _sendVoiceMessage(String localPath) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final file = File(localPath);
    if (!await file.exists()) return;

    setState(() => _sending = true);
    try {
      final storagePath = '${user.id}/$_roomId/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _supabase.storage.from('voice-messages').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(
          contentType: 'audio/mp4',
          upsert: false,
        ),
      );

      await _supabase.from('room_messages').insert({
        'room_id': _roomId,
        'sender_id': user.id,
        'body': '🎙️ Sesli mesaj',
        'reply_to': _replyTo?['id'],
        'message_type': 'voice',
        'metadata': {
          'storage_path': storagePath,
          'format': 'm4a',
        },
      });
      if (mounted) setState(() => _replyTo = null);
    } catch (error) {
      _message('Sesli mesaj gönderilemedi: $error');
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _playVoiceMessage(Map<String, dynamic> message) async {
    final id = message['id']?.toString() ?? '';
    final raw = message['metadata'];
    final metadata = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final storagePath = metadata['storage_path']?.toString();
    if (id.isEmpty || storagePath == null || storagePath.isEmpty) return;

    try {
      if (_playingVoiceId == id && _voicePlayer.playing) {
        await _voicePlayer.pause();
        if (mounted) setState(() => _playingVoiceId = null);
        return;
      }

      await _music.pause();
      final signedUrl = await _supabase.storage
          .from('voice-messages')
          .createSignedUrl(storagePath, 3600);
      await _voicePlayer.setUrl(signedUrl);
      if (mounted) setState(() => _playingVoiceId = id);
      await _voicePlayer.play();
      if (mounted && _playingVoiceId == id) {
        setState(() => _playingVoiceId = null);
      }
    } catch (error) {
      _message('Sesli mesaj açılamadı: $error');
      if (mounted) setState(() => _playingVoiceId = null);
    }
  }

  Future<void> _sendText() async {
""",
    'voice record send and playback',
)
replace_once(
    rooms,
    """  Widget _songCard(Map<String, dynamic> message) {
""",
    """  Widget _voiceCard(Map<String, dynamic> message) {
    final id = message['id']?.toString() ?? '';
    final playing = _playingVoiceId == id && _voicePlayer.playing;
    return InkWell(
      onTap: () => _playVoiceMessage(message),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(top: 5),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: AppColors.gold.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: AppColors.gold,
              size: 31,
            ),
            const SizedBox(width: 9),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sesli mesaj',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                  Text(
                    'Dinlemek için dokun',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.graphic_eq_rounded, color: AppColors.gold, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _songCard(Map<String, dynamic> message) {
""",
    'voice card',
)
replace_once(
    rooms,
    """                    final isSong = message['message_type']?.toString() == 'song';
                    return GestureDetector(
""",
    """                    final isSong = message['message_type']?.toString() == 'song';
                    final isVoice = message['message_type']?.toString() == 'voice';
                    return GestureDetector(
""",
    'voice message type',
)
replace_once(
    rooms,
    """                              if (isSong) _songCard(message) else Text(message['body']?.toString() ?? ''),
""",
    """                              if (isSong)
                                _songCard(message)
                              else if (isVoice)
                                _voiceCard(message)
                              else
                                Text(message['body']?.toString() ?? ''),
""",
    'voice message renderer',
)
replace_once(
    rooms,
    """                  IconButton(
                    tooltip: 'Çalan şarkıyı paylaş',
                    onPressed: _sendCurrentSong,
                    icon: const Icon(Icons.music_note_rounded, color: AppColors.gold),
                  ),
                  Expanded(
""",
    """                  IconButton(
                    tooltip: 'Çalan şarkıyı paylaş',
                    onPressed: _recordingVoice ? null : _sendCurrentSong,
                    icon: const Icon(Icons.music_note_rounded, color: AppColors.gold),
                  ),
                  IconButton(
                    tooltip: _recordingVoice ? 'Kaydı bitir ve gönder' : 'Sesli mesaj kaydet',
                    onPressed: _sending ? null : _toggleVoiceRecording,
                    icon: Icon(
                      _recordingVoice ? Icons.stop_circle_rounded : Icons.mic_rounded,
                      color: _recordingVoice ? Colors.redAccent : AppColors.gold,
                    ),
                  ),
                  Expanded(
""",
    'voice composer button',
)
replace_once(
    rooms,
    """                      decoration: const InputDecoration(hintText: 'Mesaj yaz...'),
                      onSubmitted: (_) => _sendText(),
""",
    """                      enabled: !_recordingVoice,
                      decoration: InputDecoration(
                        hintText: _recordingVoice ? 'Ses kaydı yapılıyor…' : 'Mesaj yaz...',
                      ),
                      onSubmitted: (_) => _sendText(),
""",
    'voice recording composer state',
)

print('Final feature pack patch completed.')
