import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Design System SkeletonLoader (§4.5, §4.6).
/// - Shimmer placeholders matching final layout (never a lone center spinner on a full screen).
/// - Respects `MediaQuery.disableAnimations`.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.height = 76,
    this.width = double.infinity,
    this.borderRadius = AppSpacing.cardRadius,
  });

  final double height;
  final double width;
  final double borderRadius;

  /// Builds a staggered list of skeleton card placeholders.
  static Widget list({int itemCount = 4, double itemHeight = 80}) {
    return Column(
      children: List<Widget>.generate(itemCount, (int index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == itemCount - 1 ? 0 : AppSpacing.md,
          ),
          child: SkeletonLoader(height: itemHeight),
        );
      }),
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    if (context.disableAnimations) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: colors.border),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final Color shimmerColor = Color.lerp(
          colors.surfaceAlt,
          colors.border,
          _controller.value * 0.65,
        )!;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: colors.border,
              width: AppSpacing.borderWidth,
            ),
          ),
        );
      },
    );
  }
}
