import 'dart:async';

import 'package:flutter/foundation.dart';

import 'wikimedia_music_service.dart';

enum DownloadStatus { queued, downloading, completed, cancelled, failed }

class MusicDownloadTask {
  MusicDownloadTask(this.track);
  final CommonsTrack track;
  DownloadStatus status = DownloadStatus.queued;
  int received = 0;
  int? total;
  DateTime? started;
  String? error;
  DownloadCancellation? cancellation;
  double? get progress => total == null || total! <= 0
      ? null : (received / total!).clamp(0.0, 1.0);
  double get bytesPerSecond {
    final seconds = started == null ? 0.0
        : DateTime.now().difference(started!).inMilliseconds / 1000;
    return seconds < .5 ? 0 : received / seconds;
  }
  Duration? get remaining => total == null || bytesPerSecond <= 0 ? null
      : Duration(seconds: ((total! - received) / bytesPerSecond).ceil().clamp(0, 86400).toInt());
}

typedef MusicDownloader = Future<DownloadedCommonsTrack> Function(
    CommonsTrack track, DownloadCancellation cancellation,
    void Function(int, int?) onProgress);

class MusicDownloadManager extends ChangeNotifier {
  MusicDownloadManager({MusicDownloader? downloader})
      : _downloader = downloader ?? _download;
  static final instance = MusicDownloadManager();
  final MusicDownloader _downloader;
  final _tasks = <MusicDownloadTask>[];
  bool _running = false;
  List<MusicDownloadTask> get tasks => List.unmodifiable(_tasks);
  int get activeCount => _tasks.where((t) =>
      t.status == DownloadStatus.downloading || t.status == DownloadStatus.queued).length;

  static Future<DownloadedCommonsTrack> _download(CommonsTrack track,
      DownloadCancellation cancellation, void Function(int, int?) onProgress) =>
      const WikimediaMusicService().downloadTrack(track,
          cancellation: cancellation, onProgress: onProgress);

  void enqueue(CommonsTrack track) {
    final existing = _tasks.where((t) => t.track.id == track.id).firstOrNull;
    if (existing != null) {
      if (existing.status == DownloadStatus.completed ||
          existing.status == DownloadStatus.failed ||
          existing.status == DownloadStatus.cancelled) retry(existing);
      return;
    }
    _tasks.add(MusicDownloadTask(track));
    notifyListeners();
    unawaited(_drain());
  }

  void cancel(MusicDownloadTask task) {
    if (task.status != DownloadStatus.downloading &&
        task.status != DownloadStatus.queued) return;
    task.status = DownloadStatus.cancelled;
    task.cancellation?.cancel();
    notifyListeners();
  }

  void retry(MusicDownloadTask task) {
    if (task.status != DownloadStatus.completed &&
        task.status != DownloadStatus.failed &&
        task.status != DownloadStatus.cancelled) return;
    // An active cancellation must finish cleaning its partial file first.
    if (task.cancellation != null) return;
    task.status = DownloadStatus.queued;
    task.received = 0;
    task.total = null;
    task.error = null;
    task.started = null;
    notifyListeners();
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final task = _tasks.where((t) => t.status == DownloadStatus.queued).firstOrNull;
        if (task == null) break;
        task.status = DownloadStatus.downloading;
        task.started = DateTime.now();
        final cancellation = task.cancellation = DownloadCancellation();
        notifyListeners();
        try {
          await _downloader(task.track, cancellation, (received, total) {
            if (task.status != DownloadStatus.downloading) return;
            task.received = received;
            task.total = total;
            notifyListeners();
          });
          if (!cancellation.isCancelled) task.status = DownloadStatus.completed;
        } catch (error) {
          if (cancellation.isCancelled) {
            task.status = DownloadStatus.cancelled;
          } else {
            task.status = DownloadStatus.failed;
            task.error = 'Bağlantıyı ve boş alanı kontrol edip yeniden dene.';
          }
        } finally {
          task.cancellation = null;
          notifyListeners();
        }
      }
    } finally {
      _running = false;
    }
  }
}
