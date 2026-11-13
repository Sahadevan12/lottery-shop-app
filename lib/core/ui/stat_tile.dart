import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_card.dart';

/// Design System StatTile (§4.5, §4.6).
/// - Label (caption, muted) + big value (display/h1, tabular) + optional delta chip.
/// - Supports count-up animation (400ms) when numeric values change.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.numericValue,
    this.isCurrency = false,
    this.valueColor,
    this.deltaText,
    this.deltaColor,
    this.onTap,
    this.useDisplaySize = false,
  });

  final String label;
  final int numericValue;
  final bool isCurrency;
  final Color? valueColor;
  final String? deltaText;
  final Color? deltaColor;
  final VoidCallback? onTap;
  final bool useDisplaySize;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextStyle baseStyle =
        useDisplaySize ? context.text.display : context.text.h1;
    final TextStyle valueStyle = baseStyle.copyWith(
      color: valueColor ?? colors.ink,
    );

    final Duration animDuration = context.disableAnimations
        ? Duration.zero
        : AppSpacing.motionCountUp;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: numericValue.toDouble()),
            duration: animDuration,
            curve: AppSpacing.motionCurve,
            builder: (BuildContext context, double animatedValue, _) {
              final int current = animatedValue.round();
              final String text = isCurrency
                  ? AppFormatters.moneyFromRupees(current)
                  : AppFormatters.count(current);
              return Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              );
            },
          ),
          if (deltaText != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: (deltaColor ?? colors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              ),
              child: Text(
                deltaText!,
                style: context.text.caption.copyWith(
                  color: deltaColor ?? colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
