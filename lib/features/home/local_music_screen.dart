import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';

class LocalMusicScreen extends StatefulWidget {
  const LocalMusicScreen({
    super.key,
  });

  @override
  State<LocalMusicScreen> createState() =>
      _LocalMusicScreenState();
}

class _LocalMusicScreenState
    extends State<LocalMusicScreen> {
  final LocalMusicService _music =
      LocalMusicService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;
  bool _permissionGranted = false;
  bool _favoritesOnly = false;

  String? _error;
  String _searchText = '';

  @override
  void initState() {
    super.initState();

    _loadMusic();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadMusic() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final permission =
          await _music.requestPermissionAndLoad();

      if (!mounted) return;

      setState(() {
        _permissionGranted = permission;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    try {
      await _music.refresh();

      if (!mounted) return;

      setState(() {});
    } catch (e) {
      _showMessage(
        'Müzikler yenilenemedi: $e',
      );
    }
  }

  List<SongModel> get _filteredSongs {
    Iterable<SongModel> result =
        _favoritesOnly
            ? _music.favoriteSongs
            : _music.songs;

    final text =
        _searchText.trim().toLowerCase();

    if (text.isEmpty) {
      return result.toList();
    }

    return result.where(
      (song) {
        final title =
            song.title.toLowerCase();

        final artist =
            (song.artist ?? '')
                .toLowerCase();

        final album =
            (song.album ?? '')
                .toLowerCase();

        return title.contains(text) ||
            artist.contains(text) ||
            album.contains(text);
      },
    ).toList();
  }

  String _artistName(
    SongModel song,
  ) {
    final artist =
        song.artist?.trim();

    if (artist == null ||
        artist.isEmpty ||
        artist == '<unknown>') {
      return 'Bilinmeyen sanatçı';
    }

    return artist;
  }

  String _albumName(
    SongModel song,
  ) {
    final album =
        song.album?.trim();

    if (album == null ||
        album.isEmpty ||
        album == '<unknown>') {
      return 'B_music02';
    }

    return album;
  }

  String _durationText(
    int? milliseconds,
  ) {
    if (milliseconds == null ||
        milliseconds <= 0) {
      return '--:--';
    }

    final duration =
        Duration(
      milliseconds:
          milliseconds,
    );

    final minutes =
        duration.inMinutes;

    final seconds =
        duration.inSeconds
            .remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  Future<void> _play(
    SongModel song,
  ) async {
    try {
      await _music.playSong(
        song,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showMessage(
        'Müzik açılamadı: $e',
      );
    }
  }

  Future<void> _toggleFavorite(
    SongModel song,
  ) async {
    final isFavorite =
        await _music.toggleFavorite(
      song,
    );

    if (!mounted) return;

    setState(() {});

    _showMessage(
      isFavorite
          ? 'Favorilere eklendi'
          : 'Favorilerden çıkarıldı',
    );
  }

  void _openPlayer() {
    final index =
        _music.player.currentIndex;

    if (index == null ||
        index < 0 ||
        index >= _music.songs.length) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (
        context,
      ) {
        return const _FullLocalPlayer();
      },
    ).then(
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFF080808,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),

            if (_loading)
              const Expanded(
                child: Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        AppColors.gold,
                  ),
                ),
              )
            else if (_error != null)
              Expanded(
                child:
                    _buildError(),
              )
            else if (!_permissionGranted)
              Expanded(
                child:
                    _buildPermission(),
              )
            else ...[
              _buildSearch(),

              _buildFilters(),

              _buildInfo(),

              Expanded(
                child:
                    _buildSongList(),
              ),

              _buildMiniPlayer(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        16,
        18,
        8,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding:
                const EdgeInsets.all(
              2,
            ),
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              border:
                  Border.all(
                color:
                    AppColors.gold,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/b_music02_logo.png',
                fit:
                    BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Müziklerim',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 23,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(
                  height: 2,
                ),
                Text(
                  'TELEFONUNDAKİ MÜZİKLER',
                  style:
                      TextStyle(
                    color:
                        AppColors.gold,
                    fontSize: 8,
                    letterSpacing:
                        1.5,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed:
                _refresh,
            icon:
                const Icon(
              Icons.refresh_rounded,
              color:
                  AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        10,
        18,
        10,
      ),
      child: Container(
        height: 55,
        decoration:
            BoxDecoration(
          color:
              const Color(
            0xFF151515,
          ),
          borderRadius:
              BorderRadius.circular(
            21,
          ),
          border:
              Border.all(
            color:
                AppColors.gold
                    .withOpacity(
              0.30,
            ),
          ),
        ),
        child: TextField(
          controller:
              _searchController,
          onChanged:
              (value) {
            setState(() {
              _searchText = value;
            });
          },
          style:
              const TextStyle(
            color:
                Colors.white,
          ),
          decoration:
              InputDecoration(
            border:
                InputBorder.none,
            hintText:
                'Müzik, sanatçı veya albüm ara...',
            hintStyle:
                const TextStyle(
              color:
                  Colors.white38,
              fontSize: 12,
            ),
            prefixIcon:
                const Icon(
              Icons.search_rounded,
              color:
                  Colors.white54,
            ),
            suffixIcon:
                _searchText.isEmpty
                    ? null
                    : IconButton(
                        onPressed:
                            () {
                          _searchController
                              .clear();

                          setState(() {
                            _searchText =
                                '';
                          });
                        },
                        icon:
                            const Icon(
                          Icons
                              .close_rounded,
                          color:
                              Colors.white38,
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 49,
      child: ListView(
        scrollDirection:
            Axis.horizontal,
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 18,
        ),
        children: [
          _FilterButton(
            icon:
                Icons.library_music_rounded,
            label:
                'Tüm Müzikler',
            selected:
                !_favoritesOnly,
            onTap:
                () {
              setState(() {
                _favoritesOnly =
                    false;
              });
            },
          ),

          const SizedBox(
            width: 9,
          ),

          _FilterButton(
            icon:
                Icons.favorite_rounded,
            label:
                'Favoriler',
            selected:
                _favoritesOnly,
            onTap:
                () {
              setState(() {
                _favoritesOnly =
                    true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        20,
        9,
        20,
        10,
      ),
      child: Row(
        children: [
          Icon(
            _favoritesOnly
                ? Icons.favorite_rounded
                : Icons
                    .library_music_rounded,
            size: 16,
            color:
                AppColors.gold,
          ),

          const SizedBox(
            width: 7,
          ),

          Text(
            '${_filteredSongs.length} müzik',
            style:
                const TextStyle(
              color:
                  Colors.white54,
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const Spacer(),

          if (_favoritesOnly)
            const Text(
              'FAVORİLER',
              style:
                  TextStyle(
                color:
                    AppColors.gold,
                fontSize: 8,
                letterSpacing:
                    1.2,
              ),
            )
          else
            const Text(
              'CİHAZ',
              style:
                  TextStyle(
                color:
                    Colors.white24,
                fontSize: 8,
                letterSpacing:
                    1.2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSongList() {
    final songs =
        _filteredSongs;

    if (songs.isEmpty) {
      return RefreshIndicator(
        color:
            AppColors.gold,
        backgroundColor:
            const Color(
          0xFF151515,
        ),
        onRefresh:
            _refresh,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(
              height: 110,
            ),

            Icon(
              _favoritesOnly
                  ? Icons
                      .favorite_border_rounded
                  : Icons
                      .music_off_rounded,
              size: 60,
              color:
                  Colors.white24,
            ),

            const SizedBox(
              height: 14,
            ),

            Center(
              child: Text(
                _favoritesOnly
                    ? 'Henüz favori müzik yok.'
                    : 'Telefonda müzik bulunamadı.',
                style:
                    const TextStyle(
                  color:
                      Colors.white54,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color:
          AppColors.gold,
      backgroundColor:
          const Color(
        0xFF151515,
      ),
      onRefresh:
          _refresh,
      child: ListView.separated(
        padding:
            const EdgeInsets
                .fromLTRB(
          13,
          0,
          13,
          105,
        ),
        itemCount:
            songs.length,
        separatorBuilder:
            (
          context,
          index,
        ) {
          return const Divider(
            height: 1,
            indent: 78,
            endIndent: 10,
            color:
                Colors.white10,
          );
        },
        itemBuilder:
            (
          context,
          index,
        ) {
          final song =
              songs[index];

          return StreamBuilder<int?>(
            stream:
                _music.player
                    .currentIndexStream,
            builder: (
              context,
              snapshot,
            ) {
              final playingIndex =
                  snapshot.data;

              SongModel? currentSong;

              if (playingIndex != null &&
                  playingIndex >= 0 &&
                  playingIndex <
                      _music.songs.length) {
                currentSong =
                    _music.songs[
                        playingIndex];
              }

              final selected =
                  currentSong?.id ==
                      song.id;

              final favorite =
                  _music.isFavorite(
                song,
              );

              return ListTile(
                onTap:
                    () {
                  _play(
                    song,
                  );
                },
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                leading:
                    QueryArtworkWidget(
                  id:
                      song.id,
                  type:
                      ArtworkType.AUDIO,
                  controller:
                      _music.audioQuery,
                  artworkWidth:
                      56,
                  artworkHeight:
                      56,
                  artworkFit:
                      BoxFit.cover,
                  artworkBorder:
                      BorderRadius.circular(
                    14,
                  ),
                  nullArtworkWidget:
                      Container(
                    width: 56,
                    height: 56,
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      gradient:
                          const LinearGradient(
                        colors: [
                          Color(
                            0xFF33250F,
                          ),
                          Color(
                            0xFF151515,
                          ),
                        ],
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .music_note_rounded,
                      color:
                          AppColors.gold,
                    ),
                  ),
                ),
                title:
                    Text(
                  song.title,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    color:
                        selected
                            ? AppColors.gold
                            : Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                subtitle:
                    Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    top: 4,
                  ),
                  child:
                      Text(
                    '${_artistName(song)} • ${_albumName(song)}',
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                ),
                trailing:
                    SizedBox(
                  width: 75,
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      IconButton(
                        padding:
                            EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(
                          minWidth: 35,
                          minHeight: 35,
                        ),
                        onPressed:
                            () {
                          _toggleFavorite(
                            song,
                          );
                        },
                        icon:
                            Icon(
                          favorite
                              ? Icons
                                  .favorite_rounded
                              : Icons
                                  .favorite_border_rounded,
                          color:
                              favorite
                                  ? AppColors.gold
                                  : Colors.white24,
                          size: 19,
                        ),
                      ),

                      if (selected)
                        StreamBuilder<bool>(
                          stream:
                              _music.player
                                  .playingStream,
                          builder:
                              (
                            context,
                            snapshot,
                          ) {
                            final playing =
                                snapshot.data ??
                                    false;

                            return Icon(
                              playing
                                  ? Icons
                                      .graphic_eq_rounded
                                  : Icons
                                      .pause_circle_outline_rounded,
                              color:
                                  AppColors.gold,
                              size: 20,
                            );
                          },
                        )
                      else
                        Text(
                          _durationText(
                            song.duration,
                          ),
                          style:
                              const TextStyle(
                            color:
                                Colors.white24,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<int?>(
      stream:
          _music.player
              .currentIndexStream,
      builder: (
        context,
        indexSnapshot,
      ) {
        final index =
            indexSnapshot.data;

        if (index == null ||
            index < 0 ||
            index >=
                _music.songs.length) {
          return const SizedBox
              .shrink();
        }

        final song =
            _music.songs[index];

        return GestureDetector(
          onTap:
              _openPlayer,
          child: Container(
            margin:
                const EdgeInsets
                    .fromLTRB(
              12,
              0,
              12,
              8,
            ),
            padding:
                const EdgeInsets
                    .all(
              9,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF171717,
              ),
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
              border:
                  Border.all(
                color:
                    AppColors.gold
                        .withOpacity(
                  0.35,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black
                          .withOpacity(
                    0.45,
                  ),
                  blurRadius:
                      18,
                ),
              ],
            ),
            child: Row(
              children: [
                QueryArtworkWidget(
                  id:
                      song.id,
                  type:
                      ArtworkType.AUDIO,
                  controller:
                      _music.audioQuery,
                  artworkWidth:
                      48,
                  artworkHeight:
                      48,
                  artworkFit:
                      BoxFit.cover,
                  artworkBorder:
                      BorderRadius.circular(
                    13,
                  ),
                  nullArtworkWidget:
                      Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                      color:
                          const Color(
                        0xFF292011,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .music_note_rounded,
                      color:
                          AppColors.gold,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 11,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        _artistName(
                          song,
                        ),
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white38,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),

                StreamBuilder<bool>(
                  stream:
                      _music.player
                          .playingStream,
                  builder: (
                    context,
                    snapshot,
                  ) {
                    final playing =
                        snapshot.data ??
                            false;

                    return GestureDetector(
                      onTap:
                          _music
                              .togglePlayPause,
                      child: Container(
                        width: 43,
                        height: 43,
                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color:
                              AppColors.gold,
                        ),
                        child:
                            Icon(
                          playing
                              ? Icons
                                  .pause_rounded
                              : Icons
                                  .play_arrow_rounded,
                          color:
                              Colors.black,
                          size: 29,
                        ),
                      ),
                    );
                  },
                ),

                IconButton(
                  onPressed:
                      _music.next,
                  icon:
                      const Icon(
                    Icons
                        .skip_next_rounded,
                    color:
                        Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermission() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 95,
              height: 95,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    AppColors.gold
                        .withOpacity(
                  0.10,
                ),
                border:
                    Border.all(
                  color:
                      AppColors.gold
                          .withOpacity(
                    0.40,
                  ),
                ),
              ),
              child:
                  const Icon(
                Icons
                    .library_music_rounded,
                color:
                    AppColors.gold,
                size: 45,
              ),
            ),

            const SizedBox(
              height: 23,
            ),

            const Text(
              'Müziklerine Erişim',
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 22,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'B_music02 telefonundaki müzikleri otomatik gösterebilmek için müzik ve ses dosyalarına erişim izni ister.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white54,
                fontSize: 11,
                height: 1.5,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            SizedBox(
              width:
                  double.infinity,
              height: 52,
              child:
                  FilledButton.icon(
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.gold,
                  foregroundColor:
                      Colors.black,
                ),
                onPressed:
                    _loadMusic,
                icon:
                    const Icon(
                  Icons
                      .verified_user_rounded,
                ),
                label:
                    const Text(
                  'Müzik Erişimine İzin Ver',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              size: 60,
              color:
                  Colors.white38,
            ),

            const SizedBox(
              height: 15,
            ),

            const Text(
              'Müzikler okunamadı',
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              _error ?? '',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white54,
                fontSize: 10,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            FilledButton(
              onPressed:
                  _loadMusic,
              child:
                  const Text(
                'Tekrar Dene',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton
    extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap:
          onTap,
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 17,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? AppColors.gold
                  : const Color(
                      0xFF151515,
                    ),
          borderRadius:
              BorderRadius.circular(
            25,
          ),
          border:
              Border.all(
            color:
                selected
                    ? AppColors.gold
                    : Colors.white12,
          ),
        ),
        child:
            Row(
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  selected
                      ? Colors.black
                      : Colors.white54,
            ),

            const SizedBox(
              width: 7,
            ),

            Text(
              label,
              style:
                  TextStyle(
                color:
                    selected
                        ? Colors.black
                        : Colors.white54,
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullLocalPlayer
    extends StatefulWidget {
  const _FullLocalPlayer();

  @override
  State<_FullLocalPlayer> createState() =>
      _FullLocalPlayerState();
}

class _FullLocalPlayerState
    extends State<_FullLocalPlayer> {
  final LocalMusicService _music =
      LocalMusicService.instance;

  String _artist(
    SongModel song,
  ) {
    final artist =
        song.artist?.trim();

    if (artist == null ||
        artist.isEmpty ||
        artist == '<unknown>') {
      return 'Bilinmeyen sanatçı';
    }

    return artist;
  }

  String _album(
    SongModel song,
  ) {
    final album =
        song.album?.trim();

    if (album == null ||
        album.isEmpty ||
        album == '<unknown>') {
      return 'B_music02';
    }

    return album;
  }

  String _time(
    Duration value,
  ) {
    final minutes =
        value.inMinutes;

    final seconds =
        value.inSeconds
            .remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleFavorite(
    SongModel song,
  ) async {
    await _music.toggleFavorite(
      song,
    );

    if (mounted) {
      setState(() {});
    }
  }

  IconData _repeatIcon(
    LoopMode mode,
  ) {
    if (mode ==
        LoopMode.one) {
      return Icons.repeat_one_rounded;
    }

    return Icons.repeat_rounded;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration:
          const BoxDecoration(
        color:
            Color(
          0xFF0D0D0D,
        ),
        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(
            34,
          ),
        ),
      ),
      child: StreamBuilder<int?>(
        stream:
            _music.player
                .currentIndexStream,
        builder: (
          context,
          snapshot,
        ) {
          final index =
              snapshot.data ??
                  _music.player
                      .currentIndex;

          if (index == null ||
              index < 0 ||
              index >=
                  _music.songs.length) {
            return const SizedBox(
              height: 300,
              child: Center(
                child:
                    CircularProgressIndicator(
                  color:
                      AppColors.gold,
                ),
              ),
            );
          }

          final song =
              _music.songs[index];

          final favorite =
              _music.isFavorite(
            song,
          );

          return SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                24,
                12,
                24,
                32,
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white12,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 27,
                  ),

                  QueryArtworkWidget(
                    id:
                        song.id,
                    type:
                        ArtworkType.AUDIO,
                    controller:
                        _music.audioQuery,
                    artworkWidth:
                        275,
                    artworkHeight:
                        275,
                    artworkFit:
                        BoxFit.cover,
                    artworkBorder:
                        BorderRadius.circular(
                      30,
                    ),
                    nullArtworkWidget:
                        Container(
                      width: 275,
                      height: 275,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          30,
                        ),
                        gradient:
                            const LinearGradient(
                          begin:
                              Alignment.topLeft,
                          end:
                              Alignment.bottomRight,
                          colors: [
                            Color(
                              0xFF3C2B10,
                            ),
                            Color(
                              0xFF101010,
                            ),
                          ],
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .music_note_rounded,
                        size: 100,
                        color:
                            AppColors.gold,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 21,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            Text(
                              _artist(
                                song,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    AppColors.gold,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              _album(
                                song,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white38,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed:
                            () {
                          _toggleFavorite(
                            song,
                          );
                        },
                        icon:
                            Icon(
                          favorite
                              ? Icons
                                  .favorite_rounded
                              : Icons
                                  .favorite_border_rounded,
                          color:
                              favorite
                                  ? AppColors.gold
                                  : Colors.white54,
                          size: 29,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 19,
                  ),

                  StreamBuilder<Duration?>(
                    stream:
                        _music.player
                            .durationStream,
                    builder: (
                      context,
                      durationSnapshot,
                    ) {
                      final duration =
                          durationSnapshot
                                  .data ??
                              Duration.zero;

                      return StreamBuilder<
                          Duration>(
                        stream:
                            _music.player
                                .positionStream,
                        builder: (
                          context,
                          positionSnapshot,
                        ) {
                          var position =
                              positionSnapshot
                                      .data ??
                                  Duration.zero;

                          if (position >
                              duration) {
                            position =
                                duration;
                          }

                          final max =
                              duration
                                          .inMilliseconds >
                                      0
                                  ? duration
                                      .inMilliseconds
                                      .toDouble()
                                  : 1.0;

                          final clamped =
                              position
                                  .inMilliseconds
                                  .toDouble()
                                  .clamp(
                                    0.0,
                                    max,
                                  );

                          final value =
                              clamped
                                  .toDouble();

                          return Column(
                            children: [
                              Slider(
                                min: 0.0,
                                max: max,
                                value:
                                    value,
                                activeColor:
                                    AppColors.gold,
                                inactiveColor:
                                    Colors.white12,
                                onChanged:
                                    (
                                  newValue,
                                ) {
                                  _music.seek(
                                    Duration(
                                      milliseconds:
                                          newValue
                                              .round(),
                                    ),
                                  );
                                },
                              ),

                              Padding(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text(
                                      _time(
                                        position,
                                      ),
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white38,
                                        fontSize:
                                            9,
                                      ),
                                    ),
                                    Text(
                                      _time(
                                        duration,
                                      ),
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white38,
                                        fontSize:
                                            9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(
                    height: 21,
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceAround,
                    children: [
                      StreamBuilder<bool>(
                        stream:
                            _music.player
                                .shuffleModeEnabledStream,
                        builder: (
                          context,
                          snapshot,
                        ) {
                          final enabled =
                              snapshot.data ??
                                  false;

                          return IconButton(
                            onPressed:
                                _music
                                    .toggleShuffle,
                            icon:
                                Icon(
                              Icons
                                  .shuffle_rounded,
                              color:
                                  enabled
                                      ? AppColors.gold
                                      : Colors.white38,
                              size: 25,
                            ),
                          );
                        },
                      ),

                      IconButton(
                        onPressed:
                            _music.previous,
                        icon:
                            const Icon(
                          Icons
                              .skip_previous_rounded,
                          color:
                              Colors.white,
                          size: 39,
                        ),
                      ),

                      StreamBuilder<bool>(
                        stream:
                            _music.player
                                .playingStream,
                        builder: (
                          context,
                          snapshot,
                        ) {
                          final playing =
                              snapshot.data ??
                                  false;

                          return GestureDetector(
                            onTap:
                                _music
                                    .togglePlayPause,
                            child: Container(
                              width: 73,
                              height: 73,
                              decoration:
                                  const BoxDecoration(
                                color:
                                    AppColors.gold,
                                shape:
                                    BoxShape.circle,
                              ),
                              child:
                                  Icon(
                                playing
                                    ? Icons
                                        .pause_rounded
                                    : Icons
                                        .play_arrow_rounded,
                                color:
                                    Colors.black,
                                size: 47,
                              ),
                            ),
                          );
                        },
                      ),

                      IconButton(
                        onPressed:
                            _music.next,
                        icon:
                            const Icon(
                          Icons
                              .skip_next_rounded,
                          color:
                              Colors.white,
                          size: 39,
                        ),
                      ),

                      StreamBuilder<LoopMode>(
                        stream:
                            _music.player
                                .loopModeStream,
                        builder: (
                          context,
                          snapshot,
                        ) {
                          final mode =
                              snapshot.data ??
                                  LoopMode.off;

                          return IconButton(
                            onPressed:
                                _music
                                    .cycleRepeatMode,
                            icon:
                                Icon(
                              _repeatIcon(
                                mode,
                              ),
                              color:
                                  mode ==
                                          LoopMode
                                              .off
                                      ? Colors.white38
                                      : AppColors.gold,
                              size: 25,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  StreamBuilder<LoopMode>(
                    stream:
                        _music.player
                            .loopModeStream,
                    builder: (
                      context,
                      snapshot,
                    ) {
                      final mode =
                          snapshot.data ??
                              LoopMode.off;

                      String text;

                      switch (mode) {
                        case LoopMode.off:
                          text =
                              'Tekrar kapalı';
                          break;

                        case LoopMode.all:
                          text =
                              'Tümünü tekrarla';
                          break;

                        case LoopMode.one:
                          text =
                              'Bu şarkıyı tekrarla';
                          break;
                      }

                      return Text(
                        text,
                        style:
                            const TextStyle(
                          color:
                              Colors.white24,
                          fontSize: 9,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
