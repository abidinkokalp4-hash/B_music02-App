import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../platform/device_controls.dart';

/// One alarm. [days] uses 1 = Monday … 7 = Sunday; empty = rings once.
@immutable
class AlarmEntry {
  const AlarmEntry({required this.id, required this.hour, required this.minute,
      this.days = const {}, this.enabled = true, this.songPath = '', this.songTitle = '', this.label = ''});
  final int id, hour, minute;
  final Set<int> days;
  final bool enabled;
  final String songPath, songTitle, label;

  AlarmEntry copyWith({int? hour, int? minute, Set<int>? days, bool? enabled,
          String? songPath, String? songTitle, String? label}) =>
      AlarmEntry(id: id, hour: hour ?? this.hour, minute: minute ?? this.minute,
          days: days ?? this.days, enabled: enabled ?? this.enabled,
          songPath: songPath ?? this.songPath, songTitle: songTitle ?? this.songTitle,
          label: label ?? this.label);

  Map<String, Object> toJson() => {
        'id': id, 'hour': hour, 'minute': minute, 'days': (days.toList()..sort()),
        'enabled': enabled, 'songPath': songPath, 'songTitle': songTitle, 'label': label,
      };

  factory AlarmEntry.fromJson(Map<String, dynamic> json) => AlarmEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        hour: ((json['hour'] as num?)?.toInt() ?? 7).clamp(0, 23),
        minute: ((json['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
        days: {for (final d in (json['days'] as List? ?? const [])) if (d is num && d >= 1 && d <= 7) d.toInt()},
        enabled: json['enabled'] != false,
        songPath: '${json['songPath'] ?? ''}',
        songTitle: '${json['songTitle'] ?? ''}',
        label: '${json['label'] ?? ''}',
      );

  String get time => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  String get daysLabel {
    if (days.isEmpty) return 'Bir kez';
    if (days.length == 7) return 'Her gün';
    if (setEquals(days, {1, 2, 3, 4, 5})) return 'Hafta içi';
    if (setEquals(days, {6, 7})) return 'Hafta sonu';
    return (days.toList()..sort()).map((d) => dayNames[d - 1]).join(', ');
  }

  /// Same rule as the native AlarmLogic.nextTrigger.
  DateTime nextRing(DateTime now) {
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    for (var i = 0; i < 8; i++) {
      if (candidate.isAfter(now.add(const Duration(milliseconds: 999))) &&
          (days.isEmpty || days.contains(candidate.weekday))) return candidate;
      candidate = DateTime(candidate.year, candidate.month, candidate.day + 1, hour, minute);
    }
    return candidate;
  }

  /// "7 saat 5 dakika sonra çalacak".
  static String untilLabel(DateTime now, DateTime at) {
    final minutes = (at.difference(now).inSeconds / 60).ceil();
    final h = minutes ~/ 60, m = minutes % 60;
    if (h >= 24) return '${h ~/ 24} gün ${h % 24} saat sonra çalacak';
    if (h == 0) return '${m < 1 ? 1 : m} dakika sonra çalacak';
    return m == 0 ? '$h saat sonra çalacak' : '$h saat $m dakika sonra çalacak';
  }
}

/// Alarms are stored natively (they must survive reboots without Flutter).
class AlarmStore extends ChangeNotifier {
  AlarmStore({bool? android}) : _android = android ?? (!kIsWeb && Platform.isAndroid);
  static final instance = AlarmStore();
  final bool _android;
  List<AlarmEntry> alarms = [];
  Map<String, dynamic> permissions = const {'exact': true, 'notifications': true, 'fullScreen': true};
  bool loaded = false;

  Future<void> load() async {
    if (_android) {
      try {
        final raw = await DeviceControls.alarms();
        alarms = (jsonDecode(raw) as List).whereType<Map>()
            .map((m) => AlarmEntry.fromJson(Map<String, dynamic>.from(m))).toList();
        permissions = await DeviceControls.alarmState();
      } catch (_) {}
    }
    _sort();
    loaded = true;
    notifyListeners();
  }

  Future<void> refreshPermissions() async {
    if (!_android) return;
    try {
      permissions = await DeviceControls.alarmState();
      notifyListeners();
    } catch (_) {}
  }

  int get nextId => alarms.fold(0, (m, a) => a.id > m ? a.id : m) + 1;

  void _sort() => alarms.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

  Future<void> save(AlarmEntry alarm) async {
    alarms = [for (final a in alarms) if (a.id != alarm.id) a, alarm];
    await _persist();
  }

  Future<void> remove(int id) async {
    alarms = alarms.where((a) => a.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    _sort();
    notifyListeners();
    if (!_android) return;
    try {
      permissions = await DeviceControls.saveAlarms(jsonEncode(alarms.map((a) => a.toJson()).toList()));
      notifyListeners();
    } catch (_) {}
  }
}
