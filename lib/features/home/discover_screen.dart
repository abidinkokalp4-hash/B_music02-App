import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
  });

  @override
  State<DiscoverScreen> createState() =>
      _DiscoverScreenState();
}

class _DiscoverScreenState
    extends State<DiscoverScreen> {
  final TextEditingController
      _searchController =
      TextEditingController();

  String _selectedCategory = 'Tümü';

  final List<String> _categories = const [
    'Tümü',
    'Popüler',
    'Yeni',
    'Kürtçe',
    'Canlı',
  ];

  final List<_MusicItem> _songs = const [
    _MusicItem(
      title: 'Dile Min',
      artist: 'B_music02',
      duration: '4:12',
      category: 'Kürtçe',
      icon: Icons.music_note_rounded,
    ),
    _MusicItem(
      title: 'Roj Baş',
      artist: 'B_music02',
      duration: '3:48',
      category: 'Popüler',
      icon: Icons.graphic_eq_rounded,
    ),
    _MusicItem(
      title: 'Gecenin Sesi',
      artist: 'B_music02',
      duration: '4:26',
      category: 'Yeni',
      icon: Icons.headphones_rounded,
    ),
    _MusicItem(
      title: 'Canlı Performans',
      artist: 'B_music02',
      duration: '5:03',
      category: 'Canlı',
      icon: Icons.mic_rounded,
    ),
    _MusicItem(
      title: 'Yol',
      artist: 'B_music02',
      duration: '3:37',
      category: 'Kürtçe',
      icon: Icons.album_rounded,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_MusicItem> get _filteredSongs {
    final query =
        _searchController.text
            .trim()
            .toLowerCase();

    return _songs.where(
      (song) {
        final categoryMatch =
            _selectedCategory == 'Tümü' ||
                song.category ==
                    _selectedCategory;

        final searchMatch =
            query.isEmpty ||
                song.title
                    .toLowerCase()
                    .contains(query) ||
                song.artist
                    .toLowerCase()
                    .contains(query);

        return categoryMatch &&
            searchMatch;
      },
    ).toList();
  }

  void _downloadInfo(
    _MusicItem song,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return Container(
          margin:
              const EdgeInsets.all(14),
          padding:
              const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color:
                const Color(0xFF151515),
            borderRadius:
                BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.gold
                  .withOpacity(0.25),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold
                      .withOpacity(0.12),
                ),
                child: const Icon(
                  Icons
                      .download_rounded,
                  color:
                      AppColors.gold,
                  size: 30,
                ),
              ),
              const SizedBox(
                height: 14,
              ),
              Text(
                song.title,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                song.artist,
                style:
                    const TextStyle(
                  color:
                      Colors.white54,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              const Text(
                'Müzik indirme altyapısı hazırlandı. '
                'Gerçek indirme için lisanslı müzik kataloğunu bağlayacağız.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              SizedBox(
                width:
                    double.infinity,
                height: 50,
                child:
                    FilledButton(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        AppColors.gold,
                    foregroundColor:
                        Colors.black,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child:
                      const Text(
                    'Tamam',
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
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final songs =
        _filteredSongs;

    return Scaffold(
      backgroundColor:
          const Color(0xFF080808),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics:
              const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  20,
                  14,
                  20,
                  0,
                ),
                child: _Header(),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  20,
                  25,
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
                        fontSize: 37,
                        letterSpacing:
                            -1.5,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    const Text(
                      'SEVDİĞİN MÜZİK HER ZAMAN SENİNLE',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            Colors.white38,
                        fontSize: 9,
                        fontWeight:
                            FontWeight
                                .w700,
                        letterSpacing:
                            2.3,
                      ),
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    _SearchBox(
                      controller:
                          _searchController,
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 72,
                child:
                    ListView.separated(
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
                      (_, __) =>
                          const SizedBox(
                    width: 9,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final item =
                        _categories[
                            index];

                    final selected =
                        item ==
                            _selectedCategory;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory =
                              item;
                        });
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
                        alignment:
                            Alignment.center,
                        child: Text(
                          item,
                          style:
                              TextStyle(
                            color:
                                selected
                                    ? Colors.black
                                    : Colors.white,
                            fontWeight:
                                FontWeight
                                    .w800,
                            fontSize:
                                13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding:
                    EdgeInsets
                        .fromLTRB(
                  20,
                  0,
                  20,
                  24,
                ),
                child:
                    _FeaturedCard(),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  20,
                  0,
                  20,
                  12,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Popüler Şarkılar',
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
                      '${songs.length} şarkı',
                      style:
                          const TextStyle(
                        color:
                            AppColors.gold,
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (songs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.all(
                    40,
                  ),
                  child: Column(
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
                        'Şarkı bulunamadı',
                        style:
                            TextStyle(
                          color:
                              Colors.white60,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount:
                    songs.length,
                separatorBuilder:
                    (_, __) =>
                        const SizedBox(
                  height: 9,
                ),
                itemBuilder:
                    (
                  context,
                  index,
                ) {
                  final song =
                      songs[index];

                  return Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 20,
                    ),
                    child:
                        _SongTile(
                      song: song,
                      onDownload: () {
                        _downloadInfo(
                          song,
                        );
                      },
                    ),
                  );
                },
              ),

            const SliverToBoxAdapter(
              child: Padding(
                padding:
                    EdgeInsets
                        .fromLTRB(
                  20,
                  24,
                  20,
                  125,
                ),
                child:
                    _DownloadsCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header
    extends StatelessWidget {
  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          padding:
              const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  AppColors.gold,
              width: 1.4,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/b_music02_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'B_music02',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              SizedBox(
                height: 2,
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

        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                const Color(
              0xFF151515,
            ),
            border: Border.all(
              color:
                  Colors.white10,
            ),
          ),
          child: const Icon(
            Icons
                .headphones_rounded,
            color:
                AppColors.gold,
          ),
        ),
      ],
    );
  }
}

class _SearchBox
    extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController
      controller;

  final ValueChanged<String>
      onChanged;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color:
            const Color(0xFF151515),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.gold
              .withOpacity(0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold
                .withOpacity(0.05),
            blurRadius: 28,
          ),
        ],
      ),
      child: TextField(
        controller:
            controller,
        onChanged:
            onChanged,
        style:
            const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.w600,
        ),
        decoration:
            const InputDecoration(
          border:
              InputBorder.none,
          prefixIcon:
              Icon(
            Icons.search_rounded,
            color:
                Colors.white,
            size: 27,
          ),
          suffixIcon:
              Icon(
            Icons
                .graphic_eq_rounded,
            color:
                AppColors.gold,
          ),
          hintText:
              'Şarkı, sanatçı veya albüm ara...',
          hintStyle:
              TextStyle(
            color:
                Colors.white38,
            fontSize: 13,
          ),
          contentPadding:
              EdgeInsets.symmetric(
            vertical: 19,
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard
    extends StatelessWidget {
  const _FeaturedCard();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(27),
        border: Border.all(
          color: AppColors.gold
              .withOpacity(0.40),
        ),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFF241A0E),
            Color(0xFF0D0D0D),
            Color(0xFF17120A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -20,
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
                    0.32,
                  ),
                  width: 22,
                ),
              ),
              child:
                  const Center(
                child: Icon(
                  Icons
                      .music_note_rounded,
                  color:
                      AppColors.gold,
                  size: 60,
                ),
              ),
            ),
          ),

          const Padding(
            padding:
                EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons
                          .workspace_premium_rounded,
                      color:
                          AppColors.gold,
                      size: 19,
                    ),
                    SizedBox(
                      width: 7,
                    ),
                    Text(
                      'EN ÇOK İNDİRİLENLER',
                      style:
                          TextStyle(
                        color:
                            AppColors.gold,
                        fontSize: 9,
                        letterSpacing:
                            2,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height: 14,
                ),

                Text(
                  'En Sevilen\nŞarkılar Cebinde',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 27,
                    height: 1.02,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),

                SizedBox(
                  height: 10,
                ),

                Text(
                  'İzinli müzikleri indir,\nçevrimdışı dinle.',
                  style:
                      TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SongTile
    extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.onDownload,
  });

  final _MusicItem song;
  final VoidCallback onDownload;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 76,
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            const Color(0xFF121212),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              Colors.white.withOpacity(
            0.06,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF3A2A12),
                  Color(0xFF151515),
                ],
              ),
            ),
            child: Icon(
              song.icon,
              color:
                  AppColors.gold,
              size: 29,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
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
                  height: 3,
                ),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Text(
            song.duration,
            style:
                const TextStyle(
              color:
                  Colors.white38,
              fontSize: 10,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          GestureDetector(
            onTap:
                onDownload,
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
                  0.10,
                ),
                border:
                    Border.all(
                  color:
                      AppColors.gold,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .download_rounded,
                color:
                    AppColors.gold,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsCard
    extends StatelessWidget {
  const _DownloadsCard();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            const Color(0xFF111111),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.gold
              .withOpacity(0.20),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons
                .folder_rounded,
            color:
                AppColors.gold,
            size: 38,
          ),
          SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
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
                SizedBox(
                  height: 3,
                ),
                Text(
                  'Çevrimdışı müziklerin burada olacak',
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
          Icon(
            Icons
                .chevron_right_rounded,
            color:
                AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class _MusicItem {
  const _MusicItem({
    required this.title,
    required this.artist,
    required this.duration,
    required this.category,
    required this.icon,
  });

  final String title;
  final String artist;
  final String duration;
  final String category;
  final IconData icon;
}
