import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/services/tiktok_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video_item.dart';
import '../requests/requests_screen.dart';

String _getTikTokVideoId(VideoItem video) {
  final fromUrl =
      RegExp(r'/video/(\d+)').firstMatch(video.tiktokUrl);

  if (fromUrl != null) {
    return fromUrl.group(1)!;
  }

  final fromId =
      RegExp(r'\d{8,}').firstMatch(video.id);

  if (fromId != null) {
    return fromId.group(0)!;
  }

  return video.id;
}

String _buildTikTokHtml(VideoItem video) {
  final id = _getTikTokVideoId(video);

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
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: #000000;
}

#player {
  position: fixed;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
  margin: 0;
  padding: 0;
  background: #000000;
}
</style>
</head>

<body>

<iframe
  id="player"
  src="https://www.tiktok.com/player/v1/$id?autoplay=0&loop=1&controls=0&progress_bar=0&play_button=0&volume_control=0&fullscreen_button=0&timestamp=0&music_info=0&description=0&rel=0&native_context_menu=0"
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
      type: command,
      "x-tiktok-player": true
    };

    if (
      value !== null &&
      value !== undefined
    ) {
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
      if (
        event.data &&
        event.data["x-tiktok-player"] &&
        window.PlayerBridge
      ) {
        PlayerBridge.postMessage(
          JSON.stringify(event.data)
        );
      }
    } catch (_) {}
  }
);
</script>

