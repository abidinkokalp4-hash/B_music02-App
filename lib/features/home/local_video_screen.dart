import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';

class LocalVideoScreen extends StatefulWidget {
  const LocalVideoScreen({super.key});

  @override
  State<LocalVideoScreen> createState() => _LocalVideoScreenState();
}

class _LocalVideoScreenState extends State<LocalVideoScreen> {
  bool _loading = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _requestAccess();
  }

  Future<void> _requestAccess() async {
    final status = await Permission.videos.request();
    if (!mounted) return;
    setState(() {
      _allowed = status.isGranted || status.isLimited;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Videolarım', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _requestAccess, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_allowed
              ? _PermissionCard(onTap: _requestAccess)
              : const _VideoReadyView(),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.video_library_rounded, size: 72, color: AppColors.neonPurple),
            const SizedBox(height: 18),
            const Text('Telefonundaki videoları gösterelim', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Videolar cihazında kalır. B_music02 hiçbir videoyu sunucuya yüklemez.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.lock_open_rounded), label: const Text('Video erişimine izin ver')),
          ]),
        ),
      );
}

class _VideoReadyView extends StatelessWidget {
  const _VideoReadyView();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(colors: [AppColors.neonPurple.withValues(alpha: .28), AppColors.neonPink.withValues(alpha: .12)]),
              border: Border.all(color: AppColors.neonPurple.withValues(alpha: .35)),
            ),
            child: const Row(children: [
              Icon(Icons.ondemand_video_rounded, color: AppColors.neonPurple, size: 38),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Yerel Video', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('Kamera, indirilenler ve diğer video klasörleri', style: TextStyle(color: Colors.white60)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Video kütüphanesi hazırlanıyor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Bu ilk sürümde video izni ve yeni B_music02 video alanı hazır. Sonraki adımda MediaStore taraması, küçük resimler ve tam ekran oynatıcı bağlanacak.', style: TextStyle(color: Colors.white60, height: 1.45)),
        ],
      );
}

class LocalVideoPlayerScreen extends StatefulWidget {
  const LocalVideoPlayerScreen({super.key, required this.file});
  final File file;

  @override
  State<LocalVideoPlayerScreen> createState() => _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<LocalVideoPlayerScreen> {
  late final VideoPlayerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)..initialize().then((_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black),
    body: Center(child: _controller.value.isInitialized ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)) : const CircularProgressIndicator()),
    floatingActionButton: FloatingActionButton(onPressed: () { setState(() { _controller.value.isPlaying ? _controller.pause() : _controller.play(); }); }, child: Icon(_controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
  );
}
