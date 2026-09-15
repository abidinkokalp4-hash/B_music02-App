import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
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
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('b_music02_dynamic_colors', enabled);
  }

  Future<void> setDark() => setThemeMode(ThemeMode.dark);
  Future<void> setLight() => setThemeMode(ThemeMode.light);
  Future<void> setSystem() => setThemeMode(ThemeMode.system);
  ThemeData apply(ThemeData base) {
    final color = dynamicColors
        ? Color.lerp(accent, Colors.pink, DateTime.now().month / 24)!
        : accent;
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
