import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
}

/// Design System Button (§4.4, §4.5).
/// - Primary buttons are 56dp tall and full-width by default.
/// - Minimum touch target is 48×48dp.
/// - Loading state replaces label with a crisp spinner.
/// - Triggers light haptic impact on tap.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final String? semanticLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _handleTap() {
    if (!_isEnabled) {
      return;
    }
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    final Color bgColor;
    final Color fgColor;
    final BorderSide borderSide;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bgColor = !_isEnabled
            ? colors.surfaceAlt
            : (_isPressed ? colors.primaryPressed : colors.primary);
        fgColor = !_isEnabled ? colors.inkFaint : colors.onPrimary;
        borderSide = BorderSide.none;
      case AppButtonVariant.secondary:
        bgColor = _isPressed ? colors.surfaceAlt : colors.surface;
        fgColor = !_isEnabled ? colors.inkFaint : colors.ink;
        borderSide = BorderSide(
          color: !_isEnabled ? colors.border : colors.inkMuted,
          width: AppSpacing.borderWidth,
        );
      case AppButtonVariant.ghost:
        bgColor = _isPressed ? colors.surfaceAlt : Colors.transparent;
        fgColor = !_isEnabled ? colors.inkFaint : colors.primary;
        borderSide = BorderSide.none;
      case AppButtonVariant.danger:
        bgColor = !_isEnabled
            ? colors.surfaceAlt
            : (_isPressed
                ? colors.danger.withValues(alpha: 0.85)
                : colors.danger);
        fgColor = !_isEnabled ? colors.inkFaint : colors.onPrimary;
        borderSide = BorderSide.none;
    }

    final double height = widget.variant == AppButtonVariant.primary ||
            widget.variant == AppButtonVariant.danger
        ? AppSpacing.primaryButtonHeight
        : AppSpacing.minTouchTarget;

    final Widget child = widget.isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          )
        : Row(
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.leadingIcon != null) ...<Widget>[
                Icon(widget.leadingIcon, size: 20, color: fgColor),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.label.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.trailingIcon != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(widget.trailingIcon, size: 20, color: fgColor),
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel:
            _isEnabled ? () => setState(() => _isPressed = false) : null,
        onTap: _isEnabled ? _handleTap : null,
        child: AnimatedContainer(
          duration: context.disableAnimations
              ? Duration.zero
              : AppSpacing.motionFast,
          curve: AppSpacing.motionCurve,
          constraints: BoxConstraints(
            minHeight: height,
            minWidth: widget.fullWidth
                ? double.infinity
                : AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            border: borderSide == BorderSide.none
                ? null
                : Border.fromBorderSide(borderSide),
          ),
          child: Center(
            heightFactor: 1.0,
            widthFactor: widget.fullWidth ? null : 1.0,
            child: child,
          ),
        ),
      ),
    );
  }
}
