import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/story_service.dart';
import '../../core/services/youtube_music_service.dart';
import '../../core/theme/app_theme.dart';
import '../home/youtube_player_screen.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<MusicStory> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late int _index;
  Timer? _timer;
  int _tick = 0;

  MusicStory get _story => widget.stories[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1).toInt();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _tick = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _tick++);
      if (_tick >= 15) _next();
    });
  }

  void _next() {
    if (_index + 1 >= widget.stories.length) {
      Navigator.pop(context);
      return;
    }
    setState(() => _index++);
    _startTimer();
  }

  void _previous() {
    if (_index <= 0) return;
    setState(() => _index--);
    _startTimer();
  }

  YouTubeMusicItem _itemFor(MusicStory story) {
    return YouTubeMusicItem(
      videoId: story.videoId,
      title: story.title,
      channelTitle: story.artist,
      thumbnailUrl: story.thumbnailUrl,
      publishedAt: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final item = _itemFor(story);
    final progress = (_tick / 15).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (story.thumbnailUrl.isNotEmpty)
              Image.network(
                story.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: AppColors.background),
              )
            else
              const ColoredBox(color: AppColors.background),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Color(0x33000000),
                    Color(0xDD000000),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      widget.stories.length,
                      (i) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          decoration: BoxDecoration(
                            color: i < _index
                                ? Colors.white
                                : i == _index
                                    ? Color.lerp(
                                        Colors.white24,
                                        Colors.white,
                                        progress,
                                      )
                                    : Colors.white24,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: const Color(0xFF23163F),
                        backgroundImage: story.avatarUrl.isEmpty
                            ? null
                            : NetworkImage(story.avatarUrl),
                        child: story.avatarUrl.isEmpty
                            ? Text(
                                story.profileName.isEmpty
                                    ? 'B'
                                    : story.profileName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.profileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              '24 saatlik müzik hikâyesi',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: YouTubePlayerScreen(
                        key: ValueKey('${story.id}-${story.startSecond}'),
                        item: item,
                        startSecond: story.startSecond,
                        endSecond: story.startSecond + 15,
                        compact: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    story.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    story.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 90,
              bottom: 120,
              width: 58,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _previous,
              ),
            ),
            Positioned(
              right: 0,
              top: 90,
              bottom: 120,
              width: 58,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
