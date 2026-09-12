import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/tiktok_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video_item.dart';
import '../requests/requests_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() =>
      _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TikTokService _tiktok =
      const TikTokService();

  final PageController _pageController =
      PageController();

  final List<VideoItem> _videos = [];

  final Map<int, WebViewController>
      _webControllers = {};

  final Map<int, double> _currentTimes = {};
  final Map<int, double> _durations = {};
  final Map<int, bool> _playing = {};

  final Set<String> _likedVideos = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _showHeart = false;

  int? _cursor;
  int _currentIndex = 0;
  int _heartAnimationId = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
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
            'Keşfet videoları yüklenemedi.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore ||
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
        for (final video in page.videos) {
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

  String _videoId(VideoItem video) {
    final urlMatch =
        RegExp(
      r'/video/(\d+)',
    ).firstMatch(
      video.tiktokUrl,
    );

    if (urlMatch != null) {
      return urlMatch.group(1)!;
    }

    final idMatch =
        RegExp(
      r'\d{8,}',
    ).firstMatch(
      video.id,
    );

    if (idMatch != null) {
      return idMatch.group(0)!;
    }

    return video.id;
  }

  String _buildPlayerHtml(
    VideoItem video,
  ) {
    final id = _videoId(video);

    return '''
<!DOCTYPE html>
<html>
<head>
<meta
  name="viewport"
  content="width=device-width,
  initial-scale=1.0,
  maximum-scale=1.0,
  user-scalable=no"
/>

<style>
html, body {
  margin: 0;
  padding: 0;
  background: #000000;
  width: 100%;
  height: 100%;
  overflow: hidden;
}

#player {
  position: fixed;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
  background: #000000;
}
</style>
</head>

<body>
<iframe
  id="player"
  src="https://www.tiktok.com/player/v1/$id?autoplay=1&loop=1&controls=0&progress_bar=0&play_button=0&volume_control=0&fullscreen_button=0&timestamp=0&music_info=0&description=0&rel=0&native_context_menu=0"
  allow="autoplay; encrypted-media; fullscreen"
></iframe>

<script>
const frame =
  document.getElementById('player');

window.sendTikTokCommand =
  function(command, value) {
    if (!frame ||
        !frame.contentWindow) {
      return;
    }

    const message = {
      type: command
    };

    if (value !== null &&
        value !== undefined) {
      message.value = value;
    }

    frame.contentWindow.postMessage(
      message,
      '*'
    );
  };

window.addEventListener(
  'message',
  function(event) {
    try {
      if (window.PlayerBridge) {
        PlayerBridge.postMessage(
          JSON.stringify(
            event.data
          )
        );
      }
    } catch (error) {}
  }
);
</script>
</body>
</html>
''';
  }

  WebViewController _controllerFor(
    int index,
    VideoItem video,
  ) {
    final existing =
        _webControllers[index];

    if (existing != null) {
      return existing;
    }

    late final WebViewController controller;

    controller =
        WebViewController()
          ..setJavaScriptMode(
            JavaScriptMode.unrestricted,
          )
          ..setBackgroundColor(
            Colors.black,
          )
          ..addJavaScriptChannel(
            'PlayerBridge',
            onMessageReceived:
                (message) {
              _handlePlayerMessage(
                index,
                message.message,
              );
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished:
                  (_) async {
                if (index ==
                    _currentIndex) {
                  await Future.delayed(
                    const Duration(
                      milliseconds: 400,
                    ),
                  );

                  await _sendCommand(
                    index,
                    'unMute',
                  );

                  await _sendCommand(
                    index,
                    'play',
                  );
                }
              },
            ),
          )
          ..loadHtmlString(
            _buildPlayerHtml(video),
          );

    _webControllers[index] =
        controller;

    _playing[index] = true;

    return controller;
  }

  Future<void> _sendCommand(
    int index,
    String command, [
    dynamic value,
  ]) async {
    final controller =
        _webControllers[index];

    if (controller == null) {
      return;
    }

    try {
      final commandJson =
          jsonEncode(command);

      final valueJson =
          value == null
              ? 'null'
              : jsonEncode(value);

      await controller.runJavaScript(
        '''
window.sendTikTokCommand(
  $commandJson,
  $valueJson
);
''',
      );
    } catch (_) {}
  }

  void _handlePlayerMessage(
    int index,
    String rawMessage,
  ) {
    try {
      final decoded =
          jsonDecode(rawMessage);

      if (decoded is! Map) {
        return;
      }

      final data =
          Map<String, dynamic>.from(
        decoded,
      );

      final type =
          data['type']
              ?.toString();

      if (type ==
          'onStateChange') {
        final value =
            data['value'];

        bool playing =
            _playing[index] ??
                true;

        if (value is num) {
          playing =
              value.toInt() == 1;
        } else {
          final text =
              value
                  ?.toString()
                  .toLowerCase();

          if (text == 'playing' ||
              text == 'play') {
            playing = true;
          }

          if (text == 'paused' ||
              text == 'pause') {
            playing = false;
          }
        }

        if (!mounted) return;

        setState(() {
          _playing[index] =
              playing;
        });

        return;
      }

      if (type ==
          'onCurrentTime') {
        final value =
            data['value'];

        double? current;
        double? duration;

        if (value is Map) {
          final map =
              Map<String, dynamic>.from(
            value,
          );

          current =
              _toDouble(
            map['currentTime'],
          );

          duration =
              _toDouble(
            map['duration'],
          );
        }

        current ??=
            _toDouble(
          data['currentTime'],
        );

        duration ??=
            _toDouble(
          data['duration'],
        );

        if (!mounted) return;

        setState(() {
          if (current != null) {
            _currentTimes[index] =
                current!;
          }

          if (duration != null &&
              duration! > 0) {
            _durations[index] =
                duration!;
          }
        });
      }
    } catch (_) {}
  }

  double? _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  Future<void> _togglePlayback(
    int index,
  ) async {
    final isPlaying =
        _playing[index] ??
            true;

    if (isPlaying) {
      await _sendCommand(
        index,
        'pause',
      );

      if (!mounted) return;

      setState(() {
        _playing[index] = false;
      });
    } else {
      await _sendCommand(
        index,
        'play',
      );

      if (!mounted) return;

      setState(() {
        _playing[index] = true;
      });
    }
  }

  Future<void> _seekRelative(
    int index,
    double seconds,
  ) async {
    final current =
        _currentTimes[index] ?? 0;

    final duration =
        _durations[index] ?? 0;

    var target =
        current + seconds;

    if (target < 0) {
      target = 0;
    }

    if (duration > 0 &&
        target > duration) {
      target = duration;
    }

    setState(() {
      _currentTimes[index] =
          target;
    });

    await _sendCommand(
      index,
      'seekTo',
      target,
    );
  }

  Future<void> _seekTo(
    int index,
    double value,
  ) async {
    setState(() {
      _currentTimes[index] =
          value;
    });

    await _sendCommand(
      index,
      'seekTo',
      value,
    );
  }

  void _toggleLike(
    VideoItem video,
  ) {
    setState(() {
      if (_likedVideos
          .contains(video.id)) {
        _likedVideos.remove(
          video.id,
        );
      } else {
        _likedVideos.add(
          video.id,
        );
      }
    });
  }

  Future<void> _doubleTapLike(
    VideoItem video,
  ) async {
    setState(() {
      _likedVideos.add(
        video.id,
      );

      _showHeart = true;
      _heartAnimationId++;
    });

    await Future.delayed(
      const Duration(
        milliseconds: 720,
      ),
    );

    if (!mounted) return;

    setState(() {
      _showHeart = false;
    });
  }

  Future<void> _changePage(
    int index,
  ) async {
    final previous =
        _currentIndex;

    if (previous != index) {
      await _sendCommand(
        previous,
        'pause',
      );
    }

    setState(() {
      _currentIndex = index;
      _showHeart = false;
    });

    await Future.delayed(
      const Duration(
        milliseconds: 250,
      ),
    );

    await _sendCommand(
      index,
      'unMute',
    );

    await _sendCommand(
      index,
      'play',
    );

    if (mounted) {
      setState(() {
        _playing[index] = true;
      });
    }

    if (index >=
            _videos.length - 3 &&
        _hasMore) {
      _loadMore();
    }
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

  void _commentInfo() {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Yorum sistemi sonraki aşamada bağlanacak.',
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Scaffold(
        backgroundColor:
            Colors.black,
        body: Center(
          child:
              CircularProgressIndicator(
            color:
                AppColors.gold,
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor:
            Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons
                      .wifi_off_rounded,
                  color:
                      Colors.white54,
                  size: 48,
                ),
                const SizedBox(
                  height: 12,
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
                  height: 10,
                ),
                TextButton(
                  onPressed:
                      _loadVideos,
                  child:
                      const Text(
                    'Tekrar Dene',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Scaffold(
        backgroundColor:
            Colors.black,
        body: Center(
          child: Text(
            'Video bulunamadı.',
            style:
                TextStyle(
              color:
                  Colors.white70,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          Colors.black,
      body: PageView.builder(
        controller:
            _pageController,
        scrollDirection:
            Axis.vertical,
        itemCount:
            _videos.length,
        onPageChanged:
            _changePage,
        itemBuilder:
            (
          context,
          index,
        ) {
          return _buildVideoPage(
            index,
            _videos[index],
          );
        },
      ),
    );
  }

  Widget _buildVideoPage(
    int index,
    VideoItem video,
  ) {
    final controller =
        _controllerFor(
      index,
      video,
    );

    final current =
        _currentTimes[index] ?? 0;

    final duration =
        _durations[index] ?? 0;

    final playing =
        _playing[index] ?? true;

    final liked =
        _likedVideos.contains(
      video.id,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color:
              Colors.black,
        ),

        WebViewWidget(
          controller:
              controller,
        ),

        Positioned.fill(
          child: GestureDetector(
            behavior:
                HitTestBehavior
                    .translucent,
            onTap: () {
              _togglePlayback(
                index,
              );
            },
            onDoubleTap: () {
              _doubleTapLike(
                video,
              );
            },
            child:
                const SizedBox.expand(),
          ),
        ),

        IgnorePointer(
          child: AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            child:
                _showHeart &&
                        index ==
                            _currentIndex
                    ? Center(
                        key: ValueKey(
                          _heartAnimationId,
                        ),
                        child:
                            TweenAnimationBuilder<
                                double>(
                          duration:
                              const Duration(
                            milliseconds:
                                280,
                          ),
                          tween:
                              Tween(
                            begin: 0.3,
                            end: 1.15,
                          ),
                          curve:
                              Curves
                                  .elasticOut,
                          builder:
                              (
                            context,
                            scale,
                            child,
                          ) {
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child:
                              const Icon(
                            Icons
                                .favorite_rounded,
                            color:
                                Color(
                              0xFFFF335D,
                            ),
                            size: 112,
                            shadows: [
                              Shadow(
                                color:
                                    Colors.black54,
                                blurRadius:
                                    25,
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox
                        .shrink(),
          ),
        ),

        Positioned(
          top:
              MediaQuery.of(
                    context,
                  ).padding.top +
                  12,
          left: 18,
          child:
              const Text(
            'Keşfet',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 22,
              fontWeight:
                  FontWeight.w900,
              shadows: [
                Shadow(
                  color:
                      Colors.black87,
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),

        Positioned(
          right: 13,
          bottom: 150,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                padding:
                    const EdgeInsets.all(
                  3,
                ),
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  border:
                      Border.all(
                    color:
                        AppColors.gold,
                    width: 2,
                  ),
                  color:
                      Colors.black54,
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
                height: 18,
              ),

              _ActionButton(
                icon:
                    liked
                        ? Icons
                            .favorite_rounded
                        : Icons
                            .favorite_border_rounded,
                iconColor:
                    liked
                        ? const Color(
                            0xFFFF335D,
                          )
                        : Colors.white,
                label:
                    liked
                        ? 'Beğenildi'
                        : 'Beğen',
                onTap: () {
                  _toggleLike(
                    video,
                  );
                },
              ),

              const SizedBox(
                height: 17,
              ),

              _ActionButton(
                icon:
                    Icons
                        .chat_bubble_rounded,
                label:
                    'Yorum',
                onTap:
                    _commentInfo,
              ),

              const SizedBox(
                height: 17,
              ),

              _ActionButton(
                icon:
                    Icons
                        .music_note_rounded,
                label:
                    'İstek',
                onTap:
                    _openRequests,
              ),
            ],
          ),
        ),

        Positioned(
          left: 16,
          right: 78,
          bottom: 112,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                '@b_music02',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w900,
                  shadows: [
                    Shadow(
                      color:
                          Colors.black,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                video.title,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 12,
                  height: 1.35,
                  shadows: [
                    Shadow(
                      color:
                          Colors.black,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          left: 14,
          right: 14,
          bottom: 20,
          child: _VideoControls(
            current: current,
            duration: duration,
            playing: playing,
            onSeek: (
              value,
            ) {
              _seekTo(
                index,
                value,
              );
            },
            onBack: () {
              _seekRelative(
                index,
                -10,
              );
            },
            onPlayPause: () {
              _togglePlayback(
                index,
              );
            },
            onForward: () {
              _seekRelative(
                index,
                10,
              );
            },
          ),
        ),

        if (_loadingMore &&
            index ==
                _videos.length - 1)
          const Positioned(
            top: 50,
            right: 20,
            child: SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color:
                    AppColors.gold,
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.current,
    required this.duration,
    required this.playing,
    required this.onSeek,
    required this.onBack,
    required this.onPlayPause,
    required this.onForward,
  });

  final double current;
  final double duration;
  final bool playing;

  final ValueChanged<double> onSeek;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onForward;

  @override
  Widget build(
    BuildContext context,
  ) {
    final safeDuration =
        duration > 0
            ? duration
            : 1;

    final safeCurrent =
        current.clamp(
      0,
      safeDuration,
    ).toDouble();

    return Container(
      padding:
          const EdgeInsets
              .fromLTRB(
        12,
        5,
        12,
        10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.black
                .withOpacity(
          0.52,
        ),
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        border:
            Border.all(
          color:
              Colors.white
                  .withOpacity(
            0.10,
          ),
        ),
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          SliderTheme(
            data:
                SliderTheme.of(
              context,
            ).copyWith(
              trackHeight: 2.5,
              thumbShape:
                  const RoundSliderThumbShape(
                enabledThumbRadius: 5,
              ),
              overlayShape:
                  const RoundSliderOverlayShape(
                overlayRadius: 12,
              ),
              activeTrackColor:
                  AppColors.gold,
              inactiveTrackColor:
                  Colors.white24,
              thumbColor:
                  AppColors.gold,
              overlayColor:
                  AppColors.gold
                      .withOpacity(
                0.15,
              ),
            ),
            child: Slider(
              min: 0,
              max: safeDuration,
              value: safeCurrent,
              onChanged:
                  duration > 0
                      ? onSeek
                      : null,
            ),
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon:
                    Icons
                        .replay_10_rounded,
                onTap: onBack,
              ),

              const SizedBox(
                width: 25,
              ),

              GestureDetector(
                onTap:
                    onPlayPause,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        AppColors.gold,
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppColors.gold
                                .withOpacity(
                          0.28,
                        ),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Icon(
                    playing
                        ? Icons
                            .pause_rounded
                        : Icons
                            .play_arrow_rounded,
                    color:
                        Colors.black,
                    size: 29,
                  ),
                ),
              ),

              const SizedBox(
                width: 25,
              ),

              _ControlButton(
                icon:
                    Icons
                        .forward_10_rounded,
                onTap: onForward,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              Colors.white
                  .withOpacity(
            0.10,
          ),
          border:
              Border.all(
            color:
                Colors.white12,
          ),
        ),
        child: Icon(
          icon,
          color:
              Colors.white,
          size: 23,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor =
        Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  Colors.black
                      .withOpacity(
                0.48,
              ),
              border:
                  Border.all(
                color:
                    Colors.white
                        .withOpacity(
                  0.12,
                ),
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 25,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            label,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 8,
              fontWeight:
                  FontWeight.w700,
              shadows: [
                Shadow(
                  color:
                      Colors.black,
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
