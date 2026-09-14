import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';
import 'download_center_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with WidgetsBindingObserver {
  final LocalMusicService _music = LocalMusicService.instance;

  bool _loading = true;
  bool _permission = false;
  int _tab = 0;
  _LibraryMode _mode = _LibraryMode.all;
  String? _playlist;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _music.addListener(_changed);
    _load(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _music.removeListener(_changed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(false);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load(bool request) async {
    if (mounted) setState(() => _loading = true);
    final granted = await _music.requestPermissionAndLoad(request: request);
    if (!mounted) return;
    setState(() {
      _permission = granted;
      _loading = false;
    });
  }

  List<SongModel> get _songs {
    if (_playlist != null) return _music.playlistSongs(_playlist!);
    if (_mode == _LibraryMode.favorites) return _music.favoriteSongs;
    return _music.songs;
  }

  String _artist(SongModel song) {
    final value = song.artist?.trim();
    return value == null || value.isEmpty || value == '<unknown>'
        ? 'Bilinmeyen sanatçı'
        : value;
  }

  String _album(SongModel song) {
    final value = song.album?.trim();
    return value == null || value.isEmpty || value == '<unknown>' ? 'B_music02' : value;
  }

  Future<void> _openDownloads() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DownloadCenterScreen(showDownloadsFirst: true),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _newPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni çalma listesi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Liste adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await _music.createPlaylist(name);
      if (mounted) {
        setState(() {
          _playlist = name.trim();
          _mode = _LibraryMode.playlist;
        });
      }
    } catch (_) {}
  }

  Future<void> _songMenu(SongModel song) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(
                _music.isFavorite(song) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              ),
              title: Text(_music.isFavorite(song) ? 'Favorilerden çıkar' : 'Favorilere ekle'),
              onTap: () => Navigator.pop(c, 'favorite'),
            ),
            for (final name in _music.playlists.keys)
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text('$name listesine ekle'),
                onTap: () => Navigator.pop(c, 'playlist:$name'),
              ),
          ],
        ),
      ),
    );
    if (result == 'favorite') {
      await _music.toggleFavorite(song);
    }
    if (result?.startsWith('playlist:') == true) {
      await _music.addToPlaylist(result!.substring('playlist:'.length), song);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.neonPurple))
            : !_permission
                ? _permissionView()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
                    children: [
                      _topBar(),
                      const SizedBox(height: 12),
                      _tabs(),
                      const SizedBox(height: 14),
                      if (_tab == 0) _playlistTab(),
                      if (_tab == 1) _artistTab(),
                      if (_tab == 2) _albumTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Expanded(
          child: Text('Kitaplığım', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        ),
        IconButton(onPressed: () => _load(false), icon: const Icon(Icons.filter_list_rounded)),
        IconButton(onPressed: _newPlaylist, icon: const Icon(Icons.more_horiz_rounded)),
      ],
    );
  }

  Widget _tabs() {
    const labels = ['Çalma Listeleri', 'Sanatçılar', 'Albümler'];
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF151724),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.neonPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _playlistTab() {
    return Column(
      children: [
        _LibraryHero(
          title: 'Çalma Listelerim',
          subtitle: '${_music.playlists.length} oynatma listesi',
          icon: Icons.folder_copy_rounded,
          colors: const [Color(0xFF8D24E8), Color(0xFF3214AC)],
          onTap: () => setState(() {
            _playlist = null;
            _mode = _LibraryMode.playlist;
          }),
        ),
        const SizedBox(height: 10),
        _LibraryHero(
          title: 'İndirilenler',
          subtitle: 'Çevrimdışı dinlediğin müzikler',
          icon: Icons.download_done_rounded,
          colors: const [Color(0xFF6C2BFF), Color(0xFF203C9D)],
          onTap: _openDownloads,
        ),
        const SizedBox(height: 10),
        _LibraryHero(
          title: 'Tüm Şarkılar',
          subtitle: '${_music.songs.length} şarkı',
          icon: Icons.library_music_rounded,
          colors: const [Color(0xFF2477EE), Color(0xFF123AAB)],
          onTap: () => setState(() {
            _playlist = null;
            _mode = _LibraryMode.all;
          }),
        ),
        const SizedBox(height: 10),
        _LibraryHero(
          title: 'Beğenilen Şarkılar',
          subtitle: '${_music.favoriteSongs.length} şarkı',
          icon: Icons.favorite_rounded,
          colors: const [Color(0xFFB729A5), Color(0xFFE83F92)],
          onTap: () => setState(() {
            _playlist = null;
            _mode = _LibraryMode.favorites;
          }),
        ),
        const SizedBox(height: 12),
        if (_mode == _LibraryMode.playlist && _playlist == null)
          _playlistNames()
        else
          _songList(_songs),
      ],
    );
  }

  Widget _playlistNames() {
    if (_music.playlists.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.neonPurple),
        title: const Text('İlk çalma listeni oluştur'),
        onTap: _newPlaylist,
      );
    }
    return Column(
      children: _music.playlists.keys.map((name) {
        final songs = _music.playlistSongs(name);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C2BFF), Color(0xFFFF4BB8)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.queue_music_rounded, color: Colors.white),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${songs.length} şarkı', style: const TextStyle(color: AppColors.textSecondary)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => setState(() => _playlist = name),
        );
      }).toList(),
    );
  }

  Widget _artistTab() {
    final groups = <String, List<SongModel>>{};
    for (final song in _music.songs) {
      groups.putIfAbsent(_artist(song), () => <SongModel>[]).add(song);
    }
    final entries = groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      children: entries.map((entry) {
        final song = entry.value.first;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 3),
          leading: ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                nullArtworkWidget: _artFallback(),
                artworkBorder: BorderRadius.zero,
              ),
            ),
          ),
          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${entry.value.length} şarkı', style: const TextStyle(color: AppColors.textSecondary)),
          onTap: () => _music.playSong(song, from: entry.value),
        );
      }).toList(),
    );
  }

  Widget _albumTab() {
    final groups = <String, List<SongModel>>{};
    for (final song in _music.songs) {
      groups.putIfAbsent(_album(song), () => <SongModel>[]).add(song);
    }
    final entries = groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      children: entries.map((entry) {
        final song = entry.value.first;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 3),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 48,
              height: 48,
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                nullArtworkWidget: _artFallback(),
                artworkBorder: BorderRadius.zero,
              ),
            ),
          ),
          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${entry.value.length} şarkı', style: const TextStyle(color: AppColors.textSecondary)),
          onTap: () => _music.playSong(song, from: entry.value),
        );
      }).toList(),
    );
  }

  Widget _songList(List<SongModel> songs) {
    return Column(
      children: songs.map((song) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          onTap: () => _music.playSong(song, from: songs),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 46,
              height: 46,
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                nullArtworkWidget: _artFallback(),
                artworkBorder: BorderRadius.zero,
              ),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _artist(song),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          trailing: IconButton(
            onPressed: () => _songMenu(song),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        );
      }).toList(),
    );
  }

  Widget _permissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music_rounded, color: AppColors.neonPurple, size: 58),
            const SizedBox(height: 14),
            const Text('Müziklerine erişim gerekli', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            const Text(
              'Kitaplığını gösterebilmek için cihazdaki ses dosyalarına erişim izni ver.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => _load(true), child: const Text('İzin Ver')),
          ],
        ),
      ),
    );
  }

  static Widget _artFallback() {
    return Container(
      color: const Color(0xFF21183F),
      child: const Icon(Icons.music_note_rounded, color: AppColors.neonPurple),
    );
  }
}

enum _LibraryMode { all, favorites, playlist }

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 100,
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                  const SizedBox(height: 7),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
            Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 46),
          ],
        ),
      ),
    );
  }
}
