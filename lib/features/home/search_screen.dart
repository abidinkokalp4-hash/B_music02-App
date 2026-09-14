import 'dart:async';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/search_history_service.dart';
import '../../core/services/wikimedia_music_service.dart';
import '../../core/services/youtube_music_service.dart';
import '../../core/theme/app_theme.dart';

enum _DurationFilter { all, short, long }

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
  final Map<String, int> _durations = <String, int>{};
  _DurationFilter _filter = _DurationFilter.all;

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
    _loadPersonalized();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _filterLabel {
    switch (_filter) {
      case _DurationFilter.short:
        return '3 dakika ve altı';
      case _DurationFilter.long:
        return '4 dakika ve üstü';
      case _DurationFilter.all:
        return 'Tümü';
    }
  }

  Future<void> _loadHistory() async {
    final values = await _history.recent(limit: 6);
    if (mounted) setState(() => _recentSearches = values);
  }

  Future<void> _loadPersonalized() async {
    if (mounted) setState(() => _loading = true);
    await _loadHistory();
    final seeds = _recentSearches.isEmpty
        ? <String>['Kürtçe müzik', 'pop music']
        : _recentSearches.take(3).toList();
    final merged = <String, YouTubeMusicItem>{};
    for (final seed in seeds) {
      try {
        final result = await _youtube.searchMusic('$seed music', maxResults: 8);
        for (final item in result.items) {
          merged[item.videoId] = item;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final values = merged.values.toList()..shuffle();
    setState(() {
      _items = values;
      _loading = false;
      _error = null;
    });
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _debounce = Timer(const Duration(milliseconds: 250), _loadPersonalized);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(value));
  }

  Future<void> _search(String query, {bool record = true}) async {
    final clean = query.trim();
    if (clean.isEmpty) return _loadPersonalized();
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
      if (_filter != _DurationFilter.all) await _loadDurations();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadDurations() async {
    for (final item in _items) {
      if (_durations.containsKey(item.videoId)) continue;
      try {
        final value = await _youtube.videoDurationSeconds(item.videoId);
        if (value != null) _durations[item.videoId] = value;
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  List<YouTubeMusicItem> get _visibleItems {
    if (_filter == _DurationFilter.all) return _items;
    return _items.where((item) {
      final seconds = _durations[item.videoId];
      if (seconds == null) return false;
      if (_filter == _DurationFilter.short) return seconds <= 180;
      return seconds >= 240;
    }).toList();
  }

  Future<void> _showFilter() async {
    final picked = await showModalBottomSheet<_DurationFilter>(
      context: context,
      backgroundColor: const Color(0xFF121420),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filterTile(c, _DurationFilter.all, 'Tümü'),
            _filterTile(c, _DurationFilter.short, '3 dakika ve altı'),
            _filterTile(c, _DurationFilter.long, '4 dakika ve üstü'),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _filter = picked);
    if (picked != _DurationFilter.all) await _loadDurations();
  }

  Widget _filterTile(BuildContext c, _DurationFilter value, String label) {
    return RadioListTile<_DurationFilter>(
      value: value,
      groupValue: _filter,
      activeColor: AppColors.neonPurple,
      title: Text(label),
      onChanged: (_) => Navigator.pop(c, value),
    );
  }

  Future<void> _playDirect(YouTubeMusicItem item) async {
    final song = _findLocalMatch(item);
    if (song == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu parçanın telefonda çalınabilir kopyası yok. İndir butonuyla izinli sürümü kitaplığa ekleyebilirsiniz.'),
        ),
      );
      return;
    }
    await _music.playSong(song, from: _music.songs);
  }

  SongModel? _findLocalMatch(YouTubeMusicItem item) {
    final wanted = _tokens('${_cleanTitle(item.title)} ${item.channelTitle}');
    SongModel? best;
    var score = 0;
    for (final song in _music.songs) {
      final current = wanted.intersection(_tokens('${song.title} ${song.artist ?? ''}')).length;
      if (current > score) {
        score = current;
        best = song;
      }
    }
    return score >= 2 ? best : null;
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu parça için indirilebilir izinli sürüm bulunamadı.')),
          );
        }
        return;
      }
      await _commons.downloadTrack(match);
      await _music.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${match.title} indirildi. Kitaplığım bölümünde.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İndirme tamamlanamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(item.videoId));
    }
  }

  String _cleanTitle(String value) => value
      .replaceAll(RegExp(r'\([^)]*(official|video|audio|lyrics?|klip)[^)]*\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[[^\]]*(official|video|audio|lyrics?|klip)[^\]]*\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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
    return PopScope(
      canPop: _controller.text.trim().isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _controller.text.trim().isNotEmpty) {
          _controller.clear();
          _changed('');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
            children: [
              SizedBox(
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text('Arama', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Positioned(
                      right: 4,
                      child: IconButton(
                        onPressed: _showFilter,
                        icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 25),
                      ),
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
                const _Heading('İlgini Çekebilir'),
                const SizedBox(height: 8),
                _recommendations(),
                const SizedBox(height: 18),
                const _Heading('Kategoriler'),
                const SizedBox(height: 10),
                _categoryGrid(),
              ] else ...[
                Row(
                  children: [
                    const Expanded(child: _Heading('Arama Sonuçları')),
                    Text(_filterLabel,
                        style: const TextStyle(color: AppColors.neonPurple, fontSize: 10)),
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
            onPressed: _controller.text.isEmpty
                ? _showFilter
                : () {
                    _controller.clear();
                    _changed('');
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

  Widget _recommendations() {
    if (_loading && _items.isEmpty) {
      return const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator(color: AppColors.neonPurple)),
      );
    }
    return Column(children: _visibleItems.take(4).map(_resultCard).toList());
  }

  Widget _resultCard(YouTubeMusicItem item) {
    final busy = _downloading.contains(item.videoId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF151724),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _playDirect(item),
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
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(item.channelTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Çal',
                  onPressed: () => _playDirect(item),
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPurple),
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
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: category.colors),
            ),
            child: Row(
              children: [
                Expanded(child: Text(category.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
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
    final visible = _visibleItems;
    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: Text('Sonuç bulunamadı')),
      );
    }
    return Column(children: visible.map(_resultCard).toList());
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
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800));
  }
}

class _SearchCategory {
  const _SearchCategory(this.label, this.query, this.colors);
  final String label;
  final String query;
  final List<Color> colors;
}
