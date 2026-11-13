import 'package:flutter/material.dart';

/// Design System Spacing, Shape, Elevation, and Motion Tokens (§4.4, §4.6).
abstract final class AppSpacing {
  // 4-pt grid tokens
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Screen horizontal padding
  static const double screenHorizontal = 20.0;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
  );

  // Corner radii
  static const double cardRadius = 20.0;
  static const double buttonRadius = 14.0;
  static const double inputRadius = 14.0;
  static const double chipRadius = 999.0;
  static const double sheetTopRadius = 28.0;

  // Touch target sizes
  static const double minTouchTarget = 48.0;
  static const double primaryButtonHeight = 56.0;

  // Hairline border width
  static const double borderWidth = 1.0;

  // Soft shadow for floating elements ONLY (FAB, bottom sheet)
  // 0 8 24 rgba(14,26,22,0.08)
  static const List<BoxShadow> floatingShadow = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(14, 26, 22, 0.08),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  // Motion tokens (§4.6)
  static const Duration motionFast = Duration(milliseconds: 200);
  static const Duration motionCountUp = Duration(milliseconds: 400);
  static const Duration staggerStep = Duration(milliseconds: 30);
  static const Curve motionCurve = Curves.easeOutCubic;
}
