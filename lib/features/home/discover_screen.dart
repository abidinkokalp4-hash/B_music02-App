import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/wikimedia_music_service.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/youtube_music_service.dart';
import '../../core/theme/app_theme.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final YouTubeMusicService _youtube =
      const YouTubeMusicService();

  final WikimediaMusicService _commons =
      const WikimediaMusicService();

  final TextEditingController _searchController =
      TextEditingController();

  final LocalMusicService _music = LocalMusicService.instance;

  bool get _offlinePlaying => _music.player.playing;
  String? get _offlinePlayingPath => _music.currentDownloadPath;

  Timer? _debounce;


  List<YouTubeMusicItem> _youtubeItems = [];

  List<DownloadedCommonsTrack> _downloads = [];

  bool _loading = false;
  bool _loadingMore = false;

  String? _error;
  String? _nextPageToken;

  String _selectedCategory = 'Tümü';

  static const List<String> _categories = [
    'Tümü',
    'Türkçe',
    'Kürtçe',
    'Arabesk',
    'Pop',
    'Rap',
    'Halk',
  ];

  @override
  void initState() {
    super.initState();

    _loadDownloads();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _search();
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadDownloads() async {
    final result =
        await _commons.getDownloads();

    if (!mounted) return;

    setState(() {
      _downloads = result;
    });
  }

  String _effectiveQuery() {
    final text =
        _searchController.text.trim();

    String category = '';

    switch (_selectedCategory) {
      case 'Türkçe':
        category = 'Türkçe müzik';
        break;

      case 'Kürtçe':
        category = 'Kürtçe müzik';
        break;

      case 'Arabesk':
        category = 'Türkçe arabesk';
        break;

      case 'Pop':
        category = 'pop music';
        break;

      case 'Rap':
        category = 'rap music';
        break;

      case 'Halk':
        category = 'Türk halk müziği';
        break;
    }

    if (text.isNotEmpty &&
        category.isNotEmpty) {
      return '$text $category';
    }

    if (text.isNotEmpty) {
      return text;
    }

    if (category.isNotEmpty) {
      return category;
    }

    return 'popular music';
  }

  Future<void> _search() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _nextPageToken = null;
    });

    try {
      final result =
          await _youtube.searchMusic(
        _effectiveQuery(),
        maxResults: 25,
      );

      if (!mounted) return;

      setState(() {
        _youtubeItems = result.items;
        _nextPageToken =
            result.nextPageToken;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _youtubeItems = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    final token =
        _nextPageToken;

    if (token == null ||
        token.isEmpty ||
        _loadingMore) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final result =
          await _youtube.searchMore(
        query: _effectiveQuery(),
        nextPageToken: token,
      );

      if (!mounted) return;

      setState(() {
        _youtubeItems.addAll(
          result.items,
        );

        _nextPageToken =
            result.nextPageToken;
      });
    } catch (e) {
      _message(
        'Daha fazla sonuç alınamadı: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(
    String value,
  ) {
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(
      const Duration(
        milliseconds: 650,
      ),
      _search,
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

  Future<void> _openYouTubePlayer(
    YouTubeMusicItem item,
  ) async {
    await _music.pause();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _YouTubePlayerScreen(
          item: item,
        ),
      ),
    );
  }

  Future<void> _openYouTubeExternal(
    YouTubeMusicItem item,
  ) async {
    final uri =
        Uri.tryParse(
      item.youtubeUrl,
    );

    if (uri == null) return;

    await launchUrl(
      uri,
      mode:
          LaunchMode.externalApplication,
    );
  }

  Future<void> _findLegalDownload(
    YouTubeMusicItem item,
  ) async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled: true,
      builder: (
        sheetContext,
      ) {
        return _LegalDownloadSheet(
          youtubeItem: item,
          commons: _commons,
          onDownloaded: () async {
            await _loadDownloads();

            if (!mounted) return;

            _message(
              'Müzik indirildi. İnternetsiz dinleyebilirsiniz.',
            );
          },
        );
      },
    );
  }

  Future<void> _playDownloaded(
    DownloadedCommonsTrack track,
  ) async {
    try {
      await _music.playDownload(track, from: _downloads);
    } catch (e) {
      _message(
        'Müzik oynatılamadı: $e',
      );
    }
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
            return StreamBuilder<PlayerEvent>(
              stream: _music.player.playerEventStream,
              builder: (context, snapshot) => SafeArea(
              child: Container(
                constraints:
                    BoxConstraints(
                  maxHeight:
                      MediaQuery.of(
                            context,
                          ).size.height *
                          0.80,
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
                              fontSize: 22,
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
                                MainAxisSize
                                    .min,
                            children: [
                              Icon(
                                Icons
                                    .library_music_outlined,
                                size: 55,
                                color:
                                    Colors.white24,
                              ),
                              SizedBox(
                                height: 12,
                              ),
                              Text(
                                'Henüz indirilen müzik yok.',
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
                              _downloads.length,
                          separatorBuilder:
                              (
                            context,
                            index,
                          ) =>
                                  const Divider(
                            color:
                                Colors.white12,
                          ),
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final item =
                                _downloads[
                                    index];

                            final playing =
                                _offlinePlayingPath ==
                                        item
                                            .localPath &&
                                    _offlinePlaying;

                            return ListTile(
                              contentPadding:
                                  EdgeInsets.zero,
                              onTap:
                                  () async {
                                await _playDownloaded(
                                  item,
                                );

                                modalSetState(
                                  () {},
                                );
                              },
                              leading:
                                  Container(
                                width: 50,
                                height: 50,
                                decoration:
                                    BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(
                                    15,
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
                                child:
                                    Icon(
                                  playing
                                      ? Icons
                                          .pause_rounded
                                      : Icons
                                          .play_arrow_rounded,
                                  color:
                                      AppColors.gold,
                                  size: 29,
                                ),
                              ),
                              title:
                                  Text(
                                item.title,
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
                                '${item.artist}\n${item.licenseName}',
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
                                  if (_offlinePlayingPath ==
                                      item.localPath) {
                                    await _music.stop();
                                  }

                                  await _commons
                                      .deleteDownload(
                                    item,
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
          color:
              AppColors.gold,
          backgroundColor:
              const Color(
            0xFF151515,
          ),
          onRefresh:
              _search,
          child: CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(
              parent:
                  BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child:
                    _buildHeader(),
              ),

              SliverToBoxAdapter(
                child:
                    _buildSearch(),
              ),

              SliverToBoxAdapter(
                child:
                    _buildCategories(),
              ),

              SliverToBoxAdapter(
                child:
                    _buildHero(),
              ),

              SliverToBoxAdapter(
                child:
                    _buildTitle(),
              ),

              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 90,
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
                  child:
                      _buildError(),
                )
              else if (_youtubeItems
                  .isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 80,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons
                              .music_off_rounded,
                          size: 55,
                          color:
                              Colors.white24,
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
                      final item =
                          _youtubeItems[
                              index];

                      return Padding(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          18,
                          5,
                          18,
                          5,
                        ),
                        child:
                            _YouTubeMusicCard(
                          item:
                              item,
                          onPlay:
                              () {
                            _openYouTubePlayer(
                              item,
                            );
                          },
                          onOpenYouTube:
                              () {
                            _openYouTubeExternal(
                              item,
                            );
                          },
                          onLegalDownload:
                              () {
                            _findLegalDownload(
                              item,
                            );
                          },
                        ),
                      );
                    },
                    childCount:
                        _youtubeItems.length,
                  ),
                ),

              if (!_loading &&
                  _nextPageToken != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      20,
                      18,
                      20,
                      0,
                    ),
                    child:
                        SizedBox(
                      height: 50,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _loadingMore
                                ? null
                                : _loadMore,
                        icon:
                            _loadingMore
                                ? const SizedBox(
                                    width:
                                        18,
                                    height:
                                        18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color:
                                          AppColors.gold,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .expand_more_rounded,
                                  ),
                        label:
                            Text(
                          _loadingMore
                              ? 'Yükleniyor'
                              : 'Daha Fazla Göster',
                        ),
                      ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child:
                    _buildDownloadsCard(),
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

  Widget _buildHeader() {
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
              width: 46,
              height: 46,
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

  Widget _buildSearch() {
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
            'Müzik',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 38,
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
            'ARA • DİNLE • YASAL İNDİR',
            style:
                TextStyle(
              color:
                  Colors.white38,
              fontSize: 8,
              letterSpacing:
                  2,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Container(
            height: 60,
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
              onSubmitted:
                  (_) => _search(),
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
                    'Şarkı, sanatçı veya albüm ara...',
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

  Widget _buildCategories() {
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

  Widget _buildHero() {
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
            28,
          ),
          border:
              Border.all(
            color:
                AppColors.gold
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
                0xFF2B1F0F,
              ),
              Color(
                0xFF0D0D0D,
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
              right: -28,
              top: -28,
              child: Container(
                width: 180,
                height: 180,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  border:
                      Border.all(
                    color:
                        AppColors.gold
                            .withOpacity(
                      0.23,
                    ),
                    width: 25,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .play_circle_fill_rounded,
                  color:
                      AppColors.gold,
                  size: 60,
                ),
              ),
            ),

            const Padding(
              padding:
                  EdgeInsets.all(
                22,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'YOUTUBE MÜZİK ARAMASI',
                    style:
                        TextStyle(
                      color:
                          AppColors.gold,
                      fontSize: 9,
                      letterSpacing:
                          1.5,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),

                  SizedBox(
                    height: 14,
                  ),

                  Text(
                    'Ara, Bul\nve Dinle',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 28,
                      height: 1.02,
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),

                  SizedBox(
                    height: 9,
                  ),

                  Text(
                    'YouTube müzik kataloğunda ara.\nİzinli alternatifleri çevrimdışı dinle.',
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

  Widget _buildTitle() {
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
              '${_youtubeItems.length} sonuç',
              style:
                  const TextStyle(
                color:
                    AppColors.gold,
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 25,
        vertical: 60,
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .cloud_off_rounded,
            size: 55,
            color:
                Colors.white24,
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'YouTube bağlantı hatası',
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
            height: 18,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsCard() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        25,
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
                0.22,
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

class _YouTubeMusicCard
    extends StatelessWidget {
  const _YouTubeMusicCard({
    required this.item,
    required this.onPlay,
    required this.onOpenYouTube,
    required this.onLegalDownload,
  });

  final YouTubeMusicItem item;

  final VoidCallback onPlay;
  final VoidCallback onOpenYouTube;
  final VoidCallback onLegalDownload;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
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
            child: Stack(
              alignment:
                  Alignment.center,
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  child: item.thumbnailUrl
                          .isNotEmpty
                      ? Image.network(
                          item.thumbnailUrl,
                          width: 92,
                          height: 62,
                          fit:
                              BoxFit.cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return _fallback();
                          },
                        )
                      : _fallback(),
                ),

                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        Colors.black
                            .withOpacity(
                      0.68,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .play_arrow_rounded,
                    color:
                        Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  item.channelTitle,
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
                  height: 8,
                ),

                Row(
                  children: [
                    GestureDetector(
                      onTap:
                          onLegalDownload,
                      child:
                          Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              10,
                          vertical:
                              6,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.gold
                                  .withOpacity(
                            0.10,
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
                              0.40,
                            ),
                          ),
                        ),
                        child:
                            const Row(
                          mainAxisSize:
                              MainAxisSize
                                  .min,
                          children: [
                            Icon(
                              Icons
                                  .download_rounded,
                              color:
                                  AppColors.gold,
                              size: 13,
                            ),
                            SizedBox(
                              width: 4,
                            ),
                            Text(
                              'Yasal indir',
                              style:
                                  TextStyle(
                                color:
                                    AppColors.gold,
                                fontSize: 8,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 7,
                    ),

                    GestureDetector(
                      onTap:
                          onOpenYouTube,
                      child:
                          const Padding(
                        padding:
                            EdgeInsets.all(
                          5,
                        ),
                        child:
                            Icon(
                          Icons
                              .open_in_new_rounded,
                          color:
                              Colors.white38,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 92,
      height: 62,
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
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
      child:
          const Icon(
        Icons.music_note_rounded,
        color:
            AppColors.gold,
      ),
    );
  }
}

class _YouTubePlayerScreen
    extends StatefulWidget {
  const _YouTubePlayerScreen({
    required this.item,
  });

  final YouTubeMusicItem item;

  @override
  State<_YouTubePlayerScreen> createState() =>
      _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState
    extends State<_YouTubePlayerScreen> {
  late final WebViewController _controller;

  bool _loading = true;

  static const String _appOrigin =
      'https://com.example.b_music02';

  @override
  void initState() {
    super.initState();

    final videoId =
        widget.item.videoId;

    final origin =
        Uri.encodeComponent(
      _appOrigin,
    );

    final html =
        '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta
  name="viewport"
  content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<meta
  name="referrer"
  content="strict-origin-when-cross-origin">

<style>
html, body {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  background: #000000;
  overflow: hidden;
}

.player {
  position: absolute;
  width: 100%;
  height: 100%;
  inset: 0;
}

iframe {
  position: absolute;
  width: 100%;
  height: 100%;
  inset: 0;
  border: 0;
}
</style>
</head>

<body>
<div class="player">
  <iframe
    src="https://www.youtube.com/embed/$videoId?autoplay=1&playsinline=1&controls=1&rel=0&enablejsapi=1&origin=$origin"
    allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
    allowfullscreen>
  </iframe>
</div>
</body>
</html>
''';

    _controller =
        WebViewController()
          ..setJavaScriptMode(
            JavaScriptMode.unrestricted,
          )
          ..setBackgroundColor(
            Colors.black,
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished:
                  (url) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _loading = false;
                });
              },
            ),
          )
          ..loadHtmlString(
            html,
            baseUrl:
                '$_appOrigin/',
          );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      appBar: AppBar(
        backgroundColor:
            Colors.black,
        foregroundColor:
            Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Text(
              widget.item.title,
              maxLines: 1,
              overflow:
                  TextOverflow
                      .ellipsis,
              style:
                  const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            Text(
              widget.item.channelTitle,
              maxLines: 1,
              overflow:
                  TextOverflow
                      .ellipsis,
              style:
                  const TextStyle(
                fontSize: 9,
                color:
                    Colors.white54,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child:
                  AspectRatio(
                aspectRatio:
                    16 / 9,
                child:
                    WebViewWidget(
                  controller:
                      _controller,
                ),
              ),
            ),
          ),

          if (_loading)
            const Positioned.fill(
              child: Center(
                child:
                    CircularProgressIndicator(
                  color:
                      AppColors.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalDownloadSheet
    extends StatefulWidget {
  const _LegalDownloadSheet({
    required this.youtubeItem,
    required this.commons,
    required this.onDownloaded,
  });

  final YouTubeMusicItem youtubeItem;

  final WikimediaMusicService commons;

  final Future<void> Function()
      onDownloaded;

  @override
  State<_LegalDownloadSheet>
      createState() =>
          _LegalDownloadSheetState();
}

class _LegalDownloadSheetState
    extends State<_LegalDownloadSheet> {
  bool _loading = true;

  String? _error;

  List<CommonsTrack> _results = [];

  final Set<int> _downloading = {};

  @override
  void initState() {
    super.initState();

    _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
          await widget.commons
              .searchMusic(
        '${widget.youtubeItem.title} '
        '${widget.youtubeItem.channelTitle}',
        limit: 15,
      );

      if (!mounted) return;

      setState(() {
        _results = result
            .where(
              (item) =>
                  item.canDownload,
            )
            .toList();

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

  Future<void> _download(
    CommonsTrack track,
  ) async {
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
      await widget.commons
          .downloadTrack(
        track,
      );

      await widget.onDownloaded();

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            'İndirme başarısız: $e',
          ),
        ),
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

  @override
  Widget build(
    BuildContext context,
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
            Container(
              width: 50,
              height: 5,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white12,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
            ),

            const SizedBox(
              height: 17,
            ),

            const Row(
              children: [
                Icon(
                  Icons
                      .verified_user_rounded,
                  color:
                      AppColors.gold,
                ),

                SizedBox(
                  width: 9,
                ),

                Expanded(
                  child: Text(
                    'Yasal İndirme Ara',
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
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              widget.youtubeItem.title,
              maxLines: 2,
              overflow:
                  TextOverflow
                      .ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white54,
                fontSize: 11,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'YouTube videosu indirilmiyor. '
              'Wikimedia Commons üzerinde açık lisanslı alternatif aranıyor.',
              style:
                  TextStyle(
                color:
                    Colors.white38,
                fontSize: 9,
                height: 1.4,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

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
                child: Center(
                  child: Text(
                    _error!,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                    ),
                  ),
                ),
              )
            else if (_results.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons
                            .search_off_rounded,
                        color:
                            Colors.white24,
                        size: 55,
                      ),

                      SizedBox(
                        height: 12,
                      ),

                      Text(
                        'Bu parça için indirilebilir açık lisanslı alternatif bulunamadı.',
                        textAlign:
                            TextAlign.center,
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
                      _results.length,
                  separatorBuilder:
                      (
                    context,
                    index,
                  ) =>
                          const Divider(
                    color:
                        Colors.white12,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final track =
                        _results[
                            index];

                    final downloading =
                        _downloading
                            .contains(
                      track.id,
                    );

                    return ListTile(
                      contentPadding:
                          EdgeInsets.zero,

                      leading:
                          Container(
                        width: 47,
                        height: 47,
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.gold
                                  .withOpacity(
                            0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            14,
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
                          fontSize: 9,
                        ),
                      ),

                      trailing:
                          downloading
                              ? const SizedBox(
                                  width: 35,
                                  height: 35,
                                  child:
                                      Padding(
                                    padding:
                                        EdgeInsets.all(
                                      7,
                                    ),
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color:
                                          AppColors.gold,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  onPressed:
                                      () {
                                    _download(
                                      track,
                                    );
                                  },
                                  icon:
                                      const Icon(
                                    Icons
                                        .download_rounded,
                                    color:
                                        AppColors.gold,
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
  }
}

