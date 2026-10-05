import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Color, Brightness;

class DeviceControls {
  static const channel = MethodChannel('b_music02/device');
  static Future<void> immersive() async {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    if (Platform.isAndroid) {
      try {
        await channel.invokeMethod<void>('immersive');
        return;
      } on MissingPluginException {
        /* Older builds use Flutter's fallback. */
      }
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static Future<void> videoFullscreen(bool enabled) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('videoFullscreen', enabled);
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.edgeToEdge : SystemUiMode.edgeToEdge,
      );
    }
  }

  static Future<Map<String, dynamic>?> openVideo(String path, String title, int position) async {
    final value = await channel.invokeMapMethod<String, dynamic>('openVideo',
        {'path': path, 'title': title, 'position': position});
    return value;
  }

  static Future<void> settings(String section) async {
    await channel.invokeMethod<void>('settings', section);
  }
  static Future<bool> pinWidget() async =>
      await channel.invokeMethod<bool>('pinWidget') ?? false;

  static Future<Map<String, dynamic>> info() async => Map<String, dynamic>.from(
    await channel.invokeMapMethod<String, dynamic>('info') ?? {},
  );
  static Future<void> exportBackup(String json) =>
      channel.invokeMethod<void>('exportBackup', json);
  static Future<String?> importBackup() =>
      channel.invokeMethod<String>('importBackup');
  static Future<void> icon(String color) =>
      channel.invokeMethod<void>('icon', color);
}
