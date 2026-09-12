import 'package:flutter/material.dart';

import '../../core/services/tiktok_service.dart';
import '../../models/video_item.dart';
import '../requests/requests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  static const _gold =
      Color(0xFFD4AF57);

  static const _burgundy =
      Color(0xFF7A1F3D);

  static const _background =
      Color(0xFF080808);

  static const _surface =
      Color(0xFF151114);

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

  void _openRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const RequestsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos =
        _filteredVideos;

    final VideoItem? featured =
        _videos.isNotEmpty
            ? _videos.first
            : null;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _gold,
          onRefresh: _loadFirstPage,
          child: CustomScrollView(
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
                      _buildHeader(),

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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Videolar',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        25,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                                SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  'B_music02 içerikleri',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white38,
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
                                color: _gold
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
                                    _gold,
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
                  hasScrollBody: false,
                  child: Center(
                    child:
                        CircularProgressIndicator(
                      color: _gold,
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(30),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          const Icon(
                            Icons
                                .wifi_off_rounded,
                            color:
                                Colors.white38,
                            size: 54,
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          Text(
                            _error!,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white70,
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
              else if (videos.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Video bulunamadı.',
                      style: TextStyle(
                        color:
                            Colors.white54,
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
                  sliver: SliverGrid(
                    delegate:
                        SliverChildBuilderDelegate(
                      (
                        context,
                        index,
                      ) {
                        final video =
                            videos[index];

                        return _VideoTile(
                          video: video,
                          onTap: () {
                            _openVideo(
                              video,
                            );
                          },
                        );
                      },
                      childCount:
                          videos.length,
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
                    child: _loadingMore
                        ? const Column(
                            children: [
                              SizedBox(
                                width: 25,
                                height: 25,
                                child:
                                    CircularProgressIndicator(
                                  color:
                                      _gold,
                                  strokeWidth:
                                      2,
                                ),
                              ),
                              SizedBox(
                                height:
                                    10,
                              ),
                              Text(
                                'Yeni videolar yükleniyor...',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white38,
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          padding:
              const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _gold,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/b_music02_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const ColoredBox(
                  color: _burgundy,
                  child: Icon(
                    Icons
                        .music_note_rounded,
                    color: _gold,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'B_music02',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              SizedBox(height: 2),

              Text(
                'Müzik burada yaşar',
                style: TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: _surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: const Icon(
            Icons
                .notifications_none_rounded,
            color: Colors.white,
            size: 22,
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
      style: const TextStyle(
        color: Colors.white,
      ),
      decoration:
          InputDecoration(
        hintText:
            'Şarkı veya video ara',
        hintStyle:
            const TextStyle(
          color: Colors.white38,
        ),
        prefixIcon:
            const Icon(
          Icons.search_rounded,
          color: _gold,
        ),
        suffixIcon:
            const Icon(
          Icons.tune_rounded,
          color: Colors.white38,
        ),
        filled: true,
        fillColor: _surface,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          borderSide:
              BorderSide.none,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          borderSide:
              BorderSide(
            color: Colors.white
                .withOpacity(
              0.08,
            ),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          borderSide:
              const BorderSide(
            color: _gold,
          ),
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
        _openVideo(video);
      },
      child: SizedBox(
        height: 310,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(
            28,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnail != null &&
                  thumbnail.isNotEmpty)
                Image.network(
                  thumbnail,
                  fit: BoxFit.cover,
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
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
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
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color: _burgundy
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
                        size: 15,
                      ),
                      SizedBox(
                        width: 5,
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
                              FontWeight
                                  .w900,
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
                        BoxShape.circle,
                    color: Colors.black
                        .withOpacity(
                      0.43,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.white54,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .play_arrow_rounded,
                    color: Colors.white,
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
                        fontSize: 20,
                        height: 1.1,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      video.artist,
                      style:
                          const TextStyle(
                        color: _gold,
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w700,
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
              Alignment.bottomRight,
          colors: [
            _burgundy,
            Color(
              0xFF211016,
            ),
            Colors.black,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons
              .music_note_rounded,
          color: _gold,
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
            icon:
                Icons.explore_rounded,
            title: 'Keşfet',
            subtitle:
                'Yeni videolar',
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Alttaki Keşfet bölümünden tam ekran akışı açabilirsiniz.',
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _QuickAction(
            icon: Icons
                .music_note_rounded,
            title: 'İstek',
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
            (context, index) {
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
                    ? _gold
                    : _surface,
                borderRadius:
                    BorderRadius
                        .circular(
                  22,
                ),
                border:
                    Border.all(
                  color: selected
                      ? _gold
                      : Colors
                          .white10,
                ),
              ),
              child: Text(
                item,
                style:
                    TextStyle(
                  color: selected
                      ? Colors.black
                      : Colors
                          .white60,
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: Ink(
          padding:
              const EdgeInsets.all(
            14,
          ),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                    BoxDecoration(
                  color: _gold
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
                  color: _gold,
                  size: 22,
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
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 14,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.white38,
                        fontSize: 10,
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
  Widget build(BuildContext context) {
    final thumbnail =
        video.thumbnailUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnail != null &&
                  thumbnail.isNotEmpty)
                Image.network(
                  thumbnail,
                  fit: BoxFit.cover,
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
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
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
                child: CircleAvatar(
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
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w800,
                        height: 1.15,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      video.artist,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color: _gold,
                        fontSize: 10,
                        fontWeight:
                            FontWeight
                                .w600,
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
              Alignment.bottomRight,
          colors: [
            _burgundy,
            Color(
              0xFF181014,
            ),
            Colors.black,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons
              .music_note_rounded,
          color: _gold,
          size: 50,
        ),
      ),
    );
  }
}
