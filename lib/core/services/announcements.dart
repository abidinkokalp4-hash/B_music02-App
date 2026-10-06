import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One entry of announcements.json in the public repository, or an instant
/// announcement received through Firebase Cloud Messaging (same fields).
///
/// Android fetches the file natively (start/resume and every ~4 h through
/// WorkManager), posts notifications for new ids and caches the raw JSON.
/// FCM pushes are handled natively too (PushMessagingService) and kept in a
/// "pushed" list; both paths share one seen-id set, so an id is notified once.
/// This side merges both for the in-app "Duyurular" list.
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

  /// An FCM message as an announcement: `id`, `title`, `body`, optional `url`
  /// from the data payload, falling back to the notification payload and the
  /// FCM message id. Mirrors AnnouncementLogic.fromPush on the Kotlin side.
  static Announcement? fromPush(Map<String, Object?> data,
      {String? title, String? body, String? messageId, DateTime? sentTime}) {
    String text(Object? v) => '${v ?? ''}'.trim();
    final merged = <String, Object?>{...data};
    if (text(merged['title']).isEmpty && title != null) merged['title'] = title;
    if (text(merged['body']).isEmpty && body != null) merged['body'] = body;
    var id = text(merged['id']);
    if (id.isEmpty && text(messageId).isNotEmpty) id = 'fcm-${text(messageId)}';
    merged['id'] = id.length > 200 ? id.substring(0, 200) : id;
    final item = fromJson(merged);
    if (item == null) return null;
    final bodyText = item.body.length > 1000 ? item.body.substring(0, 1000) : item.body;
    return Announcement(
        id: item.id,
        title: item.title,
        body: bodyText,
        url: item.url,
        createdAt: item.createdAt ?? sentTime?.toUtc());
  }

  /// One entry per id from the polled file and received pushes, newest first.
  /// The announcements.json copy wins because it is the edited/canonical one.
  static List<Announcement> merge(
      List<Announcement> polled, List<Announcement> pushed) {
    final byId = <String, Announcement>{
      for (final item in pushed) item.id: item,
      for (final item in polled) item.id: item,
    };
    final result = byId.values.toList()
      ..sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? -1)
          .compareTo(a.createdAt?.millisecondsSinceEpoch ?? -1));
    return result;
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

  /// Native FCM topic state: unknown / unconfigured / subscribed / unsubscribed / error.
  String push = 'unknown';
  DateTime? _lastCheck;
  String? _pendingTap;
  final _taps = StreamController<String>.broadcast();

  /// Ids of announcements opened from an FCM-displayed notification while the app runs.
  Stream<String> get taps => _taps.stream;

  Announcement? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _apply(Object? state) {
    if (state is! Map) return;
    items = Announcement.merge(Announcement.parseAll(state['json'] as String?),
        Announcement.parseAll(state['pushed'] as String?));
    push = '${state['push'] ?? 'unknown'}';
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
    final pending = _pendingTap;
    _pendingTap = null;
    if (!_android) return pending;
    try {
      return await _channel.invokeMethod<String>('announcementTap') ?? pending;
    } catch (_) {
      return pending;
    }
  }

  /// A push whose notification Android displayed itself (FCM notification
  /// payload) was tapped: store it natively (seen + Duyurular list, never
  /// notified again) and open it like a tapped announcement.
  Future<void> openedPush(Announcement item, {bool running = true}) async {
    if (_android) {
      try {
        await _channel.invokeMethod<Object?>('announcementsPushed', {
          'id': item.id,
          'title': item.title,
          'body': item.body,
          if (item.url != null) 'url': item.url,
          if (item.createdAt != null)
            'createdAt': item.createdAt!.toUtc().toIso8601String(),
        });
      } catch (_) {}
      await loadCached();
    }
    _pendingTap = item.id;
    if (running) _taps.add(item.id);
  }
}
