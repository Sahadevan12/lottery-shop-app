import 'package:flutter/material.dart';

@immutable
class AppPreferences {
  const AppPreferences({
    this.locale = const Locale('ml'),
    this.themeMode = ThemeMode.system,
    this.largeText = false,
    this.hasPickedLanguage = false,
    this.hasSeenWelcome = false,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final bool largeText;
  final bool hasPickedLanguage;
  final bool hasSeenWelcome;

  AppPreferences copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? largeText,
    bool? hasPickedLanguage,
    bool? hasSeenWelcome,
  }) {
    return AppPreferences(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      largeText: largeText ?? this.largeText,
      hasPickedLanguage: hasPickedLanguage ?? this.hasPickedLanguage,
      hasSeenWelcome: hasSeenWelcome ?? this.hasSeenWelcome,
    );
  }
}
