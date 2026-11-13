import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Design System SellerAvatar (§4.5).
/// - Initials in a soft tinted circle (color derived deterministically from name hash
///   using the fixed 6-color muted palette in `AppColors`).
class SellerAvatar extends StatelessWidget {
  const SellerAvatar({
    super.key,
    required this.name,
    this.size = 44.0,
  });

  final String name;
  final double size;

  static String extractInitials(String rawName) {
    final List<String> parts = rawName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      final Characters chars = parts.first.characters;
      return chars.take(2).toString().toUpperCase();
    }
    final String first = parts.first.characters.first;
    final String second = parts[1].characters.first;
    return '$first$second'.toUpperCase();
  }

  static int paletteIndexForName(String rawName, int paletteLength) {
    final String clean = rawName.trim().toLowerCase();
    int hash = 0;
    for (int i = 0; i < clean.length; i++) {
      hash = 31 * hash + clean.codeUnitAt(i);
    }
    return hash.abs() % paletteLength;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int idx = paletteIndexForName(name, colors.avatarPalette.length);
    final Color bg = colors.avatarPalette[idx];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.border,
          width: AppSpacing.borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        extractInitials(name),
        style: context.text.label.copyWith(
          color: colors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
