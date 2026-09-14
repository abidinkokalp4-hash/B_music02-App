import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/story_service.dart';
import '../../core/services/youtube_music_service.dart';
import '../../core/theme/app_theme.dart';
import '../home/youtube_player_screen.dart';

class StoryComposerScreen extends StatefulWidget {
  const StoryComposerScreen({super.key});

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  final _youtube = const YouTubeMusicService();
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<YouTubeMusicItem> _items = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _youtube.searchMusic(query, maxResults: 15);
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

  Future<void> _choose(YouTubeMusicItem item) async {
    setState(() => _loading = true);
    final seconds = await _youtube.videoDurationSeconds(item.videoId);
    if (!mounted) return;
    setState(() => _loading = false);

    final total = (seconds ?? 180).clamp(15, 7200).toInt();
    final maxStart = total <= 15 ? 0 : total - 15;
    double start = 0;

    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final startInt = start.round().clamp(0, maxStart).toInt();
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF11131F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2C2F45)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.thumbnailUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: const Color(0xFF21183F),
                              child: const Icon(Icons.music_note_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.channelTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '15 saniyelik bölümü seç',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_time(startInt)} – ${_time(startInt + 15)}',
                      style: const TextStyle(
                        color: AppColors.neonPurple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Slider(
                      value: start.clamp(0.0, maxStart.toDouble()).toDouble(),
                      min: 0,
                      max: maxStart <= 0 ? 1 : maxStart.toDouble(),
                      activeColor: AppColors.neonPurple,
                      onChanged: maxStart <= 0
                          ? null
                          : (value) => setSheetState(() => start = value),
                    ),
                    const SizedBox(height: 6),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: YouTubePlayerScreen(
                          key: ValueKey('${item.videoId}-$startInt'),
                          item: item,
                          startSecond: startInt,
                          endSecond: startInt + 15,
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, startInt),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Bu Bölümü Hikâye Yap'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await StoryService.instance.createStory(
        videoId: item.videoId,
        title: item.title,
        artist: item.channelTitle,
        thumbnailUrl: item.thumbnailUrl,
        startSecond: selected,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hikâye paylaşılamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _time(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Müzik Hikâyesi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              onChanged: _changed,
              onSubmitted: (value) {
                if (value.trim().length >= 2) _search(value);
              },
              decoration: const InputDecoration(
                hintText: 'Hikâyeye eklemek istediğin şarkıyı ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(color: AppColors.neonPurple),
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : _items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                            'Şarkı ara, istediğin 15 saniyelik bölümü seç ve 24 saatlik hikâye olarak paylaş.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            onTap: _loading ? null : () => _choose(item),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(
                                item.thumbnailUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 52,
                                  height: 52,
                                  color: const Color(0xFF21183F),
                                  child: const Icon(Icons.music_note_rounded),
                                ),
                              ),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.channelTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
