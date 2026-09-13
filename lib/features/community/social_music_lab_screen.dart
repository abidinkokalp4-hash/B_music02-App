import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/theme/app_theme.dart';

class SocialMusicLabScreen extends StatefulWidget {
  const SocialMusicLabScreen({super.key});

  @override
  State<SocialMusicLabScreen> createState() => _SocialMusicLabScreenState();
}

class _SocialMusicLabScreenState extends State<SocialMusicLabScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalMusicService _music = LocalMusicService.instance;
  final MusicInsightsService _insights = MusicInsightsService.instance;

  bool _loading = true;
  bool _tastePublic = false;
  List<Map<String, dynamic>> _matches = const [];
  List<Map<String, dynamic>> _playlists = const [];
  List<Map<String, dynamic>> _sessions = const [];
  Map<String, Map<String, dynamic>> _profiles = const {};

  Timer? _hostTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _joinedSessionSub;
  String? _hostedSessionId;
  String? _joinedSessionId;

  User? get _user => _supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostTimer?.cancel();
    _joinedSessionSub?.cancel();
    super.dispose();
  }

  String _key(String? title, String? artist) {
    String normalize(String? value) => (value ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+'), '')
        .trim();
    return '${normalize(title)}|${normalize(artist)}';
  }

  Future<List<Map<String, dynamic>>> _myTasteRows() async {
    final top = await _insights.topTracks(limit: 20);
    return top
        .map(
          (item) => <String, dynamic>{
            'title': item.title,
            'artist': item.artist,
            'album': item.album,
            'key': _key(item.title, item.artist),
            'plays': item.plays,
          },
        )
        .where((row) => row['key'] != '|')
        .toList();
  }

  Future<void> _load() async {
    final user = _user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        _supabase.from('profiles').select('id, username, display_name, avatar_url'),
        _supabase
            .from('music_taste_profiles')
            .select('user_id, top_tracks, is_public, updated_at'),
        _supabase
            .from('shared_playlists')
            .select('id, owner_id, name, description, is_public, created_at')
            .order('updated_at', ascending: false),
        _supabase
            .from('listening_sessions')
            .select('id, host_id, title, artist, album, track_key, position_ms, is_playing, updated_at')
            .eq('is_active', true)
            .order('updated_at', ascending: false),
        _myTasteRows(),
      ]);

      final profileRows = (values[0] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final tasteRows = (values[1] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final myTaste = values[4] as List<Map<String, dynamic>>;
      final myKeys = myTaste.map((row) => row['key'].toString()).toSet();
      final profiles = <String, Map<String, dynamic>>{
        for (final row in profileRows) row['id'].toString(): row,
      };

      bool public = false;
      final matches = <Map<String, dynamic>>[];
      for (final row in tasteRows) {
        final id = row['user_id'].toString();
        if (id == user.id) {
          public = row['is_public'] == true;
          continue;
        }
        if (row['is_public'] != true) continue;
        final rawTracks = row['top_tracks'];
        final otherKeys = <String>{};
        if (rawTracks is List) {
          for (final raw in rawTracks) {
            if (raw is Map) {
              final map = Map<String, dynamic>.from(raw);
              final key = map['key']?.toString() ?? _key(map['title']?.toString(), map['artist']?.toString());
              if (key != '|') otherKeys.add(key);
            }
          }
        }
        final union = <String>{...myKeys, ...otherKeys};
        final intersection = myKeys.intersection(otherKeys);
        final percent = union.isEmpty ? 0 : ((intersection.length / union.length) * 100).round();
        matches.add({
          'user_id': id,
          'percent': percent,
          'common': intersection.length,
          'profile': profiles[id],
        });
      }
      matches.sort((a, b) => (b['percent'] as int).compareTo(a['percent'] as int));

      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _tastePublic = public;
        _matches = matches;
        _playlists = (values[2] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _sessions = (values[3] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Sosyal müzik alanı yüklenemedi: $error');
    }
  }

  Future<void> _setTastePublic(bool value) async {
    final user = _user;
    if (user == null) return;
    try {
      final tracks = await _myTasteRows();
      await _supabase.from('music_taste_profiles').upsert(
        {
          'user_id': user.id,
          'top_tracks': tracks,
          'is_public': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id',
      );
      if (mounted) setState(() => _tastePublic = value);
      await _load();
    } catch (error) {
      _message('Müzik uyumu ayarı kaydedilemedi: $error');
    }
  }

  Future<void> _createPlaylist() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ortak playlist oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Liste adı'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: description,
              maxLength: 180,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Açıklama'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (create == true && name.text.trim().isNotEmpty && _user != null) {
      try {
        final row = await _supabase
            .from('shared_playlists')
            .insert({
              'owner_id': _user!.id,
              'name': name.text.trim(),
              'description': description.text.trim().isEmpty ? null : description.text.trim(),
              'is_public': true,
            })
            .select('id')
            .single();
        await _supabase.from('shared_playlist_members').insert({
          'playlist_id': row['id'],
          'user_id': _user!.id,
          'role': 'owner',
        });
        await _load();
      } catch (error) {
        _message('Ortak playlist oluşturulamadı: $error');
      }
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _joinPlaylist(Map<String, dynamic> playlist) async {
    final user = _user;
    if (user == null) return;
    try {
      await _supabase.from('shared_playlist_members').upsert(
        {
          'playlist_id': playlist['id'],
          'user_id': user.id,
          'role': playlist['owner_id']?.toString() == user.id ? 'owner' : 'member',
        },
        onConflict: 'playlist_id,user_id',
      );
      _message('Listeye katıldın.');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SharedPlaylistPage(playlist: playlist),
        ),
      );
      await _load();
    } catch (error) {
      _message('Listeye katılınamadı: $error');
    }
  }

  MediaItem? get _currentItem {
    final tag = _music.player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  Future<void> _startListeningSession() async {
    final user = _user;
    final item = _currentItem;
    if (user == null) return;
    if (item == null) {
      _message('Birlikte Dinle başlatmak için önce bir şarkı çal.');
      return;
    }

    try {
      if (_hostedSessionId != null) {
        await _supabase
            .from('listening_sessions')
            .update({'is_active': false})
            .eq('id', _hostedSessionId!);
      }
      final row = await _supabase
          .from('listening_sessions')
          .insert({
            'host_id': user.id,
            'title': item.title,
            'artist': item.artist,
            'album': item.album,
            'track_key': _key(item.title, item.artist),
            'position_ms': _music.player.position.inMilliseconds,
            'is_playing': _music.player.playing,
            'is_active': true,
          })
          .select('id')
          .single();
      _hostedSessionId = row['id'].toString();
      await _supabase.from('listening_session_members').upsert(
        {'session_id': _hostedSessionId, 'user_id': user.id},
        onConflict: 'session_id,user_id',
      );
      _hostTimer?.cancel();
      _hostTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        unawaited(_publishHostState());
      });
      await _publishHostState();
      await _load();
      _message('Birlikte Dinle başladı.');
    } catch (error) {
      _message('Birlikte Dinle başlatılamadı: $error');
    }
  }

  Future<void> _publishHostState() async {
    final sessionId = _hostedSessionId;
    final item = _currentItem;
    if (sessionId == null || item == null) return;
    try {
      await _supabase.from('listening_sessions').update({
        'title': item.title,
        'artist': item.artist,
        'album': item.album,
        'track_key': _key(item.title, item.artist),
        'position_ms': _music.player.position.inMilliseconds,
        'is_playing': _music.player.playing,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
    } catch (_) {}
  }

  Future<void> _stopListeningSession() async {
    final sessionId = _hostedSessionId;
    _hostTimer?.cancel();
    _hostTimer = null;
    _hostedSessionId = null;
    if (sessionId != null) {
      await _supabase
          .from('listening_sessions')
          .update({'is_active': false})
          .eq('id', sessionId);
    }
    await _load();
  }

  SongModel? _findLocalSong(Map<String, dynamic> session) {
    final target = session['track_key']?.toString() ??
        _key(session['title']?.toString(), session['artist']?.toString());
    for (final song in _music.songs) {
      if (_key(song.title, song.artist) == target) return song;
    }
    return null;
  }

  Future<void> _joinSession(Map<String, dynamic> session) async {
    final user = _user;
    if (user == null) return;
    try {
      if (_music.songs.isEmpty) {
        await _music.requestPermissionAndLoad(request: true);
      }
      final match = _findLocalSong(session);
      if (match == null) {
        _message('Bu oturumdaki şarkı telefonunda bulunamadı. Oturuma katılabilirsin ancak senkron çalma için aynı şarkı gerekli.');
      } else {
        await _music.playSong(match);
        await _music.seek(
          Duration(milliseconds: int.tryParse(session['position_ms'].toString()) ?? 0),
        );
        if (session['is_playing'] != true) await _music.pause();
      }

      final sessionId = session['id'].toString();
      await _supabase.from('listening_session_members').upsert(
        {'session_id': sessionId, 'user_id': user.id},
        onConflict: 'session_id,user_id',
      );
      await _joinedSessionSub?.cancel();
      _joinedSessionId = sessionId;
      _joinedSessionSub = _supabase
          .from('listening_sessions')
          .stream(primaryKey: ['id'])
          .eq('id', sessionId)
          .listen((rows) {
        if (rows.isNotEmpty) unawaited(_syncToHost(rows.first));
      });
      if (mounted) setState(() {});
      _message('Birlikte Dinle oturumuna katıldın.');
    } catch (error) {
      _message('Oturuma katılınamadı: $error');
    }
  }

  Future<void> _syncToHost(Map<String, dynamic> session) async {
    if (session['is_active'] != true) {
      await _leaveJoinedSession();
      return;
    }
    final match = _findLocalSong(session);
    if (match == null) return;
    final current = _currentItem;
    if (_key(current?.title, current?.artist) != session['track_key']?.toString()) {
      await _music.playSong(match);
    }
    final target = int.tryParse(session['position_ms'].toString()) ?? 0;
    if ((_music.player.position.inMilliseconds - target).abs() > 1800) {
      await _music.seek(Duration(milliseconds: target));
    }
    if (session['is_playing'] == true && !_music.player.playing) {
      await _music.togglePlayPause();
    } else if (session['is_playing'] != true && _music.player.playing) {
      await _music.pause();
    }
  }

  Future<void> _leaveJoinedSession() async {
    final id = _joinedSessionId;
    await _joinedSessionSub?.cancel();
    _joinedSessionSub = null;
    _joinedSessionId = null;
    if (id != null && _user != null) {
      try {
        await _supabase
            .from('listening_session_members')
            .delete()
            .eq('session_id', id)
            .eq('user_id', _user!.id);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  String _profileName(String? id) {
    final profile = _profiles[id];
    if (profile == null) return 'Kullanıcı';
    final display = profile['display_name']?.toString().trim() ?? '';
    return display.isNotEmpty ? display : profile['username']?.toString() ?? 'Kullanıcı';
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.gold,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                  children: [
                    const Text(
                      'Birlikte',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Müzik uyumu • Ortak playlist • Birlikte Dinle',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                    const SizedBox(height: 18),
                    _tasteCard(),
                    const SizedBox(height: 22),
                    _sectionHeader('Müzik Uyumu', Icons.favorite_rounded),
                    const SizedBox(height: 8),
                    if (!_tastePublic)
                      _empty('Uyum yüzdesini görmek için müzik zevkini paylaşmayı aç.')
                    else if (_matches.isEmpty)
                      _empty('Henüz müzik zevkini paylaşan başka kullanıcı yok.')
                    else
                      ..._matches.take(8).map(_matchTile),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: _sectionHeader('Ortak Playlistler', Icons.playlist_add_rounded)),
                        IconButton(
                          onPressed: _createPlaylist,
                          tooltip: 'Playlist oluştur',
                          icon: const Icon(Icons.add_circle_rounded, color: AppColors.gold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_playlists.isEmpty)
                      _empty('İlk ortak playlisti sen oluştur.')
                    else
                      ..._playlists.take(12).map(_playlistTile),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: _sectionHeader('Birlikte Dinle', Icons.headphones_rounded)),
                        if (_hostedSessionId == null)
                          IconButton(
                            tooltip: 'Oturum başlat',
                            onPressed: _startListeningSession,
                            icon: const Icon(Icons.add_circle_rounded, color: AppColors.gold),
                          )
                        else
                          IconButton(
                            tooltip: 'Oturumu bitir',
                            onPressed: _stopListeningSession,
                            icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_sessions.isEmpty)
                      _empty('Aktif Birlikte Dinle oturumu yok.')
                    else
                      ..._sessions.take(10).map(_sessionTile),
                    if (_joinedSessionId != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _leaveJoinedSession,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Dinleme oturumundan ayrıl'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tasteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _tastePublic,
        activeThumbColor: AppColors.gold,
        title: const Text('Müzik uyumumu göster', style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: const Text(
          'Açarsan en çok dinlediğin şarkıların adları diğer kullanıcılara uyum hesabı için görünür. İstediğin zaman kapatabilirsin.',
          style: TextStyle(fontSize: 10),
        ),
        onChanged: _setTastePublic,
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.gold),
        const SizedBox(width: 7),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _matchTile(Map<String, dynamic> match) {
    final percent = match['percent'] as int? ?? 0;
    final name = _profileName(match['user_id']?.toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.gold.withValues(alpha: 0.12),
          child: Text('$percent%', style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${match['common'] ?? 0} ortak favori/dinleme izi'),
        trailing: Icon(
          percent >= 60 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: percent >= 60 ? AppColors.gold : Colors.white38,
        ),
      ),
    );
  }

  Widget _playlistTile(Map<String, dynamic> playlist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.queue_music_rounded, color: AppColors.gold),
        title: Text(playlist['name']?.toString() ?? 'Ortak Playlist', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          '${_profileName(playlist['owner_id']?.toString())} • ${playlist['description']?.toString() ?? 'Birlikte şarkı ekleyin'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _joinPlaylist(playlist),
      ),
    );
  }

  Widget _sessionTile(Map<String, dynamic> session) {
    final mine = session['host_id']?.toString() == _user?.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          session['is_playing'] == true ? Icons.graphic_eq_rounded : Icons.pause_circle_rounded,
          color: AppColors.gold,
        ),
        title: Text(
          session['title']?.toString() ?? 'Müzik',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${_profileName(session['host_id']?.toString())} • ${session['artist']?.toString() ?? 'Bilinmeyen sanatçı'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: mine
            ? const Chip(label: Text('SEN'))
            : FilledButton.tonal(
                onPressed: () => _joinSession(session),
                child: Text(_joinedSessionId == session['id']?.toString() ? 'Bağlı' : 'Katıl'),
              ),
      ),
    );
  }

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    );
  }
}

class SharedPlaylistPage extends StatefulWidget {
  const SharedPlaylistPage({super.key, required this.playlist});

  final Map<String, dynamic> playlist;

  @override
  State<SharedPlaylistPage> createState() => _SharedPlaylistPageState();
}

class _SharedPlaylistPageState extends State<SharedPlaylistPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalMusicService _music = LocalMusicService.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _tracks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _supabase
          .from('shared_playlist_tracks')
          .select('id, playlist_id, added_by, title, artist, album, source_ref, art_url, sort_order, created_at')
          .eq('playlist_id', widget.playlist['id'])
          .order('sort_order')
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _tracks = rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _message('Playlist yüklenemedi: $error');
      }
    }
  }

  MediaItem? get _currentItem {
    final tag = _music.player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag : null;
  }

  Future<void> _addCurrent() async {
    final user = _supabase.auth.currentUser;
    final item = _currentItem;
    if (user == null || item == null) {
      _message('Önce bir şarkı çal.');
      return;
    }
    try {
      await _supabase.from('shared_playlist_tracks').insert({
        'playlist_id': widget.playlist['id'],
        'added_by': user.id,
        'title': item.title,
        'artist': item.artist,
        'album': item.album,
        'source_ref': item.id,
        'art_url': item.artUri?.toString(),
        'sort_order': _tracks.length,
      });
      await _load();
    } catch (error) {
      _message('Şarkı eklenemedi: $error');
    }
  }

  Future<void> _remove(Map<String, dynamic> track) async {
    try {
      await _supabase.from('shared_playlist_tracks').delete().eq('id', track['id']);
      await _load();
    } catch (_) {
      _message('Bu parçayı kaldırma yetkin yok.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist['name']?.toString() ?? 'Ortak Playlist'),
        actions: [
          IconButton(
            onPressed: _addCurrent,
            tooltip: 'Çalan şarkıyı ekle',
            icon: const Icon(Icons.playlist_add_rounded, color: AppColors.gold),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _tracks.isEmpty
              ? const Center(child: Text('Henüz şarkı eklenmedi.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
                  itemCount: _tracks.length,
                  itemBuilder: (context, index) {
                    final item = _tracks[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                        child: Text('${index + 1}', style: const TextStyle(color: AppColors.gold)),
                      ),
                      title: Text(item['title']?.toString() ?? 'Müzik', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item['artist']?.toString() ?? 'Bilinmeyen sanatçı'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'remove') _remove(item);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'remove', child: Text('Listeden kaldır')),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
