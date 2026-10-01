import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/music_download_manager.dart';
import '../../core/services/wikimedia_music_service.dart';
import 'global_mini_player.dart';
import 'widgets/music_widgets.dart';

class DownloadCenterScreen extends StatefulWidget {
  const DownloadCenterScreen({super.key, this.initialQuery,
    this.showDownloadsFirst = false, this.showQueueFirst = false,
    this.music, this.manager, this.commons = const WikimediaMusicService()});
  final String? initialQuery;
  final bool showDownloadsFirst, showQueueFirst;
  final LocalMusicService? music;
  final MusicDownloadManager? manager;
  final WikimediaMusicService commons;
  @override
  State<DownloadCenterScreen> createState() => _DownloadCenterScreenState();
}

class _DownloadCenterScreenState extends State<DownloadCenterScreen>
    with SingleTickerProviderStateMixin {
  late final _commons = widget.commons;
  late final _music = widget.music ?? LocalMusicService.instance;
  late final _manager = widget.manager ?? MusicDownloadManager.instance;
  final _controller = TextEditingController();
  late final TabController _tabs;
  Timer? _debounce;
  List<CommonsTrack> _results = [];
  List<DownloadedCommonsTrack> _downloads = [];
  bool _loading = false;
  String? _error;
  int _generation = 0, _completedCount = 0;
  ColorScheme get scheme => Theme.of(context).colorScheme;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this,
        initialIndex: widget.showDownloadsFirst ? 2 : widget.showQueueFirst ? 1 : 0);
    _controller.text = widget.initialQuery?.trim() ?? '';
    _music.addListener(_refresh);
    _manager.addListener(_queueChanged);
    _completedCount = _manager.tasks.where((t) => t.status == DownloadStatus.completed).length;
    unawaited(_loadDownloads());
    if (_controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }
  @override
  void dispose() {
    _music.removeListener(_refresh);
    _manager.removeListener(_queueChanged);
    _debounce?.cancel();
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }
  void _refresh() { if (mounted) setState(() {}); }
  void _queueChanged() {
    final count = _manager.tasks.where((t) => t.status == DownloadStatus.completed).length;
    if (count != _completedCount) {
      _completedCount = count;
      unawaited(_loadDownloads());
    }
    _refresh();
  }
  Future<void> _loadDownloads() async {
    final values = await _commons.getDownloads();
    if (mounted) setState(() => _downloads = values);
  }
  void _changed(String value) {
    _generation++;
    _debounce?.cancel();
    setState(() { _loading = false; _error = null; _results = []; });
    if (value.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 550), _search);
    }
  }
  Future<void> _search() async {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (!mounted || query.isEmpty) return;
    final generation = ++_generation;
    setState(() { _loading = true; _error = null; });
    try {
      final values = await _commons.searchMusic(query);
      if (!mounted || generation != _generation) return;
      setState(() { _results = values; _loading = false; });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Bağlantını kontrol edip yeniden dene.';
      });
    }
  }
  void _download(CommonsTrack track) {
    _manager.enqueue(track);
    _tabs.animateTo(1);
  }
  Future<void> _play(DownloadedCommonsTrack track) =>
      runMusicAction(context, () async {
        if (_music.currentDownloadPath == track.localPath) {
          await _music.togglePlayPause();
        } else {
          await _music.playDownload(track, from: _downloads);
        }
      });
  Future<void> _delete(DownloadedCommonsTrack track) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (c) => AlertDialog(
        title: const Text('İndirme silinsin mi?'),
        content: Text('${track.title} telefonundan kaldırılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    await runMusicAction(context, () async {
      if (_music.currentDownloadPath == track.localPath) await _music.pause();
      await _commons.deleteDownload(track);
      await _loadDownloads();
    });
  }
  Future<void> _source(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
    await runMusicAction(context, () async {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Kaynak açılamadı.');
      }
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('İndirme merkezi'),
      bottom: TabBar(controller: _tabs, isScrollable: true,
          tabAlignment: TabAlignment.start, tabs: [
        const Tab(text: 'Müzik bul'),
        Tab(text: _manager.activeCount == 0 ? 'Kuyruk' : 'Kuyruk (${_manager.activeCount})'),
        const Tab(text: 'İndirilenler'),
      ])),
    body: TabBarView(controller: _tabs, children: [_finder(), _queue(), _downloaded()]),
    bottomNavigationBar: GlobalMiniPlayer(music: _music, onOpenMusic: () => _tabs.animateTo(2)),
  );
  Widget _finder() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      TextField(controller: _controller, onChanged: _changed,
        onSubmitted: (_) => _search(), textInputAction: TextInputAction.search,
        decoration: InputDecoration(hintText: 'Şarkı veya sanatçı ara',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _controller.text.isEmpty ? null : IconButton(
            tooltip: 'Aramayı temizle',
            onPressed: () { _controller.clear(); _changed(''); },
            icon: const Icon(Icons.close_rounded)))),
      const SizedBox(height: 18),
      Text('Çevrimdışı koleksiyonun', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('Wikimedia Commons’tan açık lisanslı müzikleri keşfet. İndirdiğin parçalar internet olmadan da yanında.',
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 22),
      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(36), child: CircularProgressIndicator()))
      else if (_error != null) MusicEmptyState(icon: Icons.wifi_off_rounded,
          title: 'Bağlantı kurulamadı', description: _error!,
          action: _search, actionLabel: 'Yeniden dene')
      else if (_controller.text.trim().isEmpty) const MusicEmptyState(
          icon: Icons.travel_explore_rounded, title: 'Yeni bir ses keşfet',
          description: 'Arama alanına bir şarkı, sanatçı veya müzik türü yaz.')
      else if (_results.isEmpty) const MusicEmptyState(
          icon: Icons.search_off_rounded, title: 'Sonuç bulunamadı',
          description: 'Başka bir şarkı adı veya müzik türü dene.')
      else ..._results.map((track) {
        final downloaded = _downloads.any((t) => t.id == track.id);
        final pending = _manager.tasks.any((t) => t.track.id == track.id &&
            (t.status == DownloadStatus.queued || t.status == DownloadStatus.downloading));
        return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
          leading: _icon(Icons.music_note_rounded),
          title: Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${track.artist}\n${track.licenseName}', maxLines: 3, overflow: TextOverflow.ellipsis),
          onTap: () => _source(track.sourcePageUrl),
          trailing: IconButton(
            tooltip: downloaded ? 'İndirildi' : pending ? 'Kuyrukta' : track.canDownload ? 'İndir' : 'İndirme yok',
            onPressed: downloaded || pending || !track.canDownload ? null : () => _download(track),
            icon: Icon(downloaded ? Icons.download_done_rounded : pending ? Icons.hourglass_top_rounded : Icons.download_rounded))));
      }),
    ],
  );
  Widget _queue() {
    final tasks = _manager.tasks.reversed.toList();
    if (tasks.isEmpty) return MusicEmptyState(icon: Icons.downloading_rounded,
      title: 'Kuyruğun hazır', description: 'İndirmek istediğin parçaları seç. İlerlemeyi buradan takip et.',
      action: () => _tabs.animateTo(0), actionLabel: 'Müzik bul');
    return ListView.separated(padding: const EdgeInsets.all(20),
      itemCount: tasks.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (c, i) => _taskCard(tasks[i]));
  }
  Widget _taskCard(MusicDownloadTask task) {
    final active = task.status == DownloadStatus.downloading;
    final waiting = task.status == DownloadStatus.queued;
    final retry = task.status == DownloadStatus.failed || task.status == DownloadStatus.cancelled;
    final label = switch (task.status) {
      DownloadStatus.queued => 'Sırada bekliyor',
      DownloadStatus.downloading => 'İndiriliyor',
      DownloadStatus.completed => 'Dinlemeye hazır',
      DownloadStatus.cancelled => 'İptal edildi',
      DownloadStatus.failed => 'İndirme tamamlanamadı',
    };
    final remaining = task.remaining;
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _icon(task.status == DownloadStatus.completed ? Icons.offline_pin_rounded : Icons.download_rounded),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.track.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))])),
          if (active || waiting) IconButton(tooltip: 'İndirmeyi iptal et',
            onPressed: () => _manager.cancel(task), icon: const Icon(Icons.close_rounded))
          else if (retry) IconButton(tooltip: 'Yeniden indir',
            onPressed: task.cancellation == null ? () => _manager.retry(task) : null,
            icon: const Icon(Icons.refresh_rounded))
          else IconButton(tooltip: 'İndirilenleri aç', onPressed: () => _tabs.animateTo(2),
            icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        if (active) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: task.progress, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 4, children: [
            Text(task.progress == null ? _bytes(task.received)
                : '${(task.progress! * 100).round()}% · ${_bytes(task.received)} / ${_bytes(task.total!)}'),
            if (task.bytesPerSecond > 0) Text('${_bytes(task.bytesPerSecond.round())}/sn',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            if (remaining != null) Text(remaining.inSeconds < 60
                ? '~${remaining.inSeconds} sn kaldı' : '~${remaining.inMinutes + 1} dk kaldı',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ])],
        if (task.error != null && task.status == DownloadStatus.failed)
          Padding(padding: const EdgeInsets.only(top: 10),
            child: Text(task.error!, style: TextStyle(color: scheme.error, fontSize: 12))),
      ])));
  }
  Widget _downloaded() {
    if (_downloads.isEmpty) return MusicEmptyState(icon: Icons.offline_pin_outlined,
      title: 'Müziğini yanında taşı',
      description: 'Tamamlanan indirmeler burada görünür. Sonrasında internet bağlantısı gerekmez.',
      action: () => _tabs.animateTo(0), actionLabel: 'Koleksiyonunu oluştur');
    return RefreshIndicator(onRefresh: _loadDownloads,
      child: ListView.separated(padding: const EdgeInsets.all(20), itemCount: _downloads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) {
          final track = _downloads[i];
          final playing = _music.currentDownloadPath == track.localPath &&
              _music.player.playing && _music.player.processingState != ProcessingState.completed;
          return Card(child: ListTile(
            leading: _icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            title: Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _play(track),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => value == 'delete' ? _delete(track) : _source(track.sourcePageUrl),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'source', child: Text('Kaynak ve lisans')),
                PopupMenuItem(value: 'delete', child: Text('Telefondan sil'))]))); }));
  }
  Widget _icon(IconData icon) => Container(width: 46, height: 46,
    decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: scheme.primary));
  String _bytes(int value) => value >= 1024 * 1024
      ? '${(value / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(value / 1024).toStringAsFixed(0)} KB';
}
