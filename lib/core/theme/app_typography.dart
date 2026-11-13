import 'package:flutter/material.dart';

/// Design System Typography Tokens (§4.3).
/// - Base size 16sp, never below 13sp.
/// - Malayalam (`ml`) and Tamil (`ta`) get +1sp for legibility.
/// - "Large text" multiplies the entire scale by 1.15.
/// - All numbers use `FontFeature.tabularFigures()`.
/// - Ticket numbers always use `JetBrains Mono`.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.h1,
    required this.h2,
    required this.body,
    required this.bodyMedium,
    required this.label,
    required this.caption,
    required this.ticketMono,
    required this.ticketMonoLarge,
  });

  final TextStyle display;
  final TextStyle h1;
  final TextStyle h2;
  final TextStyle body;
  final TextStyle bodyMedium;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle ticketMono;
  final TextStyle ticketMonoLarge;

  static const String fontInter = 'Inter';
  static const String fontMalayalam = 'NotoSansMalayalam';
  static const String fontTamil = 'NotoSansTamil';
  static const String fontMono = 'JetBrainsMono';

  static String fontFamilyForLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ml':
        return fontMalayalam;
      case 'ta':
        return fontTamil;
      default:
        return fontInter;
    }
  }

  static AppTypography fromConfig({
    required Color ink,
    required Locale locale,
    required bool largeText,
  }) {
    final bool isIndic =
        locale.languageCode == 'ml' || locale.languageCode == 'ta';
    final double indicBump = isIndic ? 1.0 : 0.0;
    final double scale = largeText ? 1.15 : 1.0;
    final String family = fontFamilyForLocale(locale);
    const List<FontFeature> tabular = <FontFeature>[
      FontFeature.tabularFigures(),
    ];

    TextStyle buildStyle({
      required double size,
      required double lineHeight,
      required FontWeight weight,
      String? customFamily,
      double? letterSpacing,
    }) {
      final double adjustedSize = (size + indicBump) * scale;
      final double heightRatio = lineHeight / size;
      return TextStyle(
        fontFamily: customFamily ?? family,
        fontSize: adjustedSize,
        height: heightRatio,
        fontWeight: weight,
        color: ink,
        letterSpacing: letterSpacing,
        fontFeatures: tabular,
      );
    }

    return AppTypography(
      display: buildStyle(
        size: 32,
        lineHeight: 40,
        weight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      h1: buildStyle(
        size: 24,
        lineHeight: 32,
        weight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      h2: buildStyle(
        size: 20,
        lineHeight: 28,
        weight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      body: buildStyle(
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w400,
      ),
      bodyMedium: buildStyle(
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w500,
      ),
      label: buildStyle(
        size: 14,
        lineHeight: 20,
        weight: FontWeight.w500,
      ),
      caption: buildStyle(
        size: 13,
        lineHeight: 18,
        weight: FontWeight.w400,
      ),
      ticketMono: buildStyle(
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w600,
        customFamily: fontMono,
        letterSpacing: 1.2,
      ),
      ticketMonoLarge: buildStyle(
        size: 20,
        lineHeight: 28,
        weight: FontWeight.w700,
        customFamily: fontMono,
        letterSpacing: 1.5,
      ),
    );
  }

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? h1,
    TextStyle? h2,
    TextStyle? body,
    TextStyle? bodyMedium,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? ticketMono,
    TextStyle? ticketMonoLarge,
  }) {
    return AppTypography(
      display: display ?? this.display,
      h1: h1 ?? this.h1,
      h2: h2 ?? this.h2,
      body: body ?? this.body,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      ticketMono: ticketMono ?? this.ticketMono,
      ticketMonoLarge: ticketMonoLarge ?? this.ticketMonoLarge,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) {
      return this;
    }
    return AppTypography(
      display: TextStyle.lerp(display, other.display, t)!,
      h1: TextStyle.lerp(h1, other.h1, t)!,
      h2: TextStyle.lerp(h2, other.h2, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      ticketMono: TextStyle.lerp(ticketMono, other.ticketMono, t)!,
      ticketMonoLarge: TextStyle.lerp(ticketMonoLarge, other.ticketMonoLarge, t)!,
    );
  }
}
