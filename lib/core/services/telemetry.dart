import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';

/// Firebase Analytics (users, `notification_open`) and Crashlytics (crash
/// reports). Both are free on the Spark plan. Everything is best effort: no
/// Play services or no network only means nothing is reported.
///
/// Ayarlar → Gizlilik → "Kullanım ve hata raporları" turns both off.
class Telemetry {
  Telemetry({bool? android}) : _android = android ?? (!kIsWeb && Platform.isAndroid);
  static final instance = Telemetry();
  static const preferenceKey = 'bmusic_telemetry_enabled';
  final bool _android;
  bool ready = false;
  bool enabled = true;
  Future<void>? _init;
  static Future<FirebaseApp>? _app;

  /// The single shared Firebase initialisation (push + telemetry).
  static Future<FirebaseApp> firebase() => _app ??= (Firebase.apps.isNotEmpty
          ? Future.value(Firebase.app())
          : Firebase.initializeApp(options: DefaultFirebaseOptions.android))
      .timeout(const Duration(seconds: 10))
      .catchError((Object error) {
    _app = null;
    throw error;
  });

  Future<void> init() => _init ??= _start();

  Future<void> _start() async {
    if (!_android || !DefaultFirebaseOptions.configured) return;
    try {
      enabled = (await SharedPreferences.getInstance()).getBool(preferenceKey) ?? true;
      await firebase();
      final crash = FirebaseCrashlytics.instance;
      await crash.setCrashlyticsCollectionEnabled(enabled && !kDebugMode);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        previous?.call(details);
        unawaited(crash.recordFlutterFatalError(details));
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(crash.recordError(error, stack, fatal: true));
        return true;
      };
      ready = true;
      debugPrint('[BMusic feature] telemetry ready enabled=$enabled');
    } catch (error) {
      debugPrint('[BMusic feature] telemetry unavailable: $error');
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    await (await SharedPreferences.getInstance()).setBool(preferenceKey, value);
    if (!ready) return;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(value && !kDebugMode);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(value);
    } catch (_) {}
  }

  Future<void> event(String name, [Map<String, Object>? parameters]) async {
    await init();
    if (!ready || !enabled) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
      debugPrint('[BMusic feature] analytics=$name');
    } catch (_) {}
  }

  /// A tapped notification. Native code logs taps on B Music's own
  /// notifications (source github/fcm); this covers ones Android showed itself.
  Future<void> notificationOpen(String id, String source) =>
      event('notification_open', {'id': id.length > 100 ? id.substring(0, 100) : id, 'source': source});
}
