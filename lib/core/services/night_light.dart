import 'dart:async';

import 'package:flutter/material.dart';

import 'player_preferences.dart';

/// Gece ışığı: a warm, dimmed filter drawn over the whole app (blue-light
/// reduction while listening at night). Settings live in PlayerPreferences:
/// `nightLight` (on/off), `nightBrightness` (0.1–1) and `nightWarmth` (0–1).
class NightLight extends ChangeNotifier {
  NightLight._();
  static final instance = NightLight._();

  final _prefs = PlayerPreferences.instance;
  Timer? _timer;
  DateTime? offAt;
  int? autoOffMinutes;

  bool get enabled => _prefs.flag('nightLight', fallback: false);
  double get brightness => _prefs.number('nightBrightness', .4).clamp(.1, 1.0);
  double get warmth => _prefs.number('nightWarmth', .75).clamp(0.0, 1.0);

  /// Black dim layer opacity.
  static double dimFor(double brightness) => ((1 - brightness) * .75).clamp(0.0, .7);

  /// Warm amber layer opacity.
  static double warmFor(double warmth) => (warmth * .32).clamp(0.0, .32);

  Future<void> setEnabled(bool on) async {
    await _prefs.set('nightLight', on);
    if (!on) _cancelTimer();
    notifyListeners();
  }

  Future<void> setBrightness(double v) async {
    await _prefs.set('nightBrightness', double.parse(v.toStringAsFixed(2)));
    notifyListeners();
  }

  Future<void> setWarmth(double v) async {
    await _prefs.set('nightWarmth', double.parse(v.toStringAsFixed(2)));
    notifyListeners();
  }

  void setAutoOff(int? minutes) {
    _cancelTimer();
    autoOffMinutes = minutes;
    if (minutes != null) {
      offAt = DateTime.now().add(Duration(minutes: minutes));
      _timer = Timer(Duration(minutes: minutes), () {
        autoOffMinutes = null;
        offAt = null;
        unawaited(setEnabled(false));
      });
    }
    notifyListeners();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    offAt = null;
    autoOffMinutes = null;
  }
}

/// Drawn above every route (MaterialApp.builder); never blocks touches.
class NightLightOverlay extends StatelessWidget {
  const NightLightOverlay({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: NightLight.instance,
        builder: (c, _) {
          final n = NightLight.instance;
          if (!n.enabled) return const SizedBox.shrink();
          return IgnorePointer(
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(
                  color: const Color(0xFFFF8A1E)
                      .withValues(alpha: NightLight.warmFor(n.warmth))),
              ColoredBox(
                  color: Colors.black
                      .withValues(alpha: NightLight.dimFor(n.brightness))),
            ]),
          );
        },
      );
}
