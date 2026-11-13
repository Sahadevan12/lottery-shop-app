import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds Light and Dark ThemeData strictly adhering to §4 Design System.
abstract final class AppTheme {
  static ThemeData build({
    required Brightness brightness,
    required Locale locale,
    required bool largeText,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final AppColors colors = isDark ? AppColors.dark : AppColors.light;
    final AppTypography typography = AppTypography.fromConfig(
      ink: colors.ink,
      locale: locale,
      largeText: largeText,
    );

    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.gold,
      onSecondary: colors.ink,
      error: colors.danger,
      onError: colors.onPrimary,
      surface: colors.surface,
      onSurface: colors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.surface,
      dividerColor: colors.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      fontFamily: AppTypography.fontFamilyForLocale(locale),
      extensions: <ThemeExtension<dynamic>>[
        colors,
        typography,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.h2,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(
            color: colors.border,
            width: AppSpacing.borderWidth,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetTopRadius),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: AppSpacing.borderWidth,
        space: AppSpacing.borderWidth,
      ),
      textTheme: TextTheme(
        displayLarge: typography.display,
        headlineLarge: typography.h1,
        headlineMedium: typography.h2,
        bodyLarge: typography.body,
        bodyMedium: typography.body,
        labelLarge: typography.label,
        bodySmall: typography.caption,
      ),
    );
  }
}

/// Ergonomic BuildContext getters for Design System tokens.
extension AppThemeContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  AppTypography get text =>
      Theme.of(this).extension<AppTypography>() ??
      AppTypography.fromConfig(
        ink: AppColors.light.ink,
        locale: const Locale('en'),
        largeText: false,
      );

  bool get disableAnimations =>
      MediaQuery.maybeOf(this)?.disableAnimations ?? false;
}
