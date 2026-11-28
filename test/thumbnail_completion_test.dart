import 'package:b_music02/core/services/thumbnail_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('concurrent thumbnail consumers complete on the first load', () async {
    final channel = const MethodChannel('com.fluttercandies/photo_manager');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final cache = ThumbnailCache();
    final video = AssetEntity(id:'test-first-load',typeInt:2,width:320,height:240);
    final first=cache.get(video);
    expect(identical(first,cache.get(video)),isTrue);
    await first.timeout(const Duration(seconds:3));
    await cache.get(video).timeout(const Duration(seconds:3));
  });
}
