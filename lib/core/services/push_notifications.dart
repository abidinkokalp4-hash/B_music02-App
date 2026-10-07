import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../firebase_options.dart';
import 'announcements.dart';
import 'player_preferences.dart';
import 'telemetry.dart';

/// Instant announcements through Firebase Cloud Messaging.
///
/// Android does the heavy lifting natively (PushMessagingService posts the
/// notification on the existing "Duyurular" channel in the foreground,
/// background and after the app was swiped away, de-duplicated with the
/// announcements.json seen-ids; MainActivity subscribes to topic `all` and
/// leaves it when "Duyuru bildirimleri" is off). This side initialises
/// Firebase for Dart, asks for the notification permission once and opens
/// the Duyurular list for notifications Android displayed by itself.
///
/// Everything is optional: no Play services, no network or an unconfigured
/// project only means pushes do not arrive; the poll keeps working.
class PushNotifications {
  PushNotifications({AnnouncementService? announcements, bool? android})
      : _announcements = announcements ?? AnnouncementService.instance,
        _android = android ?? (!kIsWeb && Platform.isAndroid);
  static final instance = PushNotifications();
  static const topic = 'all';
  final AnnouncementService _announcements;
  final bool _android;
  bool available = false;
  String? token;
  Future<void>? _init;

  Future<void> init() => _init ??= _start();

  Future<void> _start() async {
    if (!_android || !DefaultFirebaseOptions.configured) {
      debugPrint('[BMusic feature] push disabled (firebase not configured)');
      return;
    }
    try {
      await Telemetry.firebase();
      available = true;
      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => unawaited(opened(message)),
          onError: (Object _) {});
      final initial = await messaging
          .getInitialMessage()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (initial != null) await opened(initial, running: false);
      // Without Google Play services this fails; that is expected (CI emulator).
      unawaited(messaging.getToken().then((value) {
        token = value;
        debugPrint('[BMusic feature] push-token ready=${value != null}');
      }, onError: (Object error) {
        debugPrint('[BMusic feature] push-token unavailable: $error');
      }));
      debugPrint('[BMusic feature] push initialised');
    } catch (error) {
      debugPrint('[BMusic feature] push unavailable: $error');
    }
  }

  /// A notification shown by Android itself (FCM notification payload) was tapped.
  Future<void> opened(RemoteMessage message, {bool running = true}) async {
    final item = Announcement.fromPush(message.data,
        title: message.notification?.title,
        body: message.notification?.body,
        messageId: message.messageId,
        sentTime: message.sentTime);
    if (item == null) return;
    unawaited(Telemetry.instance.notificationOpen(item.id, 'fcm_system'));
    await _announcements.openedPush(item, running: running);
  }

  /// Android 13+: ask for POST_NOTIFICATIONS once (the same permission the
  /// media controls use), so announcements can be shown. Later changes go
  /// through Ayarlar → Bildirimler → Bildirim izni.
  Future<void> requestPermissionOnce() async {
    if (!_android || !_announcements.enabled) return;
    final prefs = PlayerPreferences.instance;
    if (prefs.flag('notificationPermissionAsked', fallback: false)) return;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) await Permission.notification.request();
      await prefs.set('notificationPermissionAsked', true);
      await _announcements.loadCached();
    } catch (_) {}
  }
}
