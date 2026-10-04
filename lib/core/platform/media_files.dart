import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device_controls.dart';

class MediaFiles {
  static Future<void> share(String source, String title) async {
    if (source.startsWith('content:')) {
      await DeviceControls.channel.invokeMethod<void>('shareUri', {'uri': source, 'title': title});
    } else {
      final path = source.startsWith('file:') ? File.fromUri(Uri.parse(source)).path : source;
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    }
  }
  static Future<String?> pickSubtitle() => DeviceControls.channel.invokeMethod<String>('pickSubtitle');
  static Future<void> saveImage(Uint8List bytes) async {
    final info = await DeviceControls.info();
    if ((info['sdk'] as int? ?? 29) < 29 && !await Permission.storage.request().isGranted) {
      throw StateError('Galeriye kaydetmek için depolama izni gerekiyor');
    }
    await DeviceControls.channel.invokeMethod<void>('saveFrame', bytes);
  }
  static Future<bool> saveCopy(String path, String title) async =>
      await DeviceControls.channel.invokeMethod<bool>('saveMediaCopy', {'path': path, 'title': title}) ?? false;
}
