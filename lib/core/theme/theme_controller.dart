import 'dart:async';

import 'package:flutter/material.dart';

import '../services/local_music_service.dart';

import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  StreamSubscription<int?>? _trackSubscription;
  Color? _artAccent;
  Future<void> updateArtworkColor() async {
    if (!dynamicColors) return;
    try {
      final tag =
          LocalMusicService.instance.player.sequenceState.currentSource?.tag;
      final id = int.tryParse(tag?.id?.toString() ?? '');
      if (id == null) return;
      final bytes = await LocalMusicService.instance.audioQuery.queryArtwork(
        id,
        ArtworkType.AUDIO,
        size: 128,
      );
      if (bytes == null) return;
      final scheme = await ColorScheme.fromImageProvider(
        provider: MemoryImage(bytes),
        brightness: Brightness.dark,
      );
      _artAccent = scheme.primary;
      notifyListeners();
    } catch (_) {
      /* Use the selected accent when artwork is missing. */
    }
  }

  @override
  void dispose() {
    _trackSubscription?.cancel();
    super.dispose();
  }

  ThemeMode _themeMode = ThemeMode.dark;
  Color accent = Colors.purpleAccent;
  bool dynamicColors = false;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isSystem => _themeMode == ThemeMode.system;
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final mode = p.getString('app_theme_mode');
    _themeMode = mode == 'light'
        ? ThemeMode.light
        : mode == 'system'
        ? ThemeMode.system
        : ThemeMode.dark;
    accent = Color(p.getInt('b_music02_accent') ?? 0xFFA53CFF);
    dynamicColors = p.getBool('b_music02_dynamic_colors') ?? false;
    _trackSubscription ??= LocalMusicService.instance.player.currentIndexStream
        .listen((_) => updateArtworkColor());
    unawaited(updateArtworkColor());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('app_theme_mode', mode.name);
  }

  Future<void> setAccent(Color color) async {
    accent = color;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('b_music02_accent', color.toARGB32());
  }

  Future<void> setDynamic(bool enabled) async {
    dynamicColors = enabled;
    if (enabled) await updateArtworkColor();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('b_music02_dynamic_colors', enabled);
  }

  Future<void> setDark() => setThemeMode(ThemeMode.dark);
  Future<void> setLight() => setThemeMode(ThemeMode.light);
  Future<void> setSystem() => setThemeMode(ThemeMode.system);
  ThemeData apply(ThemeData base) {
    final color = dynamicColors ? (_artAccent ?? accent) : accent;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: color, secondary: color),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: color,
        thumbColor: color,
      ),
    );
  }
}

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);
  static ThemeController of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<ThemeControllerScope>()!.notifier!;
}
