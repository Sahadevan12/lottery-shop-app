import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Design System Floating Snackbar (§4.5).
/// - Floating, rounded, with optional Undo action for reversible operations.
abstract final class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    String? undoLabel,
    VoidCallback? onUndo,
    bool isError = false,
  }) {
    final AppColors colors = context.colors;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        backgroundColor: isError ? colors.danger : colors.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        content: Text(
          message,
          style: context.text.body.copyWith(
            color: colors.surface,
          ),
        ),
        action: (undoLabel != null && onUndo != null)
            ? SnackBarAction(
                label: undoLabel,
                textColor: colors.gold,
                onPressed: onUndo,
              )
            : null,
      ),
    );
  }
}
