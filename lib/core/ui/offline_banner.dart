import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../network/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// Banner shown on cached read-only screens when the device is offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({
    super.key,
    this.cachedAt,
    this.onRetry,
  });

  final DateTime? cachedAt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final String label = cachedAt != null
        ? l10n.offlineBannerWithTime(DateFormat.jm().format(cachedAt!.toLocal()))
        : l10n.offlineBannerNoTime;

    return AppCard(
      backgroundColor: colors.warning.withValues(alpha: 0.14),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_rounded, color: colors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: context.text.caption.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                unawaited(ref.read(isOnlineProvider.notifier).probeOnline());
                onRetry?.call();
              },
              child: Text(l10n.retryAction),
            ),
        ],
      ),
    );
  }
}
