import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/search_history_service.dart';
import '../../core/services/wikimedia_music_service.dart';
import '../../core/services/youtube_music_service.dart';
import '../../core/theme/app_theme.dart';
import 'youtube_player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _youtube = const YouTubeMusicService();
  final _commons = const WikimediaMusicService();
  final _history = SearchHistoryService.instance;
  final _controller = TextEditingController();
  final _music = LocalMusicService.instance;

  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<YouTubeMusicItem> _items = const [];
  List<String> _recentSearches = const [];
  final Set<String> _downloading = <String>{};

  static const _categories = <_SearchCategory>[
    _SearchCategory('Pop', 'pop music', [Color(0xFFD13AC8), Color(0xFF8E28DD)]),
    _SearchCategory('Elektronik', 'electronic music', [Color(0xFF2D75EF), Color(0xFF1747A9)]),
    _SearchCategory('Hiphop', 'hip hop music', [Color(0xFF7634EE), Color(0xFF4318B9)]),
    _SearchCategory('Rock', 'rock music', [Color(0xFFE04461), Color(0xFFB32045)]),
    _SearchCategory('R&B', 'r&b music', [Color(0xFFD4319A), Color(0xFF8D1B92)]),
    _SearchCategory('Kürtçe', 'Kürtçe müzik', [Color(0xFF1EAAC3), Color(0xFF0A7188)]),
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _search('popular music', record: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final values = await _history.recent(limit: 5);
    if (mounted) setState(() => _recentSearches = values);
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      Duration(milliseconds: value.trim().isEmpty ? 300 : 650),
      () => _search(value.trim().isEmpty ? 'popular music' : value,
          record: value.trim().isNotEmpty),
    );
  }

  Future<void> _search(String query, {bool record = true}) async {
    if (!mounted) return;
    final clean = query.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _youtube.searchMusic(clean, maxResults: 20);
      if (record) {
        await _history.record(clean);
        await _loadHistory();
      }
      if (!mounted) return;
      setState(() {
        _items = result.items;
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

  Future<void> _open(YouTubeMusicItem item) async {
    await _music.pause();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => YouTubePlayerScreen(item: item)),
    );
  }

  Future<void> _download(YouTubeMusicItem item) async {
    if (_downloading.contains(item.videoId)) return;
    setState(() => _downloading.add(item.videoId));

    try {
      var candidates = await _commons.searchMusic(
        '${_cleanTitle(item.title)} ${item.channelTitle}',
        limit: 20,
      );
      candidates = candidates.where((track) => track.canDownload).toList();

      if (candidates.isEmpty) {
        candidates = (await _commons.searchMusic(_cleanTitle(item.title), limit: 25))
            .where((track) => track.canDownload)
            .toList();
      }

      final match = _bestMatch(item, candidates);
      if (match == null || _matchScore(item, match) < 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu parça için indirilebilir izinli sürüm bulunamadı.'),
          ),
        );
        return;
      }

      await _commons.downloadTrack(match);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${match.title} indirildi. Kitaplığım > İndirilenler bölümünde.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İndirme tamamlanamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading.remove(item.videoId));
    }
  }

  String _cleanTitle(String value) {
    return value
        .replaceAll(RegExp(r'\([^)]*(official|video|audio|lyrics?|klip)[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[[^\]]*(official|video|audio|lyrics?|klip)[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _matchScore(YouTubeMusicItem item, CommonsTrack track) {
    final wanted = _tokens('${_cleanTitle(item.title)} ${item.channelTitle}');
    final got = _tokens('${track.title} ${track.artist}');
    return wanted.where(got.contains).length;
  }

  CommonsTrack? _bestMatch(YouTubeMusicItem item, List<CommonsTrack> tracks) {
    if (tracks.isEmpty) return null;
    tracks.sort((a, b) => _matchScore(item, b).compareTo(_matchScore(item, a)));
    return tracks.first;
  }

  Set<String> _tokens(String value) {
    const ignored = <String>{
      'official', 'video', 'audio', 'music', 'lyrics', 'lyric', 'klip', 'vevo',
      'feat', 'ft', 'the', 'and', 'bir', 'ile'
    };
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9çğıöşüâîû]+', unicode: true), ' ')
        .split(' ')
        .where((e) => e.length > 1 && !ignored.contains(e))
        .toSet();
  }

  Future<void> _selectCategory(_SearchCategory category) async {
    _controller.text = category.label;
    setState(() {});
    await _search(category.query);
  }

  Future<void> _selectRecent(String query) async {
    _controller.text = query;
    setState(() {});
    await _search(query);
  }

  bool get _isBrowsing => _controller.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
          children: [
            const SizedBox(
              height: 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text('Arama', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Positioned(
                    right: 4,
                    child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 25),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _searchField(),
            const SizedBox(height: 18),
            if (_isBrowsing) ...[
              if (_recentSearches.isNotEmpty) ...[
                const _Heading('Son Aramaların'),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recentSearches
                      .map((q) => ActionChip(
                            avatar: const Icon(Icons.history_rounded, size: 17),
                            label: Text(q),
                            onPressed: () => _selectRecent(q),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
              ],
              const _Heading('Popüler Aramalar'),
              const SizedBox(height: 8),
              _popularSearches(),
              const SizedBox(height: 18),
              const _Heading('Kategoriler'),
              const SizedBox(height: 10),
              _categoryGrid(),
            ] else ...[
              Row(
                children: [
                  const Expanded(child: _Heading('Arama Sonuçları')),
                  TextButton(
                    onPressed: () {
                      _controller.clear();
                      _changed('');
                    },
                    child: const Text('Temizle'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _results(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 51,
      decoration: BoxDecoration(
        color: const Color(0xFF151724),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF2A2D40)),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) _search(value);
        },
        decoration: InputDecoration(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'Sanatçı, şarkı veya müzik ara',
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC8CAD6)),
          suffixIcon: IconButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                _controller.clear();
                _changed('');
              }
            },
            icon: Icon(
              _controller.text.isEmpty ? Icons.tune_rounded : Icons.close_rounded,
              color: const Color(0xFFC8CAD6),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _popularSearches() {
    if (_loading && _items.isEmpty) {
      return const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator(color: AppColors.neonPurple)),
      );
    }
    return Column(
      children: _items.take(3).map((item) => _resultCard(item)).toList(),
    );
  }

  Widget _resultCard(YouTubeMusicItem item) {
    final busy = _downloading.contains(item.videoId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF151724),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _open(item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                _thumb(item, 50),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Çal',
                  onPressed: () => _open(item),
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.neonPurple,
                          ),
                        )
                      : IconButton(
                          tooltip: 'İndir',
                          onPressed: () => _download(item),
                          icon: const Icon(Icons.download_rounded, color: AppColors.neonPurple),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, index) {
        final category = _categories[index];
        return InkWell(
          onTap: () => _selectCategory(category),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: category.colors,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _results() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(child: CircularProgressIndicator(color: AppColors.neonPurple)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text(_error!, style: const TextStyle(color: Colors.white54)),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: Text('Sonuç bulunamadı')),
      );
    }
    return Column(children: _items.map(_resultCard).toList());
  }

  Widget _thumb(YouTubeMusicItem item, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.network(
        item.thumbnailUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF231646),
          child: const Icon(Icons.music_note_rounded, color: AppColors.neonPurple),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));
  }
}

class _SearchCategory {
  const _SearchCategory(this.label, this.query, this.colors);
  final String label;
  final String query;
  final List<Color> colors;
}
