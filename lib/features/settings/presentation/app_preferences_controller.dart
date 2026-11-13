import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_preferences.dart';

final Provider<SharedPreferences?> sharedPreferencesProvider =
    Provider<SharedPreferences?>((Ref ref) => null);

final NotifierProvider<AppPreferencesController, AppPreferences>
    appPreferencesProvider =
    NotifierProvider<AppPreferencesController, AppPreferences>(
  AppPreferencesController.new,
);

class AppPreferencesController extends Notifier<AppPreferences> {
  static const String _keyLocale = 'pref_locale';
  static const String _keyTheme = 'pref_theme';
  static const String _keyLargeText = 'pref_large_text';
  static const String _keyPickedLang = 'pref_picked_language';
  static const String _keySeenWelcome = 'pref_seen_welcome';

  @override
  AppPreferences build() {
    final SharedPreferences? prefs = ref.watch(sharedPreferencesProvider);
    if (prefs == null) {
      return const AppPreferences();
    }
    final String langCode = prefs.getString(_keyLocale) ?? 'ml';
    final String themeStr = prefs.getString(_keyTheme) ?? 'system';
    final bool largeText = prefs.getBool(_keyLargeText) ?? false;
    final bool hasPickedLanguage = prefs.getBool(_keyPickedLang) ?? false;
    final bool hasSeenWelcome = prefs.getBool(_keySeenWelcome) ?? false;

    final ThemeMode mode;
    switch (themeStr) {
      case 'light':
        mode = ThemeMode.light;
      case 'dark':
        mode = ThemeMode.dark;
      default:
        mode = ThemeMode.system;
    }

    return AppPreferences(
      locale: Locale(langCode),
      themeMode: mode,
      largeText: largeText,
      hasPickedLanguage: hasPickedLanguage,
      hasSeenWelcome: hasSeenWelcome,
    );
  }

  Future<void> setLocale(Locale locale, {bool markPicked = true}) async {
    state = state.copyWith(
      locale: locale,
      hasPickedLanguage: markPicked ? true : state.hasPickedLanguage,
    );
    final SharedPreferences? prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(_keyLocale, locale.languageCode);
    if (markPicked) {
      await prefs?.setBool(_keyPickedLang, true);
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    final SharedPreferences? prefs = ref.read(sharedPreferencesProvider);
    final String value = switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs?.setString(_keyTheme, value);
  }

  Future<void> setLargeText(bool enabled) async {
    state = state.copyWith(largeText: enabled);
    final SharedPreferences? prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_keyLargeText, enabled);
  }

  Future<void> completeWelcome() async {
    state = state.copyWith(hasSeenWelcome: true);
    final SharedPreferences? prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_keySeenWelcome, true);
  }
}
