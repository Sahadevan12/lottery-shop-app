import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/shop_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../stock/domain/stock_entities.dart';
import '../../stock/presentation/stock_controller.dart';

/// Home Screen — Tab 1 (§8.2).
/// Displays greeting, sync pill, shop name, and live 2×2 StatTiles connected to today's draw stock.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onGoToStock,
  });

  final VoidCallback onGoToStock;

  String _greeting(AppLocalizations l10n, String ownerName) {
    final int hour = DateTime.now().hour;
    final String displayOwner = ownerName.trim().isEmpty ? 'Owner' : ownerName;
    if (hour < 12) {
      return l10n.greetingMorning(displayOwner);
    }
    if (hour < 17) {
      return l10n.greetingAfternoon(displayOwner);
    }
    return l10n.greetingEvening(displayOwner);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final ShopProfile? shop = ref.watch(authControllerProvider).shop;
    final StockState stockState = ref.watch(stockControllerProvider);
    final DrawStockSummary todaySummary =
        stockState.summaryForDate(DateTime.now());

    final String ownerName = shop?.ownerName ?? '';
    final String shopName = shop?.name ?? l10n.appName;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            // Top Header: Greeting + Shop Name + Sync Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _greeting(l10n, ownerName),
                        style: context.text.h2,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shopName,
                        style: context.text.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SyncStatusPill(
                  status: SyncStatus.synced,
                  label: l10n.syncStatusSynced,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 2×2 StatTiles Grid (§8.2) — connected to today's draw stock
            Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(
                    label: l10n.statInStock,
                    numericValue: todaySummary.inStock,
                    onTap: onGoToStock,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: l10n.statWithSellers,
                    numericValue: todaySummary.withSellers,
                    onTap: onGoToStock,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(
                    label: l10n.statSoldToday,
                    numericValue: todaySummary.sold,
                    onTap: onGoToStock,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: l10n.statDueFromSellers,
                    numericValue: 0,
                    isCurrency: true,
                    valueColor: colors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            if (todaySummary.total == 0)
              AppCard(
                child: EmptyState(
                  title: l10n.homeEmptyTitle,
                  message: l10n.homeEmptyBody,
                  actionLabel: l10n.homeEmptyCta,
                  onAction: onGoToStock,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
