import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Design System Card (§4.4, §4.5).
/// - `surface` background + 1px `border` + radius 20 + padding 16.
/// - No heavy shadows.
/// - Optional `isWinHighlight` uses `goldSoft` fill and `gold` border for wins.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.isWinHighlight = false,
    this.backgroundColor,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isWinHighlight;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color fill = backgroundColor ??
        (isWinHighlight ? colors.goldSoft : colors.surface);
    final Color stroke =
        borderColor ?? (isWinHighlight ? colors.gold : colors.border);

    final Widget cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: stroke,
          width: AppSpacing.borderWidth,
        ),
      ),
      child: child,
    );

    if (onTap == null) {
      return Semantics(
        label: semanticLabel,
        child: cardContent,
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: cardContent,
      ),
    );
  }
}
