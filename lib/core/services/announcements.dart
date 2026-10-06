import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One entry of announcements.json in the public repository.
///
/// Android fetches the file natively (start/resume and every ~4 h through
/// WorkManager), posts notifications for new ids and caches the raw JSON;
/// this side parses that cache for the in-app "Duyurular" list.
@immutable
class Announcement {
  const Announcement(
      {required this.id,
      required this.title,
      this.body = '',
      this.url,
      this.createdAt});
  final String id, title, body;
  final String? url;
  final DateTime? createdAt;

  static Announcement? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = '${value['id'] ?? ''}'.trim();
    final title = '${value['title'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) return null;
    final url = '${value['url'] ?? ''}'.trim();
    return Announcement(
      id: id,
      title: title.length > 120 ? title.substring(0, 120) : title,
      body: '${value['body'] ?? ''}'.trim(),
      url: url.startsWith('https://') ? url : null,
      createdAt: DateTime.tryParse('${value['createdAt'] ?? ''}'.trim()),
    );
  }

  /// Valid, de-duplicated announcements, newest first. Malformed input → [].
  static List<Announcement> parseAll(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    Object? root;
    try {
      root = jsonDecode(text);
    } catch (_) {
      return const [];
    }
    final items = root is Map ? root['announcements'] : null;
    if (items is! List) return const [];
    final ids = <String>{};
    final result = <Announcement>[
      for (final item in items.map(fromJson))
        if (item != null && ids.add(item.id)) item
    ];
    result.sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? -1)
        .compareTo(a.createdAt?.millisecondsSinceEpoch ?? -1));
    return result;
  }
}

class AnnouncementService extends ChangeNotifier {
  AnnouncementService({MethodChannel? channel, bool? android})
      : _channel = channel ?? const MethodChannel('b_music02/device'),
        _android = android ?? (!kIsWeb && Platform.isAndroid);
  static final instance = AnnouncementService();
  final MethodChannel _channel;
  final bool _android;
  List<Announcement> items = const [];
  Set<String> seen = const {};
  bool enabled = true, allowed = true, loading = false;
  DateTime? _lastCheck;

  void _apply(Object? state) {
    if (state is! Map) return;
    items = Announcement.parseAll(state['json'] as String?);
    seen = {...?(state['seen'] as List?)?.map((e) => '$e')};
    enabled = state['enabled'] != false;
    allowed = state['allowed'] != false;
    notifyListeners();
  }

  /// Native fetch + notify. Throttled on resume; [force] for pull-to-refresh.
  Future<void> check({bool force = false}) async {
    if (!_android || loading) return;
    final now = DateTime.now();
    if (!force &&
        _lastCheck != null &&
        now.difference(_lastCheck!) < const Duration(minutes: 15)) {
      return;
    }
    _lastCheck = now;
    loading = true;
    notifyListeners();
    try {
      _apply(await _channel.invokeMethod<Object?>('announcementsCheck'));
    } catch (_) {
      // Offline or unsupported: the cached list stays as it was.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCached() async {
    if (!_android) return;
    try {
      _apply(await _channel.invokeMethod<Object?>('announcementsState'));
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    notifyListeners();
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('announcementsEnable', value);
    } catch (_) {}
  }

  /// The id of an announcement notification that opened the app, once.
  Future<String?> takeTap() async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<String>('announcementTap');
    } catch (_) {
      return null;
    }
  }
}
