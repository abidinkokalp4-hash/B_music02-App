import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../platform/device_controls.dart';

/// Crash-safe access to on_audio_query.
///
/// on_audio_query 2.9 keeps the pending Dart `Result` only in a WeakReference
/// inside its native `PluginProvider`. Its own permission request therefore
/// crashed (Crashlytics 1.0.355: "PluginProvider has not initialized" from
/// `onRequestPermissionsResult`) when that reference was collected or replaced
/// by a concurrent artwork query while the system dialog was open. Permissions
/// are now requested with permission_handler, and every artwork read goes
/// through a single serialized queue that never throws.
class SafeAudioQuery {
  SafeAudioQuery._();

  static OnAudioQuery? _query;
  static OnAudioQuery get _q => _query ??= OnAudioQuery();

  @visibleForTesting
  static set debugQuery(OnAudioQuery? q) => _query = q;

  /// Last known library permission; artwork is only read when true.
  static bool hasPermission = false;

  static Future<bool> permissionsStatus() async {
    try {
      hasPermission = await _q.permissionsStatus();
    } catch (_) {
      hasPermission = false;
    }
    return hasPermission;
  }

  /// Requests audio library access without on_audio_query's fragile request
  /// path, then re-reads the status the plugin itself uses for its queries.
  static Future<bool> permissionsRequest() async {
    try {
      if (Platform.isAndroid) {
        int sdk = 33;
        try {
          sdk = (await DeviceControls.info())['sdk'] as int? ?? 33;
        } catch (_) {}
        final List<Permission> wanted = sdk >= 33
            ? <Permission>[Permission.audio, Permission.photos]
            : <Permission>[Permission.storage];
        await wanted.request();
      }
    } catch (_) {
      /* Fall through to the status check. */
    }
    return permissionsStatus();
  }

  static final Queue<Future<void> Function()> _jobs =
      Queue<Future<void> Function()>();
  static bool _running = false;
  static final Map<String, Uint8List?> _cache = <String, Uint8List?>{};
  static final Map<String, Future<Uint8List?>> _pending =
      <String, Future<Uint8List?>>{};
  static const int _cacheLimit = 200;

  static Uint8List? cached(int id, int size) => _cache['$id:$size'];
  static bool isCached(int id, int size) => _cache.containsKey('$id:$size');

  /// Serialized (one at a time), cached artwork read. Returns null on any
  /// failure so callers show the fallback cover.
  static Future<Uint8List?> artwork(int id, {int size = 200}) {
    final String key = '$id:$size';
    if (_cache.containsKey(key)) return Future<Uint8List?>.value(_cache[key]);
    final Future<Uint8List?>? inFlight = _pending[key];
    if (inFlight != null) return inFlight;
    final Completer<Uint8List?> completer = Completer<Uint8List?>();
    _pending[key] = completer.future;
    _jobs.add(() async {
      Uint8List? bytes;
      if (hasPermission && _appAttached()) {
        try {
          bytes = await _q
              .queryArtwork(id, ArtworkType.AUDIO, size: size)
              .timeout(const Duration(seconds: 8));
          if (bytes != null && bytes.isEmpty) bytes = null;
        } catch (_) {
          bytes = null;
        }
        if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
        _cache[key] = bytes;
      }
      _pending.remove(key);
      completer.complete(bytes);
    });
    _pump();
    return completer.future;
  }

  static bool _appAttached() {
    final AppLifecycleState? s = WidgetsBinding.instance.lifecycleState;
    return s == null ||
        s == AppLifecycleState.resumed ||
        s == AppLifecycleState.inactive;
  }

  static bool get isForeground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_jobs.isNotEmpty) {
        try {
          await _jobs.removeFirst()();
        } catch (_) {}
      }
    } finally {
      _running = false;
    }
  }
}
