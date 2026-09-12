import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const String _storageKey =
      'app_theme_mode';

  ThemeMode _themeMode =
      ThemeMode.system;

  ThemeMode get themeMode =>
      _themeMode;

  bool get isSystem =>
      _themeMode ==
      ThemeMode.system;

  bool get isDark =>
      _themeMode ==
      ThemeMode.dark;

  bool get isLight =>
      _themeMode ==
      ThemeMode.light;

  Future<void> load() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final savedMode =
        prefs.getString(
      _storageKey,
    );

    switch (savedMode) {
      case 'dark':
        _themeMode =
            ThemeMode.dark;
        break;

      case 'light':
        _themeMode =
            ThemeMode.light;
        break;

      default:
        _themeMode =
            ThemeMode.system;
    }

    notifyListeners();
  }

  Future<void> setSystem() async {
    await _setThemeMode(
      ThemeMode.system,
      'system',
    );
  }

  Future<void> setDark() async {
    await _setThemeMode(
      ThemeMode.dark,
      'dark',
    );
  }

  Future<void> setLight() async {
    await _setThemeMode(
      ThemeMode.light,
      'light',
    );
  }

  Future<void> setThemeMode(
    ThemeMode mode,
  ) async {
    switch (mode) {
      case ThemeMode.dark:
        await setDark();
        break;

      case ThemeMode.light:
        await setLight();
        break;

      case ThemeMode.system:
        await setSystem();
        break;
    }
  }

  Future<void> _setThemeMode(
    ThemeMode mode,
    String value,
  ) async {
    _themeMode = mode;

    notifyListeners();

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      _storageKey,
      value,
    );
  }
}

class ThemeControllerScope
    extends InheritedNotifier<
        ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController
        controller,
    required super.child,
  }) : super(
          notifier: controller,
        );

  static ThemeController of(
    BuildContext context,
  ) {
    final scope =
        context
            .dependOnInheritedWidgetOfExactType<
                ThemeControllerScope>();

    assert(
      scope != null,
      'ThemeControllerScope bulunamadı.',
    );

    return scope!.notifier!;
  }
}
