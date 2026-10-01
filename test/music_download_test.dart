import 'dart:async';
import 'dart:io';
import 'package:b_music02/core/services/music_download_manager.dart';
import 'package:b_music02/core/services/wikimedia_music_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

CommonsTrack track(int id) => CommonsTrack(id: id, title: 'Parça $id',
    artist: 'Sanatçı', fileUrl: 'https://example.com/$id.ogg',
    sourcePageUrl: 'https://example.com/source', mimeType: 'audio/ogg',
    licenseName: 'CC BY 4.0', licenseUrl: '', credit: '', description: '');
DownloadedCommonsTrack downloaded(CommonsTrack t) => DownloadedCommonsTrack(
    id: t.id, title: t.title, artist: t.artist, localPath: '/tmp/${t.id}',
    sourcePageUrl: t.sourcePageUrl, licenseName: t.licenseName,
    licenseUrl: t.licenseUrl, credit: t.credit);

class StreamClient extends http.BaseClient {
  StreamClient(this.response);
  final http.StreamedResponse response;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async => response;
  @override
  void close() { closed = true; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('bmusic-download-test-');
  });
  tearDown(() async { await root.delete(recursive: true); });

  WikimediaMusicService service(http.StreamedResponse response) =>
      WikimediaMusicService(clientFactory: () => StreamClient(response), downloadsRoot: () async => root);

  test('download publishes only complete files and reports final progress', () async {
    final progress = <int>[];
    final commons = service(http.StreamedResponse(Stream.fromIterable([[1, 2], [3, 4]]), 200, contentLength: 4));
    final value = await commons.downloadTrack(track(1), onProgress: (n, _) => progress.add(n));
    expect(await File(value.localPath).readAsBytes(), [1, 2, 3, 4]);
    expect(progress.first, 0);
    expect(progress.last, 4);
    expect((await commons.getDownloads()).single.id, 1);
    expect(await File('${value.localPath}.part').exists(), false);
    expect((await commons.downloadTrack(track(1))).localPath, value.localPath);
  });
  test('truncated download removes its partial file and leaves no library entry', () async {
    final commons = service(http.StreamedResponse(Stream.fromIterable([[1, 2]]), 200, contentLength: 4));
    await expectLater(commons.downloadTrack(track(2)), throwsA(isA<HttpException>()));
    expect(await commons.getDownloads(), isEmpty);
    expect(await Directory('${root.path}/b_music02_music').list().toList(), isEmpty);
  });
  test('cancel closes the client and removes incomplete data', () async {
    final token = DownloadCancellation();
    final client = StreamClient(http.StreamedResponse(Stream.fromIterable([[1], [2]]), 200, contentLength: 2));
    final commons = WikimediaMusicService(clientFactory: () => client, downloadsRoot: () async => root);
    await expectLater(commons.downloadTrack(track(3), cancellation: token,
        onProgress: (n, _) { if (n > 0) token.cancel(); }), throwsA(isA<DownloadCancelled>()));
    expect(client.closed, true);
    expect(await commons.getDownloads(), isEmpty);
    expect(await Directory('${root.path}/b_music02_music').list().toList(), isEmpty);
  });
  test('simultaneous completed downloads retain both library entries', () async {
    final commons = WikimediaMusicService(downloadsRoot: () async => root,
        clientFactory: () => StreamClient(http.StreamedResponse(Stream.value([1, 2, 3]), 200)));
    await Future.wait([commons.downloadTrack(track(4)), commons.downloadTrack(track(5))]);
    expect((await commons.getDownloads()).map((t) => t.id).toSet(), {4, 5});
  });
  test('HTTP failure cannot become a saved download', () async {
    final commons = service(http.StreamedResponse(Stream.value([1]), 403));
    await expectLater(commons.downloadTrack(track(6)), throwsA(isA<HttpException>()));
    expect(await commons.getDownloads(), isEmpty);
  });
  test('queue is sequential, deduplicates requests and retries cancelled work', () async {
    final calls = <int>[];
    final pending = <int, Completer<DownloadedCommonsTrack>>{};
    final manager = MusicDownloadManager(downloader: (t, token, progress) {
      calls.add(t.id);
      progress(50, 100);
      return (pending[t.id] = Completer()).future;
    });
    manager.enqueue(track(1));
    manager.enqueue(track(1));
    manager.enqueue(track(2));
    expect(calls, [1]);
    expect(manager.tasks.first.progress, .5);
    expect(manager.tasks.last.status, DownloadStatus.queued);
    manager.cancel(manager.tasks.last);
    pending[1]!.complete(downloaded(track(1)));
    await Future<void>.delayed(Duration.zero);
    expect(manager.activeCount, 0);
    expect(calls, [1]);
    manager.enqueue(track(2));
    expect(calls, [1, 2]);
    pending[2]!.complete(downloaded(track(2)));
    await Future<void>.delayed(Duration.zero);
    expect(manager.tasks.last.status, DownloadStatus.completed);
    manager.dispose();
  });
  test('failed task can be retried without blocking the next track', () async {
    var fail = true;
    final manager = MusicDownloadManager(downloader: (t, token, progress) async {
      if (t.id == 1 && fail) throw const HttpException('offline');
      progress(100, 100);
      return downloaded(t);
    });
    manager.enqueue(track(1));
    manager.enqueue(track(2));
    await Future<void>.delayed(Duration.zero);
    expect(manager.tasks.first.status, DownloadStatus.failed);
    expect(manager.tasks.last.status, DownloadStatus.completed);
    fail = false;
    manager.retry(manager.tasks.first);
    await Future<void>.delayed(Duration.zero);
    expect(manager.tasks.first.status, DownloadStatus.completed);
    manager.dispose();
  });
}
