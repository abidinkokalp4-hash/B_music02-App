import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Color, Brightness;

class DeviceControls {
  static const channel = MethodChannel('b_music02/device');
  static Future<void> immersive() async {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF030305),
      systemNavigationBarDividerColor: Color(0xFF030305),
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

  /// [playlist] items carry id/title/favorite/position; the native player
  /// swipes vertically through them starting at [index].
  static Future<Map<String, dynamic>?> openVideo(
      String path, String title, int position,
      {bool favorite = false,
      List<Map<String, Object>>? playlist,
      int index = 0}) async {
    final value = await channel.invokeMapMethod<String, dynamic>('openVideo', {
      'path': path,
      'title': title,
      'position': position,
      'favorite': favorite,
      if (playlist != null) 'playlist': playlist,
      'index': index,
    });
    return value;
  }

  /// Window brightness for the in-app player gestures (0..1, -1 = system).
  static Future<double> brightness() async {
    try {
      return (await channel.invokeMethod<num>('brightness'))?.toDouble() ?? -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<void> setBrightness(double? value) async {
    try {
      await channel.invokeMethod<void>('setBrightness', value ?? -1.0);
    } catch (_) {/* Brightness is optional on unsupported platforms. */}
  }

  /// Saves [start]..[end] of a local video as a new MP4 in Movies/BMusic.
  static Future<String?> trimVideo(String path, Duration start, Duration end) =>
      channel.invokeMethod<String>('trimVideo', {
        'path': path,
        'start': start.inMilliseconds,
        'end': end.inMilliseconds
      });

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

  // Alarm (native AlarmManager + full-screen ringing activity).
  static Future<String> alarms() async =>
      await channel.invokeMethod<String>('alarmsGet') ?? '[]';
  static Future<Map<String, dynamic>> saveAlarms(String json) async =>
      Map<String, dynamic>.from(await channel.invokeMapMethod<String, dynamic>('alarmsSave', json) ?? {});
  static Future<Map<String, dynamic>> alarmState() async =>
      Map<String, dynamic>.from(await channel.invokeMapMethod<String, dynamic>('alarmState') ?? {});
  static Future<void> alarmPermission(String kind) =>
      channel.invokeMethod<void>('alarmPermission', kind);

  // In-app updater.
  static Future<Map<String, dynamic>> updateInfo() async =>
      Map<String, dynamic>.from(await channel.invokeMapMethod<String, dynamic>('updateInfo') ?? {});
  static Future<String?> installUpdate(String path) =>
      channel.invokeMethod<String>('installUpdate', path);
}
