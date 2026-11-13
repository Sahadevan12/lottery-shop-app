import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Design System EmptyState (§4.5).
/// - Simple line illustration (SVG), one sentence, one primary action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.confirmation_number_outlined,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String strokeHex =
        colors.primary.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    final String mutedHex =
        colors.border.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);

    // Clean inline line-art SVG illustration matching the current theme tokens
    final String svgMarkup = '''
<svg width="96" height="96" viewBox="0 0 96 96" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="14" y="24" width="68" height="48" rx="10" stroke="#$mutedHex" stroke-width="2"/>
  <path d="M26 38H54" stroke="#$strokeHex" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M26 48H70" stroke="#$mutedHex" stroke-width="2" stroke-linecap="round"/>
  <path d="M26 58H46" stroke="#$mutedHex" stroke-width="2" stroke-linecap="round"/>
  <circle cx="66" cy="38" r="5" stroke="#$strokeHex" stroke-width="2"/>
</svg>
''';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SvgPicture.string(
            svgMarkup,
            width: 88,
            height: 88,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.h2,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.body.copyWith(color: colors.inkMuted),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              leadingIcon: icon,
            ),
          ],
        ],
      ),
    );
  }
}
