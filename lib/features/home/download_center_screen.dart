import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/wikimedia_music_service.dart';
import '../../core/theme/app_theme.dart';

class DownloadCenterScreen extends StatefulWidget {
  const DownloadCenterScreen({
    super.key,
    this.initialQuery,
    this.showDownloadsFirst = false,
  });

  final String? initialQuery;
  final bool showDownloadsFirst;

  @override
  State<DownloadCenterScreen> createState() => _DownloadCenterScreenState();
}

class _DownloadCenterScreenState extends State<DownloadCenterScreen>
    with SingleTickerProviderStateMixin {
  final WikimediaMusicService _commons = const WikimediaMusicService();
  final LocalMusicService _music = LocalMusicService.instance;
  final TextEditingController _controller = TextEditingController();

  late final TabController _tabs;
  Timer? _debounce;

  List<CommonsTrack> _results = const [];
  List<DownloadedCommonsTrack> _downloads = const [];
  bool _loading = false;
  String? _error;
  int? _downloadingId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showDownloadsFirst ? 1 : 0,
    );
    _controller.text = widget.initialQuery?.trim() ?? '';
    _loadDownloads();
    if (_controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    final value = await _commons.getDownloads();
    if (!mounted) return;
    setState(() => _downloads = value);
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 650), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _commons.searchMusic(query, limit: 30);
      if (!mounted) return;
      setState(() {
        _results = value;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'İndirilebilir müzikler alınamadı: $e';
      });
    }
  }

  bool _isDownloaded(CommonsTrack track) {
    return _downloads.any((item) => item.id == track.id);
  }

  Future<void> _download(CommonsTrack track) async {
    if (!track.canDownload || _downloadingId != null) return;
    setState(() => _downloadingId = track.id);
    try {
      await _commons.downloadTrack(track);
      await _loadDownloads();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${track.title} indirildi. Artık internetsiz dinleyebilirsin.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İndirme başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _play(DownloadedCommonsTrack track) async {
    try {
      await _music.playDownload(track, from: _downloads);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Müzik açılamadı: $e')),
      );
    }
  }

  Future<void> _delete(DownloadedCommonsTrack track) async {
    if (_music.currentDownloadPath == track.localPath) {
      await _music.pause();
    }
    await _commons.deleteDownload(track);
    await _loadDownloads();
  }

  Future<void> _openSource(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Müzik İndir'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.neonPurple,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Müzik Bul'),
            Tab(text: 'İndirilenler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _finder(),
          _downloadedList(),
        ],
      ),
    );
  }

  Widget _finder() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151724),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2D40)),
          ),
          child: TextField(
            controller: _controller,
            onChanged: _changed,
            onSubmitted: (_) => _search(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'İndirilebilir müzik ara',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _controller.clear();
                        _changed('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF18162A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.neonPurple, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'İndirme sonuçları izinli ve açık lisanslı kaynaklardan gelir. YouTube videosu MP3’e dönüştürülmez.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.neonPurple)),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(_error!, style: const TextStyle(color: Colors.white60)),
          )
        else if (_controller.text.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 55),
            child: Column(
              children: [
                Icon(Icons.download_for_offline_outlined, size: 58, color: Colors.white24),
                SizedBox(height: 12),
                Text('Bir şarkı veya sanatçı ara', style: TextStyle(color: Colors.white54)),
              ],
            ),
          )
        else if (_results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: Text('İndirilebilir sonuç bulunamadı')),
          )
        else
          ..._results.map(_resultTile),
      ],
    );
  }

  Widget _resultTile(CommonsTrack track) {
    final downloaded = _isDownloaded(track);
    final busy = _downloadingId == track.id;
    return Card(
      color: const Color(0xFF151724),
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C2BFF), Color(0xFF27115F)],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.white),
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${track.artist} • ${track.licenseName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        onTap: () => _openSource(track.sourcePageUrl),
        trailing: busy
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.neonPurple),
              )
            : IconButton(
                tooltip: downloaded
                    ? 'İndirildi'
                    : track.canDownload
                        ? 'İndir'
                        : 'Lisans uygun değil',
                onPressed: downloaded || !track.canDownload ? null : () => _download(track),
                icon: Icon(
                  downloaded ? Icons.download_done_rounded : Icons.download_rounded,
                  color: downloaded ? Colors.greenAccent : AppColors.neonPurple,
                ),
              ),
      ),
    );
  }

  Widget _downloadedList() {
    if (_downloads.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.offline_pin_outlined, size: 62, color: Colors.white24),
              SizedBox(height: 12),
              Text('Henüz indirilen müzik yok'),
              SizedBox(height: 6),
              Text(
                'Müzik Bul sekmesinden bir parça indirince burada görünecek.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      itemCount: _downloads.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
      itemBuilder: (context, index) {
        final item = _downloads[index];
        final selected = _music.currentDownloadPath == item.localPath;
        final playing = selected && _music.player.playing;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => _play(item),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF21183F),
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.neonPurple,
              size: 28,
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            item.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'source') _openSource(item.sourcePageUrl);
              if (value == 'delete') _delete(item);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'source', child: Text('Kaynağı göster')),
              PopupMenuItem(value: 'delete', child: Text('Telefondan sil')),
            ],
          ),
        );
      },
    );
  }
}
