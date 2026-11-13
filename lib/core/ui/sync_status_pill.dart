import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum SyncStatus {
  synced,
  syncing,
  offline,
}

/// Small "Syncing… / Synced ✓ / Offline" pill in the app bar (§4.7 #5).
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({
    super.key,
    required this.status,
    required this.label,
  });

  final SyncStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color dotColor;
    switch (status) {
      case SyncStatus.synced:
        dotColor = colors.success;
      case SyncStatus.syncing:
        dotColor = colors.primary;
      case SyncStatus.offline:
        dotColor = colors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(
          color: colors.border,
          width: AppSpacing.borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            label,
            style: context.text.caption.copyWith(
              color: colors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
