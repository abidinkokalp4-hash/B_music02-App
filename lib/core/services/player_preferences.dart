import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerPreferences extends ChangeNotifier {
  static final instance = PlayerPreferences();
  Map<String, dynamic> _values = {};
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      _values = Map<String, dynamic>.from(
        jsonDecode(p.getString('b_music02_player_settings') ?? '{}'),
      );
    } catch (_) {
      _values = {};
    }
    notifyListeners();
  }

  bool flag(String key, {bool fallback = true}) =>
      _values[key] is bool ? _values[key] as bool : fallback;
  double number(String key, double fallback) =>
      (_values[key] as num?)?.toDouble() ?? fallback;
  String text(String key, String fallback) =>
      _values[key] as String? ?? fallback;
  List<double> gains(String key) => ((_values[key] as List?) ?? [])
      .map((e) => (e as num).toDouble())
      .toList();
  Future<void> set(String key, dynamic value) async {
    _values[key] = value;
    final p = await SharedPreferences.getInstance();
    await p.setString('b_music02_player_settings', jsonEncode(_values));
    notifyListeners();
  }

  Future<void> reset() async {
    _values = {};
    final p = await SharedPreferences.getInstance();
    await p.remove('b_music02_player_settings');
    notifyListeners();
  }
}
