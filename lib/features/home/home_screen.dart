import 'package:flutter/material.dart';

import '../../core/services/tiktok_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/video_item.dart';
import '../requests/requests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  final TikTokService _tiktok =
      const TikTokService();

  final TextEditingController
      _searchController =
      TextEditingController();

  final ScrollController
      _scrollController =
      ScrollController();

  final List<VideoItem> _videos = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int? _cursor;
  String? _error;

  String _filter = 'Tümü';

  static const List<String> _filters = [
    'Tümü',
    'Yeni',
    'TikTok',
  ];

  bool get _isDark =>
      Theme.of(context).brightness ==
      Brightness.dark;

  Color get _background =>
      Theme.of(context)
          .scaffoldBackgroundColor;

  Color get _surface =>
      Theme.of(context)
          .colorScheme
          .surface;

  Color get _textPrimary =>
      _isDark
          ? Colors.white
          : const Color(
              0xFF171313,
            );

  Color get _textSecondary =>
      _isDark
          ? Colors.white54
          : Colors.black54;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _onScroll,
    );

    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position =
        _scrollController.position;

    if (position.pixels >=
        position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _cursor = null;
      _hasMore = true;
    });

    try {
      final page =
          await _tiktok.fetchVideos();

      if (!mounted) return;

      setState(() {
        _videos
          ..clear()
          ..addAll(page.videos);

        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Videolar yüklenemedi.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading ||
        _loadingMore ||
        !_hasMore ||
        _cursor == null) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final page =
          await _tiktok.fetchVideos(
        cursor: _cursor,
      );

      if (!mounted) return;

      setState(() {
        for (final video
            in page.videos) {
          final exists =
              _videos.any(
            (item) =>
                item.id == video.id,
          );

          if (!exists) {
            _videos.add(video);
          }
        }

        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingMore = false;
      });
    }
  }

  List<VideoItem>
      get _filteredVideos {
    final query =
        _searchController.text
            .trim()
            .toLowerCase();

    var result =
        _videos.where((video) {
      final searchOk =
          query.isEmpty ||
              video.title
                  .toLowerCase()
                  .contains(query) ||
              video.artist
                  .toLowerCase()
                  .contains(query);

      final filterOk =
          _filter == 'Tümü' ||
              _filter == 'Yeni' ||
              video.category ==
                  _filter;

      return searchOk && filterOk;
    }).toList();

    if (_filter == 'Yeni') {
      result =
          result.take(10).toList();
    }

    return result;
  }

  Future<void> _openVideo(
    VideoItem video,
  ) async {
    final opened =
        await _tiktok.open(
      video.tiktokUrl,
    );

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Video açılamadı.',
        ),
      ),
    );
  }

  Future<void>
      _openTikTokProfile() async {
    final opened =
        await _tiktok.open(
      'https://www.tiktok.com/@b_music02',
    );

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'TikTok profili açılamadı.',
        ),
      ),
    );
  }

  void _openRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const RequestsScreen(),
      ),
    );
  }

  IconData _themeIcon(
    ThemeMode mode,
  ) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons
            .dark_mode_rounded;

      case ThemeMode.light:
        return Icons
            .light_mode_rounded;

      case ThemeMode.system:
        return Icons
            .brightness_auto_rounded;
    }
  }

  void _openThemeSelector() {
    final controller =
        ThemeControllerScope.of(
      context,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      showDragHandle: false,
      builder: (
        sheetContext,
      ) {
        return SafeArea(
          child: Container(
            margin:
                const EdgeInsets.all(
              12,
            ),
            padding:
                const EdgeInsets
                    .fromLTRB(
              18,
              10,
              18,
              20,
            ),
            decoration:
                BoxDecoration(
              color:
                  Theme.of(context)
                      .colorScheme
                      .surface,
              borderRadius:
                  BorderRadius
                      .circular(
                30,
              ),
              border:
                  Border.all(
                color: AppColors.gold
                    .withOpacity(
                  0.22,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(
                    0.18,
                  ),
                  blurRadius: 30,
                  offset:
                      const Offset(
                    0,
                    12,
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin:
                      const EdgeInsets
                          .only(
                    bottom: 18,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Theme.of(
                      context,
                    )
                        .dividerColor,
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                ),

                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .gold
                            .withOpacity(
                          0.12,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .palette_outlined,
                        color:
                            AppColors
                                .gold,
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
                            'Görünüm',
                            style:
                                TextStyle(
                              color:
                                  Theme.of(
                                context,
                              )
                                      .colorScheme
                                      .onSurface,
                              fontSize:
                                  20,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            'Uygulama temasını seçin',
                            style:
                                TextStyle(
                              color:
                                  Theme.of(
                                context,
                              )
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(
                                0.50,
                              ),
                              fontSize:
                                  12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                _ThemeOption(
                  icon: Icons
                      .brightness_auto_rounded,
                  title:
                      'Otomatik',
                  subtitle:
                      'Telefonun temasını kullan',
                  selected:
                      controller
                              .themeMode ==
                          ThemeMode
                              .system,
                  onTap: () async {
                    await controller
                        .setSystem();

                    if (sheetContext
                        .mounted) {
                      Navigator.pop(
                        sheetContext,
                      );
                    }
                  },
                ),

                const SizedBox(
                  height: 9,
                ),

                _ThemeOption(
                  icon: Icons
                      .dark_mode_rounded,
                  title:
                      'Gece',
                  subtitle:
                      'Koyu görünüm',
                  selected:
                      controller
                              .themeMode ==
                          ThemeMode.dark,
                  onTap: () async {
                    await controller
                        .setDark();

                    if (sheetContext
                        .mounted) {
                      Navigator.pop(
                        sheetContext,
                      );
                    }
                  },
                ),

                const SizedBox(
                  height: 9,
                ),

                _ThemeOption(
                  icon: Icons
                      .light_mode_rounded,
                  title:
                      'Gündüz',
                  subtitle:
                      'Açık görünüm',
                  selected:
                      controller
                              .themeMode ==
                          ThemeMode.light,
                  onTap: () async {
                    await controller
                        .setLight();

                    if (sheetContext
                        .mounted) {
                      Navigator.pop(
                        sheetContext,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final videos =
        _filteredVideos;

    final VideoItem? featured =
        _videos.isNotEmpty
            ? _videos.first
            : null;

    final themeController =
        ThemeControllerScope.of(
      context,
    );

    return Scaffold(
      backgroundColor:
          _background,
      body: SafeArea(
        child: RefreshIndicator(
          color:
              AppColors.gold,
          onRefresh:
              _loadFirstPage,
          child:
              CustomScrollView(
            controller:
                _scrollController,
            physics:
                const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    18,
                    18,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      _buildHeader(
                        themeController,
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      _buildSearch(),

                      const SizedBox(
                        height: 18,
                      ),

                      if (featured !=
                          null)
                        _buildStage(
                          featured,
                        ),

                      if (featured !=
                          null)
                        const SizedBox(
                          height: 18,
                        ),

                      _buildQuickActions(),

                      const SizedBox(
                        height: 24,
                      ),

                      _buildFilters(),

                      const SizedBox(
                        height: 25,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Videolar',
                                  style:
                                      TextStyle(
                                    color:
                                        _textPrimary,
                                    fontSize:
                                        25,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  'B_music02 içerikleri',
                                  style:
                                      TextStyle(
                                    color:
                                        _textSecondary,
                                    fontSize:
                                        12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  11,
                              vertical:
                                  6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  _surface,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                              border:
                                  Border.all(
                                color:
                                    AppColors
                                        .gold
                                        .withOpacity(
                                  0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              '${videos.length}',
                              style:
                                  const TextStyle(
                                color:
                                    AppColors
                                        .gold,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 14,
                      ),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody:
                      false,
                  child: Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          AppColors
                              .gold,
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody:
                      false,
                  child: Center(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        30,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          Icon(
                            Icons
                                .wifi_off_rounded,
                            color:
                                _textSecondary,
                            size: 54,
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          Text(
                            _error!,
                            style:
                                TextStyle(
                              color:
                                  _textSecondary,
                            ),
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          ElevatedButton(
                            onPressed:
                                _loadFirstPage,
                            child:
                                const Text(
                              'Tekrar Dene',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (videos
                  .isEmpty)
                SliverFillRemaining(
                  hasScrollBody:
                      false,
                  child: Center(
                    child: Text(
                      'Video bulunamadı.',
                      style:
                          TextStyle(
                        color:
                            _textSecondary,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    0,
                    18,
                    20,
                  ),
                  sliver:
                      SliverGrid(
                    delegate:
                        SliverChildBuilderDelegate(
                      (
                        context,
                        index,
                      ) {
                        final video =
                            videos[
                                index];

                        return _VideoTile(
                          video:
                              video,
                          onTap:
                              () {
                            _openVideo(
                              video,
                            );
                          },
                        );
                      },
                      childCount:
                          videos
                              .length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          2,
                      crossAxisSpacing:
                          11,
                      mainAxisSpacing:
                          13,
                      childAspectRatio:
                          0.72,
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    0,
                    15,
                    0,
                    130,
                  ),
                  child: Center(
                    child:
                        _loadingMore
                            ? Column(
                                children: [
                                  const SizedBox(
                                    width: 25,
                                    height: 25,
                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          AppColors.gold,
                                      strokeWidth:
                                          2,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Text(
                                    'Yeni videolar yükleniyor...',
                                    style:
                                        TextStyle(
                                      color:
                                          _textSecondary,
                                      fontSize:
                                          12,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox
                                .shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeController controller,
  ) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          padding:
              const EdgeInsets.all(
            4,
          ),
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            border:
                Border.all(
              color:
                  AppColors.gold,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/b_music02_logo.png',
              fit:
                  BoxFit.cover,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const ColoredBox(
                  color:
                      AppColors
                          .burgundy,
                  child: Icon(
                    Icons
                        .music_note_rounded,
                    color:
                        AppColors
                            .gold,
                  ),
                );
              },
            ),
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
                'B_music02',
                style:
                    TextStyle(
                  color:
                      _textPrimary,
                  fontSize:
                      22,
                  fontWeight:
                      FontWeight
                          .w900,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              const Text(
                'Müzik burada yaşar',
                style:
                    TextStyle(
                  color:
                      AppColors.gold,
                  fontSize:
                      12,
                  fontWeight:
                      FontWeight
                          .w600,
                ),
              ),
            ],
          ),
        ),

        Material(
          color:
              Colors.transparent,
          child: InkWell(
            onTap:
                _openThemeSelector,
            borderRadius:
                BorderRadius
                    .circular(
              50,
            ),
            child: Ink(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color:
                    _surface,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color: AppColors
                      .gold
                      .withOpacity(
                    0.22,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors
                        .gold
                        .withOpacity(
                      0.06,
                    ),
                    blurRadius:
                        15,
                  ),
                ],
              ),
              child: Icon(
                _themeIcon(
                  controller
                      .themeMode,
                ),
                color:
                    AppColors.gold,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller:
          _searchController,
      onChanged: (_) {
        setState(() {});
      },
      style: TextStyle(
        color:
            _textPrimary,
      ),
      decoration:
          InputDecoration(
        hintText:
            'Şarkı veya video ara',
        prefixIcon:
            const Icon(
          Icons.search_rounded,
          color:
              AppColors.gold,
        ),
        suffixIcon:
            Icon(
          Icons.tune_rounded,
          color:
              _textSecondary,
        ),
      ),
    );
  }

  Widget _buildStage(
    VideoItem video,
  ) {
    final thumbnail =
        video.thumbnailUrl;

    return GestureDetector(
      onTap: () {
        _openVideo(
          video,
        );
      },
      child: SizedBox(
        height: 310,
        child: ClipRRect(
          borderRadius:
              BorderRadius
                  .circular(
            28,
          ),
          child: Stack(
            fit:
                StackFit.expand,
            children: [
              if (thumbnail !=
                      null &&
                  thumbnail
                      .isNotEmpty)
                Image.network(
                  thumbnail,
                  fit:
                      BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _stageFallback();
                  },
                )
              else
                _stageFallback(),

              const DecoratedBox(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment
                            .topCenter,
                    end:
                        Alignment
                            .bottomCenter,
                    colors: [
                      Color(
                        0x22000000,
                      ),
                      Color(
                        0x20000000,
                      ),
                      Color(
                        0xE8000000,
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 17,
                top: 16,
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        11,
                    vertical:
                        6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors
                            .burgundy
                            .withOpacity(
                      0.90,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
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
                            .graphic_eq_rounded,
                        color:
                            Colors.white,
                        size:
                            15,
                      ),
                      SizedBox(
                        width:
                            5,
                      ),
                      Text(
                        'ÖNE ÇIKAN',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              10,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing:
                              1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape
                            .circle,
                    color:
                        Colors.black
                            .withOpacity(
                      0.43,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors
                              .white54,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .play_arrow_rounded,
                    color:
                        Colors.white,
                    size: 44,
                  ),
                ),
              ),

              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            20,
                        height:
                            1.1,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      video.artist,
                      style:
                          const TextStyle(
                        color:
                            AppColors
                                .gold,
                        fontSize:
                            13,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageFallback() {
    return Container(
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment
                  .bottomRight,
          colors: [
            AppColors.burgundy,
            Color(
              0xFF211016,
            ),
            Colors.black,
          ],
        ),
      ),
      child:
          const Center(
        child: Icon(
          Icons
              .music_note_rounded,
          color:
              AppColors.gold,
          size: 80,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons
                .person_add_alt_1_rounded,
            title:
                'Takip Et',
            subtitle:
                '@b_music02 • TikTok',
            onTap:
                _openTikTokProfile,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: _QuickAction(
            icon: Icons
                .music_note_rounded,
            title:
                'İstek',
            subtitle:
                'Şarkı iste',
            onTap:
                _openRequests,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 39,
      child:
          ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount:
            _filters.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 8,
        ),
        itemBuilder:
            (
          context,
          index,
        ) {
          final item =
              _filters[index];

          final selected =
              _filter == item;

          return GestureDetector(
            onTap: () {
              setState(() {
                _filter =
                    item;
              });
            },
            child:
                AnimatedContainer(
              duration:
                  const Duration(
                milliseconds:
                    200,
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal:
                    18,
              ),
              alignment:
                  Alignment.center,
              decoration:
                  BoxDecoration(
                color: selected
                    ? AppColors
                        .gold
                    : _surface,
                borderRadius:
                    BorderRadius
                        .circular(
                  22,
                ),
                border:
                    Border.all(
                  color: selected
                      ? AppColors
                          .gold
                      : Theme.of(
                          context,
                        )
                            .dividerColor,
                ),
              ),
              child: Text(
                item,
                style:
                    TextStyle(
                  color: selected
                      ? Colors
                          .black
                      : _textSecondary,
                  fontWeight:
                      selected
                          ? FontWeight
                              .w900
                          : FontWeight
                              .w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction
    extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final isDark =
        Theme.of(context)
                .brightness ==
            Brightness.dark;

    final surface =
        Theme.of(context)
            .colorScheme
            .surface;

    final primary =
        Theme.of(context)
            .colorScheme
            .onSurface;

    final secondary =
        primary.withOpacity(
      isDark ? 0.45 : 0.55,
    );

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius
                .circular(
          20,
        ),
        child: Ink(
          padding:
              const EdgeInsets
                  .all(
            14,
          ),
          decoration:
              BoxDecoration(
            color:
                surface,
            borderRadius:
                BorderRadius
                    .circular(
              20,
            ),
            border:
                Border.all(
              color: Theme.of(
                context,
              ).dividerColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .gold
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      AppColors
                          .gold,
                  size:
                      22,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          TextStyle(
                        color:
                            primary,
                        fontSize:
                            14,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      subtitle,
                      style:
                          TextStyle(
                        color:
                            secondary,
                        fontSize:
                            10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoTile
    extends StatelessWidget {
  const _VideoTile({
    required this.video,
    required this.onTap,
  });

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final thumbnail =
        video.thumbnailUrl;

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius
                .circular(
          20,
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius
                  .circular(
            20,
          ),
          child: Stack(
            fit:
                StackFit.expand,
            children: [
              if (thumbnail !=
                      null &&
                  thumbnail
                      .isNotEmpty)
                Image.network(
                  thumbnail,
                  fit:
                      BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _fallback();
                  },
                )
              else
                _fallback(),

              const DecoratedBox(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment
                            .topCenter,
                    end:
                        Alignment
                            .bottomCenter,
                    colors: [
                      Colors
                          .transparent,
                      Color(
                        0x22000000,
                      ),
                      Color(
                        0xE7000000,
                      ),
                    ],
                    stops: [
                      0.42,
                      0.62,
                      1,
                    ],
                  ),
                ),
              ),

              const Center(
                child:
                    CircleAvatar(
                  radius: 23,
                  backgroundColor:
                      Color(
                    0x65000000,
                  ),
                  child: Icon(
                    Icons
                        .play_arrow_rounded,
                    color:
                        Colors.white,
                    size: 31,
                  ),
                ),
              ),

              Positioned(
                left: 11,
                right: 11,
                bottom: 11,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      video.title,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            13,
                        fontWeight:
                            FontWeight.w800,
                        height:
                            1.15,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      video.artist,
                      maxLines:
                          1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            AppColors
                                .gold,
                        fontSize:
                            10,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment
                  .bottomRight,
          colors: [
            AppColors.burgundy,
            Color(
              0xFF181014,
            ),
            Colors.black,
          ],
        ),
      ),
      child:
          const Center(
        child: Icon(
          Icons
              .music_note_rounded,
          color:
              AppColors.gold,
          size: 50,
        ),
      ),
    );
  }
}

class _ThemeOption
    extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final onSurface =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius
                .circular(
          18,
        ),
        child: Ink(
          padding:
              const EdgeInsets
                  .all(
            13,
          ),
          decoration:
              BoxDecoration(
            color: selected
                ? AppColors.gold
                    .withOpacity(
                  0.12,
                )
                : Theme.of(
                    context,
                  )
                      .colorScheme
                      .surface,
            borderRadius:
                BorderRadius
                    .circular(
              18,
            ),
            border:
                Border.all(
              color: selected
                  ? AppColors
                      .gold
                  : Theme.of(
                      context,
                    )
                        .dividerColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                    BoxDecoration(
                  color: selected
                      ? AppColors
                          .gold
                      : AppColors
                          .gold
                          .withOpacity(
                        0.10,
                      ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? Colors
                          .black
                      : AppColors
                          .gold,
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
                      title,
                      style:
                          TextStyle(
                        color:
                            onSurface,
                        fontWeight:
                            FontWeight.w800,
                        fontSize:
                            15,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      subtitle,
                      style:
                          TextStyle(
                        color:
                            onSurface
                                .withOpacity(
                          0.45,
                        ),
                        fontSize:
                            11,
                      ),
                    ),
                  ],
                ),
              ),

              if (selected)
                const Icon(
                  Icons
                      .check_circle_rounded,
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