</body>
</html>
''';
}

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
  final TikTokService _tiktok =
      const TikTokService();

  final PageController _pageController =
      PageController();

  final List<VideoItem> _videos = [];

  final Map<int, WebViewController>
      _controllers = {};

  final Map<int, double>
      _currentTimes = {};

  final Map<int, double>
      _durations = {};

  final Map<int, bool>
      _playing = {};

  final Map<int, bool>
      _muted = {};

  final Set<int> _seeking = {};

  final Set<String> _liked = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int? _cursor;
  int _currentIndex = 0;

  String? _error;

  bool _showHeart = false;

  IconData? _gestureIcon;
  String? _gestureText;

  Timer? _gestureTimer;
  Timer? _heartTimer;

  @override
  void initState() {
    super.initState();

    _loadVideos();
  }

  @override
  void dispose() {
    _gestureTimer?.cancel();
    _heartTimer?.cancel();

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

  WebViewController _controllerFor(
    int index,
    VideoItem video,
  ) {
    final old =
        _controllers[index];

    if (old != null) {
      return old;
    }

    final controller =
        WebViewController();

    _controllers[index] =
        controller;

    _playing[index] = false;
    _muted[index] = true;

    unawaited(
      _prepareController(
        index,
        controller,
        video,
      ),
    );

    return controller;
  }

  Future<void> _prepareController(
    int index,
    WebViewController controller,
    VideoItem video,
  ) async {
    await controller.setJavaScriptMode(
      JavaScriptMode.unrestricted,
    );

    await controller.setBackgroundColor(
      Colors.black,
    );

    if (controller.platform
        is AndroidWebViewController) {
      final androidController =
          controller.platform
              as AndroidWebViewController;

      await androidController
          .setMediaPlaybackRequiresUserGesture(
        false,
      );
    }

    await controller.addJavaScriptChannel(
      'PlayerBridge',
      onMessageReceived: (
        message,
      ) {
        _handlePlayerMessage(
          index,
          message.message,
        );
      },
    );

    await controller.loadHtmlString(
      _buildTikTokHtml(video),
    );
  }

  Future<void> _sendCommand(
    int index,
    String command, [
    dynamic value,
  ]) async {
    final controller =
        _controllers[index];

    if (controller == null) {
      return;
    }

    final commandJson =
        jsonEncode(command);

    final valueJson =
        value == null
            ? 'null'
            : jsonEncode(value);

    try {
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

  Future<void> _startWithSound(
    int index,
  ) async {
    await _sendCommand(
      index,
      'unMute',
    );

    await Future.delayed(
      const Duration(
        milliseconds: 100,
      ),
    );

    await _sendCommand(
      index,
      'play',
    );

    await Future.delayed(
      const Duration(
        milliseconds: 160,
      ),
    );

    await _sendCommand(
      index,
      'unMute',
    );

    if (!mounted) return;

    setState(() {
      _playing[index] = true;
    });
  }

  void _handlePlayerMessage(
    int index,
    String raw,
  ) {
    try {
      final decoded =
          jsonDecode(raw);

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
          'onPlayerReady') {
        if (index ==
            _currentIndex) {
          unawaited(
            _startWithSound(
              index,
            ),
          );
        }

        return;
      }

      if (type ==
          'onStateChange') {
        final value =
            data['value'];

        if (value is num) {
          final state =
              value.toInt();

          if (mounted) {
            setState(() {
              _playing[index] =
                  state == 1;
            });
          }

          if (state == 1) {
            _seeking.remove(
              index,
            );
          }
        }

        return;
      }

      if (type ==
          'onMute') {
        final value =
            data['value'];

        if (value is bool) {
          _muted[index] =
              value;
        }

        return;
      }

      if (type ==
          'onCurrentTime') {
        final value =
            data['value'];

        if (value is Map) {
          final map =
              Map<String, dynamic>.from(
            value,
          );

          final current =
              _asDouble(
            map['currentTime'],
          );

          final duration =
              _asDouble(
            map['duration'],
          );

          if (current != null) {
            _currentTimes[index] =
                current;
          }

          if (duration != null &&
              duration > 0.0) {
            _durations[index] =
                duration;
          }
        }

        return;
      }
    } catch (_) {}
  }

  double? _asDouble(
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
    await _sendCommand(
      index,
      'unMute',
    );

    final playing =
        _playing[index] ??
            false;

    if (playing) {
      await _sendCommand(
        index,
        'pause',
      );

      if (mounted) {
        setState(() {
          _playing[index] =
              false;
        });
      }

      _showGesture(
        Icons.pause_rounded,
      );
    } else {
      await _sendCommand(
        index,
        'play',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 80,
        ),
      );

      await _sendCommand(
        index,
        'unMute',
      );

      if (mounted) {
        setState(() {
          _playing[index] =
              true;
        });
      }

      _showGesture(
        Icons.play_arrow_rounded,
      );
    }
  }

  Future<void> _seek(
    int index,
    double seconds,
  ) async {
    if (_seeking.contains(index)) {
      return;
    }

    final current =
        _currentTimes[index];

    if (current == null) {
      return;
    }

    _seeking.add(index);

    final wasPlaying =
        _playing[index] ??
            true;

    final duration =
        _durations[index] ??
            0.0;

    double target =
        current + seconds;

    if (target < 0.0) {
      target = 0.0;
    }

    if (duration > 0.0 &&
        target > duration) {
      target = duration;
    }

    _currentTimes[index] =
        target;

    await _sendCommand(
      index,
      'seekTo',
      target,
    );

    if (seconds > 0.0) {
      _showGesture(
        Icons.forward_5_rounded,
        '+5 sn',
      );
    } else {
      _showGesture(
        Icons.replay_5_rounded,
        '-5 sn',
      );
    }

    await Future.delayed(
      const Duration(
        milliseconds: 260,
      ),
    );

    await _sendCommand(
      index,
      'unMute',
    );

    if (wasPlaying) {
      await _sendCommand(
        index,
        'play',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 250,
        ),
      );

      await _sendCommand(
        index,
        'play',
      );
    }

    Future.delayed(
      const Duration(
        milliseconds: 700,
      ),
      () {
        _seeking.remove(index);
      },
    );
  }

  void _showGesture(
    IconData icon, [
    String? text,
  ]) {
    _gestureTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _gestureIcon = icon;
      _gestureText = text;
    });

    _gestureTimer =
        Timer(
      const Duration(
        milliseconds: 550,
      ),
      () {
        if (!mounted) return;

        setState(() {
          _gestureIcon = null;
          _gestureText = null;
        });
      },
    );
  }

  void _like(
    VideoItem video,
  ) {
    _heartTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _liked.add(video.id);
      _showHeart = true;
    });

    _heartTimer =
        Timer(
      const Duration(
        milliseconds: 700,
      ),
      () {
        if (!mounted) return;

        setState(() {
          _showHeart = false;
        });
      },
    );
  }

  void _toggleLike(
    VideoItem video,
  ) {
    if (!mounted) return;

    setState(() {
      if (_liked.contains(
        video.id,
      )) {
        _liked.remove(
          video.id,
        );
      } else {
        _liked.add(
          video.id,
        );
      }
    });
  }

  Future<void> _doubleTap(
    int index,
    VideoItem video,
    TapDownDetails details,
    double width,
  ) async {
    final x =
        details.localPosition.dx;

    if (x <
        width * 0.33) {
      await _seek(
        index,
        -5.0,
      );

      return;
    }

    if (x >
        width * 0.67) {
      await _seek(
        index,
        5.0,
      );

      return;
    }

    _like(video);
  }

  Future<void> _changePage(
    int index,
  ) async {
    final previous =
        _currentIndex;

    if (previous !=
        index) {
      await _sendCommand(
        previous,
        'pause',
      );
    }

    if (!mounted) return;

    setState(() {
      _currentIndex = index;
      _showHeart = false;
      _gestureIcon = null;
      _gestureText = null;
    });

    await Future.delayed(
      const Duration(
        milliseconds: 180,
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

    await Future.delayed(
      const Duration(
        milliseconds: 150,
      ),
    );

    await _sendCommand(
      index,
      'unMute',
    );

    if (mounted) {
      setState(() {
        _playing[index] =
            true;
      });
    }

    if (index >=
            _videos.length -
                3 &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _share(
    VideoItem video,
  ) async {
    final title =
        video.title.trim();

    final message =
        '''
