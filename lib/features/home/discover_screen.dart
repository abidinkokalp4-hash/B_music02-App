import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/wikimedia_music_service.dart';
import '../../core/theme/app_theme.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
  });

  @override
  State<DiscoverScreen> createState() =>
      _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final WikimediaMusicService _service =
      const WikimediaMusicService();

  final AudioPlayer _player = AudioPlayer();

  final TextEditingController _searchController =
      TextEditingController();

  Timer? _searchTimer;

  StreamSubscription<PlayerState>? _playerSubscription;

  List<CommonsTrack> _tracks = [];
  List<DownloadedCommonsTrack> _downloads = [];

  final Set<int> _downloading = {};

  bool _loading = true;
  bool _playing = false;

  String? _error;

  int? _playingOnlineId;
  String? _playingLocalPath;

  String _selectedCategory = 'Tümü';

  static const List<String> _categories = [
    'Tümü',
    'Kürtçe',
    'Akustik',
    'Klasik',
    'Enstrümantal',
  ];

  @override
  void initState() {
    super.initState();

    _playerSubscription =
        _player.playerStateStream.listen(
      (state) {
        if (!mounted) return;

        setState(() {
          _playing = state.playing;
        });
      },
    );

    _loadDownloads();
    _search();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _playerSubscription?.cancel();
    _searchController.dispose();
    _player.dispose();

    super.dispose();
  }

  Future<void> _loadDownloads() async {
    final items = await _service.getDownloads();

    if (!mounted) return;

    setState(() {
      _downloads = items;
    });
  }

  String _buildSearchText() {
    final typed =
        _searchController.text.trim();

    String category = '';

    switch (_selectedCategory) {
      case 'Kürtçe':
        category = 'Kurdish music';
        break;

      case 'Akustik':
        category = 'acoustic music';
        break;

      case 'Klasik':
        category = 'classical music';
        break;

      case 'Enstrümantal':
        category = 'instrumental music';
        break;
    }

    if (typed.isNotEmpty &&
        category.isNotEmpty) {
      return '$typed $category';
    }

    if (typed.isNotEmpty) {
      return typed;
    }

    if (category.isNotEmpty) {
      return category;
    }

    return 'music';
  }

  Future<void> _search() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
          await _service.searchMusic(
        _buildSearchText(),
        limit: 30,
      );

      if (!mounted) return;

      setState(() {
        _tracks = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _tracks = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(
    String value,
  ) {
    setState(() {});

    _searchTimer?.cancel();

    _searchTimer = Timer(
      const Duration(
        milliseconds: 650,
      ),
      () {
        _search();
      },
    );
  }

  Future<void> _selectCategory(
    String category,
  ) async {
    setState(() {
      _selectedCategory = category;
    });

    await _search();
  }

  Future<void> _playOnline(
    CommonsTrack track,
  ) async {
    try {
      if (_playingOnlineId ==
              track.id &&
          _player.playing) {
        await _player.pause();
        return;
      }

      if (_playingOnlineId ==
              track.id &&
          !_player.playing) {
        unawaited(
          _player.play(),
        );
        return;
      }

      await _player.stop();

      await _player.setUrl(
        track.fileUrl,
      );

      if (!mounted) return;

      setState(() {
        _playingOnlineId = track.id;
        _playingLocalPath = null;
      });

      unawaited(
        _player.play(),
      );
    } catch (e) {
      _message(
        'Müzik oynatılamadı: $e',
      );
    }
  }

  Future<void> _playDownloaded(
    DownloadedCommonsTrack track,
  ) async {
    try {
      if (_playingLocalPath ==
              track.localPath &&
          _player.playing) {
        await _player.pause();
        return;
      }

      if (_playingLocalPath ==
              track.localPath &&
          !_player.playing) {
        unawaited(
          _player.play(),
        );
        return;
      }

      await _player.stop();

      await _player.setFilePath(
        track.localPath,
      );

      if (!mounted) return;

      setState(() {
        _playingLocalPath =
            track.localPath;

        _playingOnlineId = null;
      });

      unawaited(
        _player.play(),
      );
    } catch (e) {
      _message(
        'İndirilen müzik oynatılamadı: $e',
      );
    }
  }

  bool _isDownloaded(
    int id,
  ) {
    return _downloads.any(
      (item) => item.id == id,
    );
  }

  Future<void> _download(
    CommonsTrack track,
  ) async {
    if (!track.canDownload) {
      _showLicense(
        track,
        downloadBlocked: true,
      );
      return;
    }

    if (_downloading.contains(
      track.id,
    )) {
      return;
    }

    setState(() {
      _downloading.add(
        track.id,
      );
    });

    try {
      await _service.downloadTrack(
        track,
      );

      await _loadDownloads();

      if (!mounted) return;

      _message(
        '${track.title} indirildi. İnternet olmadan da dinleyebilirsiniz.',
      );
    } catch (e) {
      _message(
        'İndirme başarısız: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading.remove(
            track.id,
          );
        });
      }
    }
  }

  Future<void> _openUrl(
    String value,
  ) async {
    if (value.trim().isEmpty) {
      return;
    }

    final uri = Uri.tryParse(
      value,
    );

    if (uri == null) {
      return;
    }

    try {
      await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _showLicense(
    CommonsTrack track, {
    bool downloadBlocked = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled: true,
      builder: (
        sheetContext,
      ) {
        return SafeArea(
          child: Container(
            margin:
                const EdgeInsets.all(
              14,
            ),
            padding:
                const EdgeInsets.all(
              22,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF151515,
              ),
              borderRadius:
                  BorderRadius.circular(
                28,
              ),
              border:
                  Border.all(
                color:
                    AppColors.gold
                        .withOpacity(
                  0.25,
                ),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  downloadBlocked
                      ? Icons.lock_rounded
                      : Icons
                          .verified_rounded,
                  color:
                      downloadBlocked
                          ? Colors.white54
                          : AppColors.gold,
                  size: 42,
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  track.title,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  track.artist,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                  ),
                ),

                const SizedBox(
                  height: 17,
                ),

                _InfoRow(
                  title: 'Lisans',
                  value:
                      track.licenseName,
                ),

                if (track.credit
                    .isNotEmpty)
                  _InfoRow(
                    title: 'Atıf',
                    value:
                        track.credit,
                  ),

                if (downloadBlocked) ...[
                  const SizedBox(
                    height: 12,
                  ),
                  const Text(
                    'Bu parçayı otomatik indirmeye açmıyoruz. '
                    'Yalnızca uygun açık lisanslı parçalar indirilebilir.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                      height: 1.4,
                      fontSize: 11,
                    ),
                  ),
                ],

                const SizedBox(
                  height: 18,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed: () {
                          _openUrl(
                            track
                                .sourcePageUrl,
                          );
                        },
                        icon:
                            const Icon(
                          Icons
                              .open_in_new_rounded,
                        ),
                        label:
                            const Text(
                          'Kaynak',
                        ),
                      ),
                    ),

                    if (track
                        .licenseUrl
                        .isNotEmpty) ...[
                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                            FilledButton.icon(
                          style:
                              FilledButton
                                  .styleFrom(
                            backgroundColor:
                                AppColors.gold,
                            foregroundColor:
                                Colors.black,
                          ),
                          onPressed:
                              () {
                            _openUrl(
                              track
                                  .licenseUrl,
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .description_rounded,
                          ),
                          label:
                              const Text(
                            'Lisans',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDownloads() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled: true,
      builder: (
        sheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            modalSetState,
          ) {
            return SafeArea(
              child: Container(
                constraints:
                    BoxConstraints(
                  maxHeight:
                      MediaQuery.of(
                            context,
                          ).size.height *
                          0.78,
                ),
                margin:
                    const EdgeInsets.all(
                  12,
                ),
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF111111,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                  border:
                      Border.all(
                    color:
                        AppColors.gold
                            .withOpacity(
                      0.25,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .download_done_rounded,
                          color:
                              AppColors.gold,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        const Expanded(
                          child: Text(
                            'İndirilenler',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 21,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),

                        Text(
                          '${_downloads.length}',
                          style:
                              const TextStyle(
                            color:
                                AppColors.gold,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    if (_downloads
                        .isEmpty)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .music_off_rounded,
                                color:
                                    Colors.white24,
                                size: 50,
                              ),
                              SizedBox(
                                height: 12,
                              ),
                              Text(
                                'Henüz müzik indirmediniz.',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child:
                            ListView.separated(
                          itemCount:
                              _downloads
                                  .length,
                          separatorBuilder:
                              (
                            context,
                            index,
                          ) =>
                                  const Divider(
                            color:
                                Colors.white10,
                          ),
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final track =
                                _downloads[
                                    index];

                            final isPlaying =
                                _playingLocalPath ==
                                        track
                                            .localPath &&
                                    _playing;

                            return ListTile(
                              contentPadding:
                                  EdgeInsets.zero,
                              leading:
                                  GestureDetector(
                                onTap:
                                    () async {
                                  await _playDownloaded(
                                    track,
                                  );

                                  modalSetState(
                                    () {},
                                  );
                                },
                                child:
                                    Container(
                                  width: 48,
                                  height: 48,
                                  decoration:
                                      BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(
                                      14,
                                    ),
                                    color:
                                        AppColors.gold
                                            .withOpacity(
                                      0.10,
                                    ),
                                  ),
                                  child:
                                      Icon(
                                    isPlaying
                                        ? Icons
                                            .pause_rounded
                                        : Icons
                                            .play_arrow_rounded,
                                    color:
                                        AppColors.gold,
                                  ),
                                ),
                              ),
                              title:
                                  Text(
                                track.title,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                              ),
                              subtitle:
                                  Text(
                                '${track.artist}\n${track.licenseName}',
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                              trailing:
                                  IconButton(
                                onPressed:
                                    () async {
                                  if (_playingLocalPath ==
                                      track.localPath) {
                                    await _player
                                        .stop();

                                    if (mounted) {
                                      setState(
                                        () {
                                          _playingLocalPath =
                                              null;
                                        },
                                      );
                                    }
                                  }

                                  await _service
                                      .deleteDownload(
                                    track,
                                  );

                                  await _loadDownloads();

                                  modalSetState(
                                    () {},
                                  );
                                },
                                icon:
                                    const Icon(
                                  Icons
                                      .delete_outline_rounded,
                                  color:
                                      Colors.white38,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _message(
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
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor:
              const Color(
            0xFF151515,
          ),
          onRefresh: _search,
          child: CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(
              parent:
                  BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _header(),
              ),

              SliverToBoxAdapter(
                child: _searchArea(),
              ),

              SliverToBoxAdapter(
                child: _categoryBar(),
              ),

              SliverToBoxAdapter(
                child: _hero(),
              ),

              SliverToBoxAdapter(
                child:
                    _sectionTitle(),
              ),

              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 80,
                    ),
                    child: Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            AppColors.gold,
                      ),
                    ),
                  ),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: _errorBox(),
                )
              else if (_tracks.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 70,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons
                              .music_off_rounded,
                          color:
                              Colors.white24,
                          size: 55,
                        ),
                        SizedBox(
                          height: 12,
                        ),
                        Text(
                          'Sonuç bulunamadı',
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate:
                      SliverChildBuilderDelegate(
                    (
                      context,
                      index,
                    ) {
                      final track =
                          _tracks[index];

                      final isPlaying =
                          _playingOnlineId ==
                                  track.id &&
                              _playing;

                      final isDownloaded =
                          _isDownloaded(
                        track.id,
                      );

                      final isDownloading =
                          _downloading
                              .contains(
                        track.id,
                      );

                      return Padding(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          18,
                          4,
                          18,
                          4,
                        ),
                        child:
                            _TrackCard(
                          track:
                              track,
                          playing:
                              isPlaying,
                          downloaded:
                              isDownloaded,
                          downloading:
                              isDownloading,
                          onPlay:
                              () {
                            _playOnline(
                              track,
                            );
                          },
                          onDownload:
                              () {
                            _download(
                              track,
                            );
                          },
                          onInfo:
                              () {
                            _showLicense(
                              track,
                            );
                          },
                        ),
                      );
                    },
                    childCount:
                        _tracks.length,
                  ),
                ),

              SliverToBoxAdapter(
                child:
                    _downloadsCard(),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 125,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        20,
        14,
        20,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
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
                  'B_music02',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),
                Text(
                  'Müzik her yerde',
                  style:
                      TextStyle(
                    color:
                        Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap:
                _showDownloads,
            child: Container(
              width: 45,
              height: 45,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    const Color(
                  0xFF151515,
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
              child:
                  const Icon(
                Icons
                    .download_done_rounded,
                color:
                    AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchArea() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        20,
        22,
        20,
        0,
      ),
      child: Column(
        children: [
          const Text(
            'Müzik İndir',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 36,
              fontWeight:
                  FontWeight.w900,
              letterSpacing:
                  -1.5,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          const Text(
            'ARA • DİNLE • İNDİR • ÇEVRİMDIŞI DİNLE',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white38,
              fontSize: 8,
              letterSpacing:
                  1.8,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 21,
          ),

          Container(
            height: 58,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF151515,
              ),
              borderRadius:
                  BorderRadius.circular(
                24,
              ),
              border:
                  Border.all(
                color:
                    AppColors.gold
                        .withOpacity(
                  0.55,
                ),
              ),
            ),
            child: TextField(
              controller:
                  _searchController,
              onChanged:
                  _onSearchChanged,
              onSubmitted: (_) {
                _search();
              },
              textInputAction:
                  TextInputAction.search,
              style:
                  const TextStyle(
                color:
                    Colors.white,
              ),
              decoration:
                  InputDecoration(
                border:
                    InputBorder.none,
                prefixIcon:
                    const Icon(
                  Icons
                      .search_rounded,
                  color:
                      Colors.white,
                ),
                hintText:
                    'Şarkı veya müzik ara...',
                hintStyle:
                    const TextStyle(
                  color:
                      Colors.white38,
                  fontSize: 13,
                ),
                suffixIcon:
                    _searchController
                            .text
                            .isEmpty
                        ? const Icon(
                            Icons
                                .graphic_eq_rounded,
                            color:
                                AppColors.gold,
                          )
                        : IconButton(
                            onPressed:
                                () {
                              _searchController
                                  .clear();

                              setState(
                                () {},
                              );

                              _search();
                            },
                            icon:
                                const Icon(
                              Icons
                                  .close_rounded,
                              color:
                                  Colors.white54,
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 20,
          vertical: 15,
        ),
        scrollDirection:
            Axis.horizontal,
        itemCount:
            _categories.length,
        separatorBuilder:
            (
          context,
          index,
        ) =>
                const SizedBox(
          width: 9,
        ),
        itemBuilder:
            (
          context,
          index,
        ) {
          final item =
              _categories[index];

          final selected =
              item ==
                  _selectedCategory;

          return GestureDetector(
            onTap: () {
              _selectCategory(
                item,
              );
            },
            child:
                AnimatedContainer(
              duration:
                  const Duration(
                milliseconds:
                    180,
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 19,
              ),
              alignment:
                  Alignment.center,
              decoration:
                  BoxDecoration(
                gradient:
                    selected
                        ? const LinearGradient(
                            colors: [
                              Color(
                                0xFFFFDE7A,
                              ),
                              Color(
                                0xFFD4AF57,
                              ),
                            ],
                          )
                        : null,
                color:
                    selected
                        ? null
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
              child: Text(
                item,
                style:
                    TextStyle(
                  color:
                      selected
                          ? Colors.black
                          : Colors.white,
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hero() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        20,
        0,
        20,
        24,
      ),
      child: Container(
        height: 175,
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            27,
          ),
          border: Border.all(
            color: AppColors.gold
                .withOpacity(
              0.38,
            ),
          ),
          gradient:
              const LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Color(
                0xFF281D0E,
              ),
              Color(
                0xFF0C0C0C,
              ),
              Color(
                0xFF171109,
              ),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -25,
              child: Container(
                width: 170,
                height: 170,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  border:
                      Border.all(
                    color:
                        AppColors.gold
                            .withOpacity(
                      0.25,
                    ),
                    width: 24,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .album_rounded,
                  color:
                      AppColors.gold,
                  size: 58,
                ),
              ),
            ),

            const Padding(
              padding:
                  EdgeInsets.all(
                21,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'WIKIMEDIA COMMONS',
                    style:
                        TextStyle(
                      color:
                          AppColors.gold,
                      fontSize: 9,
                      letterSpacing:
                          1.8,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),

                  SizedBox(
                    height: 14,
                  ),

                  Text(
                    'Özgür Müziği\nKeşfet',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 27,
                      height: 1.03,
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),

                  SizedBox(
                    height: 9,
                  ),

                  Text(
                    'Lisansı uygun parçaları indir\nve internetsiz dinle.',
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        20,
        0,
        20,
        13,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Müzikler',
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 22,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),

          if (!_loading)
            Text(
              '${_tracks.length} sonuç',
              style:
                  const TextStyle(
                color:
                    AppColors.gold,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorBox() {
    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 25,
        vertical: 55,
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .cloud_off_rounded,
            size: 50,
            color:
                Colors.white24,
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'Bağlantı hatası',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          SelectableText(
            _error ??
                'Bilinmeyen hata',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Colors.white54,
              fontSize: 11,
              height: 1.5,
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          FilledButton.icon(
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  AppColors.gold,
              foregroundColor:
                  Colors.black,
            ),
            onPressed:
                _search,
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
            label:
                const Text(
              'Tekrar Dene',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _downloadsCard() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        24,
        18,
        0,
      ),
      child: GestureDetector(
        onTap:
            _showDownloads,
        child: Container(
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFF111111,
            ),
            borderRadius:
                BorderRadius.circular(
              24,
            ),
            border:
                Border.all(
              color:
                  AppColors.gold
                      .withOpacity(
                0.20,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons
                    .folder_rounded,
                color:
                    AppColors.gold,
                size: 37,
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'İndirilenler',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      '${_downloads.length} müzik • İnternetsiz dinle',
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

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    AppColors.gold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackCard
    extends StatelessWidget {
  const _TrackCard({
    required this.track,
    required this.playing,
    required this.downloaded,
    required this.downloading,
    required this.onPlay,
    required this.onDownload,
    required this.onInfo,
  });

  final CommonsTrack track;

  final bool playing;
  final bool downloaded;
  final bool downloading;

  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onInfo;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 82,
      ),
      padding:
          const EdgeInsets.all(
        10,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF121212,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              Colors.white
                  .withOpacity(
            0.06,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap:
                onPlay,
            child: Container(
              width: 58,
              height: 58,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(
                      0xFF3A2911,
                    ),
                    Color(
                      0xFF151515,
                    ),
                  ],
                ),
              ),
              child: Icon(
                playing
                    ? Icons
                        .pause_rounded
                    : Icons
                        .play_arrow_rounded,
                color:
                    AppColors.gold,
                size: 31,
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                GestureDetector(
              onTap:
                  onInfo,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 10,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    track.licenseName,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      color:
                          track.canDownload
                              ? AppColors.gold
                              : Colors
                                  .white30,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          if (downloading)
            const SizedBox(
              width: 44,
              height: 44,
              child: Padding(
                padding:
                    EdgeInsets.all(
                  11,
                ),
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      AppColors.gold,
                ),
              ),
            )
          else
            GestureDetector(
              onTap:
                  downloaded
                      ? null
                      : onDownload,
              child: Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      AppColors.gold
                          .withOpacity(
                    0.08,
                  ),
                  border:
                      Border.all(
                    color:
                        downloaded
                            ? Colors
                                .greenAccent
                            : track
                                    .canDownload
                                ? AppColors
                                    .gold
                                : Colors
                                    .white12,
                  ),
                ),
                child: Icon(
                  downloaded
                      ? Icons
                          .download_done_rounded
                      : track.canDownload
                          ? Icons
                              .download_rounded
                          : Icons
                              .lock_rounded,
                  color:
                      downloaded
                          ? Colors
                              .greenAccent
                          : track
                                  .canDownload
                              ? AppColors
                                  .gold
                              : Colors
                                  .white30,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 65,
            child: Text(
              title,
              style:
                  const TextStyle(
                color:
                    AppColors.gold,
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value.isEmpty
                  ? 'Belirtilmemiş'
                  : value,
              style:
                  const TextStyle(
                color:
                    Colors.white60,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
