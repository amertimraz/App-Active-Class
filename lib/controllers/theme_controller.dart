// lib/controllers/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const String _keyThemeMode = 'theme_mode'; // 'light' | 'dark'

  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;
  final RxBool isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyThemeMode);
      if (saved == 'dark') {
        _applyTheme(true, persist: false);
        return;
      } else if (saved == 'light') {
        _applyTheme(false, persist: false);
        return;
      }
    } catch (_) {
      // Ignore storage errors and fallback to system preference
    }

    // Fallback: use system preference without requiring BuildContext
    final Brightness platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final bool systemDark = platformBrightness == Brightness.dark;
    _applyTheme(systemDark, persist: false);
  }

  Future<void> _saveThemePreference(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeMode, isDark ? 'dark' : 'light');
    } catch (_) {
      // Ignore storage errors silently
    }
  }

  void toggleTheme() {
    final bool next = !isDarkMode.value;
    _applyTheme(next);
  }

  void setTheme(bool isDark) {
    _applyTheme(isDark);
  }

  void _applyTheme(bool isDark, {bool persist = true}) {
    isDarkMode.value = isDark;
    if (isDark) {
      Get.changeTheme(AppTheme.darkTheme);
      themeMode.value = ThemeMode.dark;
    } else {
      Get.changeTheme(AppTheme.lightTheme);
      themeMode.value = ThemeMode.light;
    }
    if (persist) _saveThemePreference(isDark);
  }
}
