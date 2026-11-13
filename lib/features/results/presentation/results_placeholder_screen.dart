import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';

/// Results Tab Shell — Tab 4 (Full implementation in Phase 4).
class ResultsPlaceholderScreen extends StatelessWidget {
  const ResultsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navResults)),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: AppCard(
            child: EmptyState(
              title: l10n.resultsEmptyTitle,
              message: l10n.resultsEmptyBody,
              actionLabel: l10n.resultsEmptyCta,
              onAction: () {},
              icon: Icons.emoji_events_outlined,
            ),
          ),
        ),
      ),
    );
  }
}
