import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Design System TextField (§4.4, §4.5).
/// - Filled `surfaceAlt`, radius 14.
/// - Static label ABOVE the field (never floating).
/// - Helper / error text below.
/// - Supports prefix widget/text (e.g., `+91`), numeric keyboards, and mono font option.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixText,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
    this.obscureText = false,
    this.useMonoFont = false,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? prefixText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool obscureText;
  final bool useMonoFont;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final TextStyle valueStyle =
        useMonoFont ? context.text.ticketMono : context.text.body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: context.text.label.copyWith(color: colors.ink),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          readOnly: readOnly,
          onTap: onTap,
          obscureText: obscureText,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          autofocus: autofocus,
          style: valueStyle.copyWith(color: colors.ink),
          cursorColor: colors.primary,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: colors.surfaceAlt,
            hintText: hintText,
            hintStyle: context.text.body.copyWith(color: colors.inkFaint),
            prefixIcon: prefixText != null
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.sm,
                    ),
                    child: Align(
                      widthFactor: 1.0,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        prefixText!,
                        style: context.text.bodyMedium.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ),
                  )
                : null,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md + 2,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: BorderSide(
                color: hasError ? colors.danger : colors.border,
                width: AppSpacing.borderWidth,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: BorderSide(
                color: hasError ? colors.danger : colors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: context.text.caption.copyWith(color: colors.danger),
          ),
        ] else if (helperText != null && helperText!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText!,
            style: context.text.caption.copyWith(color: colors.inkMuted),
          ),
        ],
      ],
    );
  }
}
