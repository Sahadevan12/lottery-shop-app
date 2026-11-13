import 'package:flutter/material.dart';

/// Design System Color Tokens (§4.2).
/// Never use raw hex colors directly in widgets; always read via `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.gold,
    required this.goldSoft,
    required this.success,
    required this.danger,
    required this.warning,
    required this.avatarPalette,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color primary;
  final Color primaryPressed;
  final Color onPrimary;
  final Color gold;
  final Color goldSoft;
  final Color success;
  final Color danger;
  final Color warning;
  final List<Color> avatarPalette;

  static const AppColors light = AppColors(
    bg: Color(0xFFF6F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF1EE),
    border: Color(0xFFE2E6E2),
    ink: Color(0xFF0E1A16),
    inkMuted: Color(0xFF5B6B65),
    inkFaint: Color(0xFF8C9A94),
    primary: Color(0xFF0B6E4F),
    primaryPressed: Color(0xFF08513A),
    onPrimary: Color(0xFFFFFFFF),
    gold: Color(0xFFD9A21B),
    goldSoft: Color(0xFFFBF3DC),
    success: Color(0xFF1F9D55),
    danger: Color(0xFFD64545),
    warning: Color(0xFFC77700),
    avatarPalette: <Color>[
      Color(0xFFDCECE6),
      Color(0xFFE4E8F4),
      Color(0xFFF3E6DF),
      Color(0xFFE9E2F2),
      Color(0xFFE0ECEE),
      Color(0xFFEFEAD8),
    ],
  );

  static const AppColors dark = AppColors(
    bg: Color(0xFF0C1210),
    surface: Color(0xFF141C19),
    surfaceAlt: Color(0xFF1B2522),
    border: Color(0xFF26332E),
    ink: Color(0xFFECF2EF),
    inkMuted: Color(0xFF93A39C),
    inkFaint: Color(0xFF62716B),
    primary: Color(0xFF2FB386),
    primaryPressed: Color(0xFF25916C),
    onPrimary: Color(0xFF04130D),
    gold: Color(0xFFF2BE3D),
    goldSoft: Color(0xFF2B2412),
    success: Color(0xFF3CCB7F),
    danger: Color(0xFFF06A6A),
    warning: Color(0xFFF0A43A),
    avatarPalette: <Color>[
      Color(0xFF1A332A),
      Color(0xFF21293B),
      Color(0xFF362822),
      Color(0xFF2B2338),
      Color(0xFF1D3136),
      Color(0xFF332E1E),
    ],
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? primary,
    Color? primaryPressed,
    Color? onPrimary,
    Color? gold,
    Color? goldSoft,
    Color? success,
    Color? danger,
    Color? warning,
    List<Color>? avatarPalette,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      onPrimary: onPrimary ?? this.onPrimary,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      avatarPalette: avatarPalette ?? this.avatarPalette,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      avatarPalette: avatarPalette,
    );
  }
}
