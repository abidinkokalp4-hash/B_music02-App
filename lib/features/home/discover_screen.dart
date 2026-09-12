import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/jamendo_service.dart';
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
  final JamendoService _jamendo =
      const JamendoService();

  final TextEditingController
      _searchController =
      TextEditingController();

  Timer? _searchTimer;

  List<JamendoTrack> _tracks = [];

  bool _loading = true;

  String? _error;

  String _selectedCategory =
      'Tümü';

  static const List<String>
      _categories = [
    'Tümü',
    'Popüler',
    'Yeni',
    'Kürtçe',
    'Akustik',
  ];

  @override
  void initState() {
    super.initState();

    _loadPopular();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();

    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadPopular() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results =
          await _jamendo
              .popularTracks(
        limit: 40,
      );

      if (!mounted) return;

      setState(() {
        _tracks = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Müzikler yüklenemedi.';
      });
    }
  }

  void _onSearchChanged(
    String value,
  ) {
    _searchTimer?.cancel();

    _searchTimer =
        Timer(
      const Duration(
        milliseconds: 650,
      ),
      () {
        _performSearch();
      },
    );
  }

  Future<void> _performSearch() async {
    final query =
        _searchController.text.trim();

    if (query.isEmpty &&
        _selectedCategory ==
            'Tümü') {
      await _loadPopular();
      return;
    }

    if (_selectedCategory ==
        'Popüler') {
      await _loadPopular();
      return;
    }

    String searchQuery =
        query;

    if (_selectedCategory !=
            'Tümü' &&
        _selectedCategory !=
            'Popüler') {
      final category =
          _categorySearchTerm(
        _selectedCategory,
      );

      searchQuery =
          searchQuery.isEmpty
              ? category
              : '$searchQuery $category';
    }

    if (searchQuery.trim().isEmpty) {
      await _loadPopular();
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results =
          await _jamendo
              .searchTracks(
        searchQuery,
        limit: 40,
      );

      if (!mounted) return;

      setState(() {
        _tracks = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Arama sırasında hata oluştu.';
      });
    }
  }

  String _categorySearchTerm(
    String category,
  ) {
    switch (category) {
      case 'Yeni':
        return 'new';
      case 'Kürtçe':
        return 'kurdish';
      case 'Akustik':
        return 'acoustic';
      default:
        return '';
    }
  }

  Future<void> _selectCategory(
    String category,
  ) async {
    setState(() {
      _selectedCategory =
          category;
    });

    await _performSearch();
  }

  Future<void> _listen(
    JamendoTrack track,
  ) async {
    if (track.audioUrl.isEmpty) {
      _message(
        'Bu parçanın dinleme bağlantısı bulunamadı.',
      );

      return;
    }

    final uri =
        Uri.tryParse(
      track.audioUrl,
    );

    if (uri == null) {
      _message(
        'Müzik bağlantısı geçersiz.',
      );

      return;
    }

    try {
      final opened =
          await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );

      if (!opened) {
        _message(
          'Müzik oynatıcı açılamadı.',
        );
      }
    } catch (_) {
      _message(
        'Müzik oynatıcı açılamadı.',
      );
    }
  }

  Future<void> _download(
    JamendoTrack track,
  ) async {
    if (!track.downloadAllowed ||
        track.downloadUrl.isEmpty) {
      _showDownloadNotAllowed(
        track,
      );

      return;
    }

    final uri =
        Uri.tryParse(
      track.downloadUrl,
    );

    if (uri == null) {
      _message(
        'İndirme bağlantısı geçersiz.',
      );

      return;
    }

    _showDownloadSheet(
      track,
      uri,
    );
  }

  void _showDownloadSheet(
    JamendoTrack track,
    Uri uri,
  ) {
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
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 52,
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
                  height: 22,
                ),

                _Cover(
                  url:
                      track.imageUrl,
                  size:
                      100,
                ),

                const SizedBox(
                  height: 16,
                ),

                Text(
                  track.title,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        21,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  track.artist,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize:
                        13,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .all(
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.gold
                            .withOpacity(
                      0.07,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      17,
                    ),
                  ),
                  child:
                      const Row(
                    children: [
                      Icon(
                        Icons
                            .verified_rounded,
                        color:
                            AppColors.gold,
                      ),

                      SizedBox(
                        width:
                            10,
                      ),

                      Expanded(
                        child:
                            Text(
                          'Bu parça sanatçı tarafından indirmeye açık olarak işaretlenmiştir.',
                          style:
                              TextStyle(
                            color:
                                Colors.white70,
                            fontSize:
                                11,
                            height:
                                1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height:
                      52,
                  child:
                      FilledButton.icon(
                    style:
                        FilledButton
                            .styleFrom(
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
                    onPressed:
                        () async {
                      Navigator.pop(
                        sheetContext,
                      );

                      try {
                        final opened =
                            await launchUrl(
                          uri,
                          mode:
                              LaunchMode.externalApplication,
                        );

                        if (!opened) {
                          _message(
                            'İndirme bağlantısı açılamadı.',
                          );
                        }
                      } catch (_) {
                        _message(
                          'İndirme bağlantısı açılamadı.',
                        );
                      }
                    },
                    icon:
                        const Icon(
                      Icons
                          .download_rounded,
                    ),
                    label:
                        const Text(
                      'İndirmeyi Başlat',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                if (track.licenseUrl
                    .isNotEmpty) ...[
                  const SizedBox(
                    height: 13,
                  ),

                  TextButton.icon(
                    onPressed:
                        () async {
                      final licenseUri =
                          Uri.tryParse(
                        track
                            .licenseUrl,
                      );

                      if (licenseUri !=
                          null) {
                        await launchUrl(
                          licenseUri,
                          mode:
                              LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon:
                        const Icon(
                      Icons
                          .description_outlined,
                      size:
                          18,
                    ),
                    label:
                        const Text(
                      'Lisans bilgisini görüntüle',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDownloadNotAllowed(
    JamendoTrack track,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (
        context,
      ) {
        return Container(
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
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      Colors.white
                          .withOpacity(
                    0.05,
                  ),
                ),
                child:
                    const Icon(
                  Icons.lock_rounded,
                  color:
                      Colors.white54,
                  size:
                      30,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              const Text(
                'İndirme Kapalı',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      19,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                '${track.artist} bu parçanın indirilmesine izin vermemiş.',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.white54,
                  height:
                      1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _message(
    String text,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(text),
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
        child:
            RefreshIndicator(
          color:
              AppColors.gold,
          backgroundColor:
              const Color(
            0xFF151515,
          ),
          onRefresh:
              _loadPopular,
          child:
              CustomScrollView(
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
                    _buildFeatured(),
              ),

              SliverToBoxAdapter(
                child:
                    _buildSectionTitle(),
              ),

              if (_loading)
                const SliverToBoxAdapter(
                  child:
                      Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical:
                          80,
                    ),
                    child:
                        Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            AppColors.gold,
                      ),
                    ),
                  ),
                )
              else if (_error !=
                  null)
                SliverToBoxAdapter(
                  child:
                      _buildError(),
                )
              else if (_tracks
                  .isEmpty)
                const SliverToBoxAdapter(
                  child:
                      Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical:
                          70,
                    ),
                    child:
                        Column(
                      children: [
                        Icon(
                          Icons
                              .music_off_rounded,
                          color:
                              Colors.white24,
                          size:
                              55,
                        ),
                        SizedBox(
                          height:
                              12,
                        ),
                        Text(
                          'Sonuç bulunamadı',
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount:
                      _tracks.length,
                  separatorBuilder:
                      (
                    context,
                    index,
                  ) =>
                          const SizedBox(
                    height:
                        8,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final track =
                        _tracks[
                            index];

                    return Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            18,
                      ),
                      child:
                          _TrackTile(
                        track:
                            track,
                        onPlay:
                            () {
                          _listen(
                            track,
                          );
                        },
                        onDownload:
                            () {
                          _download(
                            track,
                          );
                        },
                      ),
                    );
                  },
                ),

              const SliverToBoxAdapter(
                child:
                    _DownloadsBanner(),
              ),

              const SliverToBoxAdapter(
                child:
                    SizedBox(
                  height:
                      125,
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
      child:
          Row(
        children: [
          Container(
            width:
                52,
            height:
                52,
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
            child:
                ClipOval(
              child:
                  Image.asset(
                'assets/images/b_music02_logo.png',
                fit:
                    BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(
            width:
                12,
          ),

          const Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'B_music02',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(
                  height:
                      2,
                ),
                Text(
                  'Müzik her yerde',
                  style:
                      TextStyle(
                    color:
                        Colors.white38,
                    fontSize:
                        10,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width:
                43,
            height:
                43,
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
                    Colors.white10,
              ),
            ),
            child:
                const Icon(
              Icons
                  .headphones_rounded,
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
        20,
        22,
        20,
        0,
      ),
      child:
          Column(
        children: [
          const Text(
            'Müzik İndir',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize:
                  36,
              fontWeight:
                  FontWeight.w900,
              letterSpacing:
                  -1.5,
            ),
          ),

          const SizedBox(
            height:
                4,
          ),

          const Text(
            'SEVDİĞİN MÜZİK HER ZAMAN SENİNLE',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white38,
              fontSize:
                  8,
              letterSpacing:
                  2.2,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height:
                22,
          ),

          Container(
            height:
                58,
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
            child:
                TextField(
              controller:
                  _searchController,
              onChanged:
                  _onSearchChanged,
              onSubmitted:
                  (_) {
                _performSearch();
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
                    'Şarkı, sanatçı veya albüm ara...',
                hintStyle:
                    const TextStyle(
                  color:
                      Colors.white38,
                  fontSize:
                      13,
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

                              _performSearch();
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
      height:
          72,
      child:
          ListView.separated(
        padding:
            const EdgeInsets
                .symmetric(
          horizontal:
              20,
          vertical:
              15,
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
          width:
              9,
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
            onTap:
                () {
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
                horizontal:
                    19,
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
              child:
                  Text(
                item,
                style:
                    TextStyle(
                  color:
                      selected
                          ? Colors.black
                          : Colors.white,
                  fontSize:
                      13,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatured() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        20,
        0,
        20,
        24,
      ),
      child:
          Container(
        height:
            180,
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            27,
          ),
          border:
              Border.all(
            color:
                AppColors.gold
                    .withOpacity(
              0.4,
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
                0xFF0D0D0D,
              ),
              Color(
                0xFF181208,
              ),
            ],
          ),
        ),
        child:
            Stack(
          children: [
            Positioned(
              right:
                  -30,
              top:
                  -25,
              child:
                  Container(
                width:
                    170,
                height:
                    170,
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
                    width:
                        24,
                  ),
                ),
                child:
                    const Center(
                  child:
                      Icon(
                    Icons
                        .music_note_rounded,
                    color:
                        AppColors.gold,
                    size:
                        58,
                  ),
                ),
              ),
            ),

            const Padding(
              padding:
                  EdgeInsets.all(
                21,
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons
                            .workspace_premium_rounded,
                        color:
                            AppColors.gold,
                        size:
                            18,
                      ),
                      SizedBox(
                        width:
                            7,
                      ),
                      Text(
                        'JAMENDO MÜZİK',
                        style:
                            TextStyle(
                          color:
                              AppColors.gold,
                          fontSize:
                              9,
                          letterSpacing:
                              2,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(
                    height:
                        13,
                  ),

                  Text(
                    'Keşfet, Dinle\nve İndir',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          26,
                      height:
                          1.05,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  SizedBox(
                    height:
                        9,
                  ),

                  Text(
                    'Sanatçının indirmeye izin\nverdiği müzikleri keşfet.',
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                      fontSize:
                          10,
                      height:
                          1.4,
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

  Widget _buildSectionTitle() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        20,
        0,
        20,
        13,
      ),
      child:
          Row(
        children: [
          const Expanded(
            child:
                Text(
              'Müzikler',
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize:
                    22,
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
                fontSize:
                    10,
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
        vertical:
            65,
        horizontal:
            30,
      ),
      child:
          Column(
        children: [
          const Icon(
            Icons
                .cloud_off_rounded,
            color:
                Colors.white24,
            size:
                55,
          ),

          const SizedBox(
            height:
                13,
          ),

          Text(
            _error!,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Colors.white54,
            ),
          ),

          const SizedBox(
            height:
                12,
          ),

          TextButton(
            onPressed:
                _loadPopular,
            child:
                const Text(
              'Tekrar Dene',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile
    extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.onPlay,
    required this.onDownload,
  });

  final JamendoTrack track;

  final VoidCallback onPlay;

  final VoidCallback onDownload;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      minHeight:
          78,
      padding:
          const EdgeInsets.all(
        9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF121212,
        ),
        borderRadius:
            BorderRadius.circular(
          19,
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
      child:
          Row(
        children: [
          GestureDetector(
            onTap:
                onPlay,
            child:
                Stack(
              alignment:
                  Alignment.center,
              children: [
                _Cover(
                  url:
                      track.imageUrl,
                  size:
                      58,
                ),

                Container(
                  width:
                      31,
                  height:
                      31,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black
                            .withOpacity(
                      0.62,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons
                        .play_arrow_rounded,
                    color:
                        Colors.white,
                    size:
                        21,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        14,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  track.artist,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize:
                        11,
                  ),
                ),

                if (track.album
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        2,
                  ),

                  Text(
                    track.album,
                    maxLines:
                        1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white24,
                      fontSize:
                          9,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(
            width:
                8,
          ),

          Text(
            track.formattedDuration,
            style:
                const TextStyle(
              color:
                  Colors.white38,
              fontSize:
                  10,
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          GestureDetector(
            onTap:
                onDownload,
            child:
                Container(
              width:
                  44,
              height:
                  44,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    track.downloadAllowed
                        ? AppColors.gold
                            .withOpacity(
                            0.10,
                          )
                        : Colors.white
                            .withOpacity(
                            0.03,
                          ),
                border:
                    Border.all(
                  color:
                      track.downloadAllowed
                          ? AppColors.gold
                          : Colors.white12,
                ),
              ),
              child:
                  Icon(
                track.downloadAllowed
                    ? Icons
                        .download_rounded
                    : Icons
                        .lock_rounded,
                color:
                    track.downloadAllowed
                        ? AppColors.gold
                        : Colors.white30,
                size:
                    22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover
    extends StatelessWidget {
  const _Cover({
    required this.url,
    required this.size,
  });

  final String url;

  final double size;

  @override
  Widget build(
    BuildContext context,
  ) {
    if (url.isEmpty) {
      return _fallback();
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        size *
            0.22,
      ),
      child:
          Image.network(
        url,
        width:
            size,
        height:
            size,
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
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width:
          size,
      height:
          size,
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          size *
              0.22,
        ),
        gradient:
            const LinearGradient(
          colors: [
            Color(
              0xFF3B2910,
            ),
            Color(
              0xFF141414,
            ),
          ],
        ),
      ),
      child:
          Icon(
        Icons
            .music_note_rounded,
        color:
            AppColors.gold,
        size:
            size *
                0.48,
      ),
    );
  }
}

class _DownloadsBanner
    extends StatelessWidget {
  const _DownloadsBanner();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        24,
        18,
        0,
      ),
      child:
          Container(
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
        child:
            const Row(
          children: [
            Icon(
              Icons
                  .folder_rounded,
              color:
                  AppColors.gold,
              size:
                  37,
            ),

            SizedBox(
              width:
                  14,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'İndirilenler',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  SizedBox(
                    height:
                        3,
                  ),

                  Text(
                    'Uygulama içi indirme sistemi sonraki adımda bağlanacak.',
                    style:
                        TextStyle(
                      color:
                          Colors.white38,
                      fontSize:
                          9,
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
      ),
    );
  }
}