${title.isEmpty ? '' : '$title\n\n'}B_music02'de bu videoya göz at 🎵

${video.tiktokUrl}

B_music02 • Müzik burada yaşar
''';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message.trim(),
          subject:
              'B_music02 Video',
        ),
      );
    } catch (_) {}
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

  void _comment() {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Yorum sistemi daha sonra bağlanacak.',
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
        body: Center(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
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
          return _videoPage(
            index,
            _videos[index],
          );
        },
      ),
    );
  }

  Widget _videoPage(
    int index,
    VideoItem video,
  ) {
    final controller =
        _controllerFor(
      index,
      video,
    );

    final liked =
        _liked.contains(
      video.id,
    );

    return LayoutBuilder(
      builder:
          (
        context,
        constraints,
      ) {
        return Stack(
          fit:
              StackFit.expand,
          children: [
            const ColoredBox(
              color:
                  Colors.black,
            ),

            WebViewWidget(
              controller:
                  controller,
            ),

            Positioned.fill(
              child:
                  GestureDetector(
                behavior:
                    HitTestBehavior
                        .translucent,
                onTap: () {
                  _togglePlayback(
                    index,
                  );
                },
                onDoubleTapDown:
                    (
                  details,
                ) {
                  _doubleTap(
                    index,
                    video,
                    details,
                    constraints.maxWidth,
                  );
                },
                child:
                    const SizedBox.expand(),
              ),
            ),

            if (_showHeart &&
                index ==
                    _currentIndex)
              const IgnorePointer(
                child:
                    Center(
                  child:
                      Icon(
                    Icons
                        .favorite_rounded,
                    color:
                        Colors.white,
                    size:
                        115,
                    shadows: [
                      Shadow(
                        color:
                            Colors.black54,
                        blurRadius:
                            24,
                      ),
                    ],
                  ),
                ),
              ),

            if (_gestureIcon !=
                    null &&
                index ==
                    _currentIndex)
              IgnorePointer(
                child:
                    Center(
                  child:
                      Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.black
                              .withOpacity(
                        0.55,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                    child:
                        Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          _gestureIcon,
                          color:
                              Colors.white,
                          size: 38,
                        ),
                        if (_gestureText !=
                            null)
                          Text(
                            _gestureText!,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                      ],
                    ),
                  ),
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
                  fontSize:
                      22,
                  fontWeight:
                      FontWeight.w900,
                  shadows: [
                    Shadow(
                      color:
                          Colors.black,
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
                      color:
                          Colors.black54,
                      border:
                          Border.all(
                        color:
                            AppColors.gold,
                        width: 2,
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
                    height: 17,
                  ),

                  _SideButton(
                    icon:
                        liked
                            ? Icons
                                .favorite_rounded
                            : Icons
                                .favorite_border_rounded,
                    color:
                        liked
                            ? const Color(
                                0xFFFF335D,
                              )
                            : Colors.white,
                    label:
                        'Beğen',
                    onTap: () {
                      _toggleLike(
                        video,
                      );
                    },
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  _SideButton(
                    icon:
                        Icons
                            .chat_bubble_rounded,
                    label:
                        'Yorum',
                    onTap:
                        _comment,
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  _SideButton(
                    icon:
                        Icons
                            .share_rounded,
                    label:
                        'Paylaş',
                    onTap: () {
                      _share(
                        video,
                      );
                    },
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  _SideButton(
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
              left: 18,
              right: 82,
              bottom: 105,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    '@b_music02',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          16,
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

            if (_loadingMore &&
                index ==
                    _videos.length -
                        1)
              const Positioned(
                top: 55,
                right: 20,
                child:
                    SizedBox(
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
      },
    );
  }
}

class _SideButton
    extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap:
          onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  Colors.black
                      .withOpacity(
                0.46,
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
            child:
                Icon(
              icon,
              color:
                  color,
              size: 26,
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
              fontSize: 9,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
