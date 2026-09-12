
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/community_video_service.dart';
import '../../../core/theme/app_theme.dart';

class CommunityHomeVideoCard extends StatefulWidget {
  const CommunityHomeVideoCard({
    super.key,
    required this.video,
  });

  final CommunityHomeVideo video;

  @override
  State<CommunityHomeVideoCard> createState() =>
      _CommunityHomeVideoCardState();
}

class _CommunityHomeVideoCardState
    extends State<CommunityHomeVideoCard> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _preparePreview();
  }

  Future<void> _preparePreview() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(
        Uri.parse(
          widget.video.videoUrl,
        ),
      );

      await controller.initialize();

      await controller.seekTo(
        const Duration(
          milliseconds: 250,
        ),
      );

      await controller.pause();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _ready = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _openPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommunityHomeVideoPlayer(
          video: widget.video,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: _openPlayer,
      child: SizedBox(
        width: 142,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: const Color(
                  0xFF171014,
                ),
              ),

              if (_ready &&
                  _controller != null)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior:
                      Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!
                        .value
                        .size
                        .width,
                    height: _controller!
                        .value
                        .size
                        .height,
                    child: VideoPlayer(
                      _controller!,
                    ),
                  ),
                ),

              if (!_ready)
                const Center(
                  child: Icon(
                    Icons
                        .video_library_rounded,
                    color:
                        AppColors.gold,
                    size: 42,
                  ),
                ),

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
                        0xA8000000,
                      ),
                    ],
                  ),
                ),
              ),

              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(
                    color: Colors.black
                        .withOpacity(
                      0.60,
                    ),
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color:
                          Colors.white24,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .play_arrow_rounded,
                    color:
                        Colors.white,
                    size: 31,
                  ),
                ),
              ),

              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.black
                        .withOpacity(
                      0.70,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons
                            .people_alt_rounded,
                        color:
                            AppColors.gold,
                        size: 12,
                      ),
                      SizedBox(
                        width: 4,
                      ),
                      Text(
                        'Sizden Gelenler',
                        style: TextStyle(
                          color:
                              Colors.white,
                          fontSize: 8,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityHomeVideoPlayer
    extends StatefulWidget {
  const CommunityHomeVideoPlayer({
    super.key,
    required this.video,
  });

  final CommunityHomeVideo video;

  @override
  State<CommunityHomeVideoPlayer>
      createState() =>
          _CommunityHomeVideoPlayerState();
}

class _CommunityHomeVideoPlayerState
    extends State<
        CommunityHomeVideoPlayer> {
  late final VideoPlayerController
      _controller;

  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _controller =
        VideoPlayerController.networkUrl(
      Uri.parse(
        widget.video.videoUrl,
      ),
    );

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();

      await _controller.setLooping(
        true,
      );

      await _controller.play();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (!_controller
        .value
        .isInitialized) {
      return;
    }

    setState(() {
      if (_controller
          .value
          .isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading)
              const Center(
                child:
                    CircularProgressIndicator(
                  color:
                      AppColors.gold,
                ),
              )
            else if (_failed)
              const Center(
                child: Text(
                  'Video açılamadı.',
                  style: TextStyle(
                    color:
                        Colors.white70,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap:
                    _togglePlayback,
                child: Center(
                  child: AspectRatio(
                    aspectRatio:
                        _controller
                            .value
                            .aspectRatio,
                    child: VideoPlayer(
                      _controller,
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color:
                    Colors.black54,
                shape:
                    const CircleBorder(),
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .arrow_back_rounded,
                    color:
                        Colors.white,
                  ),
                ),
              ),
            ),

            if (!_loading &&
                !_failed)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child:
                    VideoProgressIndicator(
                  _controller,
                  allowScrubbing:
                      true,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 8,
                  ),
                  colors:
                      const VideoProgressColors(
                    playedColor:
                        AppColors.gold,
                    bufferedColor:
                        Colors.white24,
                    backgroundColor:
                        Colors.white12,
                  ),
                ),
              ),

            if (widget.video.caption
                    ?.trim()
                    .isNotEmpty ==
                true)
              Positioned(
                left: 18,
                right: 18,
                bottom: 48,
                child: Text(
                  widget.video.caption!,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style: const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 13,
                    shadows: [
                      Shadow(
                        color:
                            Colors.black,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
