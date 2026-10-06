import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:b_music02/core/services/local_music_service.dart';
import 'package:b_music02/core/services/sleep_timer.dart';
import 'package:b_music02/core/theme/app_theme.dart';
import 'package:b_music02/features/home/full_player_screen.dart';
import 'package:b_music02/features/home/global_mini_player.dart';
import 'package:b_music02/features/home/library_screen.dart';
import 'package:b_music02/features/home/music_home_screen.dart';
import 'package:b_music02/features/home/playlists_hub.dart';
import 'package:b_music02/features/home/download_center_screen.dart';
import 'package:b_music02/core/services/music_download_manager.dart';
import 'package:b_music02/core/services/wikimedia_music_service.dart';
import 'music_download_test.dart' show track, downloaded;
import 'package:b_music02/features/home/local_video_screen.dart';
import 'package:b_music02/core/services/video_library.dart';
import 'package:b_music02/core/services/video_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_catalog_test.dart' show fixtureSong;
import 'support/fake_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['BMUSIC_CAPTURE_DIR'] == null) return;
    final loader = FontLoader('Roboto');
    loader.addFont(Future.value(ByteData.sublistView(
        File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
            .readAsBytesSync())));
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  late TestAudioPlayer player;
  late LocalMusicService music;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.lucasjosino.on_audio_query'),
            (_) async => null);
    player = TestAudioPlayer();
    music = LocalMusicService.forTesting(player);
    music.hasPermission = true;
    music.songs = [
      fixtureSong(1, 'Eşarbını Yan Bağlama'),
      fixtureSong(2, 'Uzun Bir Yol'),
      fixtureSong(3, 'Akşamın Sesi')
    ];
    await player.setAudioSources(music.songs
        .map((song) => AudioSource.uri(Uri.parse(song.uri!),
            tag: MediaItem(
                id: '${song.id}',
                title: song.title,
                artist: song.artist,
                album: song.album)))
        .toList());
    player.at = const Duration(seconds: 42);
    music.favoriteIds.add(1);
  });
  tearDown(() {
    music.dispose();
  });

  Future<void> show(WidgetTester tester, Widget screen,
      {Size size = const Size(390, 844),
      bool light = false,
      double textScale = 1,
      String? capture}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final base = light ? AppTheme.light() : AppTheme.dark();
    await tester.pumpWidget(MaterialApp(
        theme: base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
            appBarTheme: base.appBarTheme.copyWith(
                titleTextStyle: (base.appBarTheme.titleTextStyle ??
                        base.textTheme.titleLarge ??
                        const TextStyle())
                    .copyWith(
                        fontFamily: 'Roboto',
                        color: base.colorScheme.onSurface))),
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: RepaintBoundary(key: boundaryKey, child: screen)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final destination = Platform.environment['BMUSIC_CAPTURE_DIR'];
    if (capture != null && destination != null) {
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/images/b_music02_logo.png'),
          boundaryKey.currentContext!));
      await tester.pumpAndSettle();
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$destination/$capture.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }

  testWidgets('full player remains usable on small screens and large text',
      (tester) async {
    await show(tester, FullPlayerScreen(music: music),
        size: const Size(320, 568), textScale: 1.4, capture: 'player-small');
    expect(find.text('Eşarbını Yan Bağlama'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('full player uses current metadata and a responsive layout',
      (tester) async {
    await show(tester, FullPlayerScreen(music: music), capture: 'player-dark');
    await tester.runAsync(() async {
      await player.seek(Duration.zero, index: 1);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(music.currentMediaItem?.title, 'Uzun Bir Yol');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(find.text('Uzun Bir Yol'), findsOneWidget);
  });
  testWidgets('the first play tap restarts a completed queue', (tester) async {
    player.index = 2;
    player.at = player.duration!;
    player.isPlaying = true;
    player.processing = ProcessingState.completed;
    player.emitSequence();
    player.emitState();
    await show(tester, FullPlayerScreen(music: music));
    expect(find.byTooltip('Oynat'), findsOneWidget);

    await tester.tap(find.byTooltip('Oynat'));
    await tester.pumpAndSettle();

    expect(player.playing, true);
    expect(player.currentIndex, 0);
    expect(player.position, Duration.zero);
    expect(find.byTooltip('Duraklat'), findsOneWidget);
  });
  testWidgets('library search actually filters Turkish device metadata',
      (tester) async {
    await show(tester, LibraryScreen(music: music), capture: 'library-dark');
    await tester.enterText(find.byType(TextField), 'esarbini');
    await tester.pumpAndSettle();
    expect(find.text('Eşarbını Yan Bağlama'), findsOneWidget);
    expect(find.text('Uzun Bir Yol'), findsNothing);
    await tester.enterText(find.byType(TextField), 'olmayan');
    await tester.pumpAndSettle();
    expect(find.text('Eşleşen müzik bulunamadı'), findsOneWidget);
  });
  testWidgets('home layout uses actual device tracks in both themes',
      (tester) async {
    final screen = MusicHomeScreen(
      music: music,
      onOpenMusic: () {},
      onOpenVideo: () {},
    );
    await show(tester, screen, capture: 'home-dark');
    await tester.scrollUntilVisible(find.text('Eşarbını Yan Bağlama').first, 180, scrollable: find.byType(Scrollable).first);
    expect(find.text('Eşarbını Yan Bağlama'), findsWidgets);
    await show(tester, screen, light: true, capture: 'home-light');
    expect(tester.takeException(), isNull);
  });
  testWidgets('mini player and playlist hub fit narrow displays',
      (tester) async {
    await show(
        tester,
        Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar:
                GlobalMiniPlayer(music: music, onOpenMusic: () {})),
        size: const Size(320, 568),
        textScale: 1.4);
    await show(tester, PlaylistsHub(music: music),
        size: const Size(320, 568), textScale: 1.4, capture: 'playlists-small');
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('Yeni liste oluştur'), findsOneWidget);
  });

  testWidgets('home remains usable with large text on a narrow screen',
      (tester) async {
    await show(
        tester,
        MusicHomeScreen(
          music: music,
          onOpenMusic: () {},
          onOpenVideo: () {},
        ),
        size: const Size(320, 568),
        textScale: 1.4,
        capture: 'home-small');
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'pinning a playlist exposes a working home shortcut on a narrow screen',
      (tester) async {
    await music.createPlaylist('Uzun Yol');
    await music.addSongsToPlaylist('Uzun Yol', music.songs);
    await show(tester, PlaylistsHub(music: music));
    await tester.scrollUntilVisible(find.byTooltip('Uzun Yol seçenekleri'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Uzun Yol seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana sayfaya sabitle'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(music.pinnedPlaylistNames, ['Uzun Yol']);
    await show(tester,
        MusicHomeScreen(music: music, onOpenMusic: () {}, onOpenVideo: () {}),
        capture: 'home-pinned-dark');
    await show(
        tester,
        MusicHomeScreen(
          music: music,
          onOpenMusic: () {},
          onOpenVideo: () {},
        ),
        size: const Size(320, 568),
        textScale: 1.4);
    await tester.scrollUntilVisible(find.text('Uzun Yol'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Uzun Yol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzun Yol'));
    await tester.pumpAndSettle();
    expect(find.text('Tümünü çal'), findsOneWidget);
    await tester.tap(find.text('Tümünü çal'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(player.playing, true);
    expect(music.queueItems.length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'local home opens videos and never exposes online music entry points',
      (tester) async {
    var openedVideo = false;
    await show(
        tester,
        MusicHomeScreen(
            music: music,
            onOpenMusic: () {},
            onOpenVideo: () => openedVideo = true));
    await tester.scrollUntilVisible(find.text('Tüm\nVideolar'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Tüm\nVideolar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tüm\nVideolar'));
    await tester.pumpAndSettle();
    expect(openedVideo, true);
    expect(find.text('İndirilenler'), findsNothing);
    expect(find.text('Keşfet'), findsNothing);
    expect(find.byTooltip('İndirme merkezi'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Karışık çal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Karışık çal'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(player.shuffleModeEnabled, true);
    expect(player.playing, true);
    expect(music.queueItems.length, music.songs.length);
  });

  testWidgets(
      'video favorites and view controls fit narrow and large-text displays',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.fluttercandies/photo_manager'),
            (_) async => null);
    final library = VideoLibrary()..allowed = true;
    library.videos = [
      LocalVideo(
          AssetEntity(
              id: 'local-video-ui',
              typeInt: 2,
              width: 1920,
              height: 1080,
              duration: 125,
              title: 'İstanbul Geceleri.mp4',
              createDateSecond: 1720000000),
          20000000,
          {'Kamera'})
    ];
    await VideoPreferences.instance.record('local-video-ui',
        const Duration(seconds: 35), const Duration(seconds: 125));
    expect(library.filter('istanbul', 'Tümü', VideoSort.newest).length, 1);
    await show(tester, LocalVideoScreen(library: library, scanOnOpen: false),
        size: const Size(320, 568), textScale: 1.4, capture: 'videos-small');
    await tester.tap(find.byTooltip('İstanbul Geceleri.mp4 seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorilere ekle'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(VideoPreferences.instance.isFavorite('local-video-ui'), true);
    // At 320 px with large text the filter chips scroll horizontally.
    await tester.ensureVisible(find.text('Favoriler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoriler'));
    await tester.pumpAndSettle();
    expect(find.text('İstanbul Geceleri.mp4'), findsOneWidget);
    await tester.tap(find.byTooltip('Liste görünümü'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Kart görünümü'), findsOneWidget);
    expect(find.text('Devam: 0:35'), findsOneWidget);
    await show(tester, LocalVideoScreen(library: library, scanOnOpen: false),
        light: true, capture: 'videos-light');
    await show(tester, LocalVideoScreen(library: library, scanOnOpen: false),
        capture: 'videos-dark');
  });

  testWidgets(
      'download queue exposes progress, cancellation and retry in both themes',
      (tester) async {
    final pending = Completer<DownloadedCommonsTrack>();
    final manager = MusicDownloadManager(downloader: (t, token, progress) {
      progress(512 * 1024, 1024 * 1024);
      return pending.future;
    });
    manager.enqueue(track(11));
    await show(
        tester,
        DownloadCenterScreen(
            music: music, manager: manager, showQueueFirst: true),
        capture: 'downloads-dark');
    expect(find.text('İndiriliyor'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
    await tester.tap(find.byTooltip('İndirmeyi iptal et'));
    pending.complete(downloaded(track(11)));
    await tester.pumpAndSettle();
    expect(find.text('İptal edildi'), findsOneWidget);
    expect(find.byTooltip('Yeniden indir'), findsOneWidget);
    await show(
        tester,
        DownloadCenterScreen(
            music: music, manager: manager, showQueueFirst: true),
        light: true,
        size: const Size(320, 568),
        textScale: 1.4,
        capture: 'downloads-light-small');
    manager.dispose();
  });
  testWidgets('playlist cover choices are available in a personal list',
      (tester) async {
    await music.createPlaylist('Uzun Yol');
    await music.addToPlaylist('Uzun Yol', music.songs.first);
    await show(tester, PlaylistsHub(music: music), capture: 'playlists-dark');
    await tester.scrollUntilVisible(find.text('Uzun Yol'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzun Yol'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Listeye şarkı ekle'), findsOneWidget);
    await tester.tap(find.byTooltip('Liste seçenekleri'));
    await tester.pumpAndSettle();
    expect(find.text('Kapak fotoğrafı seç'), findsOneWidget);
  });

  testWidgets('sleep timer choices scroll and remain usable with large text',
      (tester) async {
    final sleep =
        SleepTimer(player: player, pause: () async {}, onChange: () {});
    await show(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showSleepTimer(context, timer: sleep),
                    child: const Text('Zamanlayıcıyı aç')))),
        size: const Size(320, 568),
        textScale: 1.6);
    await tester.tap(find.text('Zamanlayıcıyı aç'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('180 dakika'));
    await tester.tap(find.text('180 dakika'));
    await tester.pumpAndSettle();
    expect(sleep.isActive, true);
    expect(sleep.endsAt!.difference(DateTime.now()).inMinutes, 179);
    expect(tester.takeException(), isNull);
    sleep.cancel();
  });
}
