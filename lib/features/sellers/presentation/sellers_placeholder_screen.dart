import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';

/// Sellers Tab Shell — Tab 3 (Full implementation in Phase 3).
class SellersPlaceholderScreen extends StatelessWidget {
  const SellersPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSellers)),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: AppCard(
            child: EmptyState(
              title: l10n.sellersEmptyTitle,
              message: l10n.sellersEmptyBody,
              actionLabel: l10n.sellersEmptyCta,
              onAction: () {},
              icon: Icons.person_add_alt_1_outlined,
            ),
          ),
        ),
      ),
    );
  }
}
