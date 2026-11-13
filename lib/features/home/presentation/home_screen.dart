import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/shop_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../sellers/domain/seller_entities.dart';
import '../../sellers/presentation/give_tickets_sheet.dart';
import '../../sellers/presentation/record_payment_sheet.dart';
import '../../sellers/presentation/sellers_controller.dart';
import '../data/home_repository.dart';
import 'home_controller.dart';

/// Home Screen — Tab 1 (§8.2).
/// Displays greeting, sync pill, shop name, live 2×2 StatTiles, quick actions,
/// and top due sellers.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onGoToStock,
    this.onGoToSellers,
    this.onGoToResults,
  });

  final VoidCallback onGoToStock;
  final VoidCallback? onGoToSellers;
  final VoidCallback? onGoToResults;

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
    final HomeState homeState = ref.watch(homeControllerProvider);
    final DashboardTodayData? dashboard = homeState.dashboard;
    final SellersState sellersState = ref.watch(sellersControllerProvider);

    final String ownerName = shop?.ownerName ?? '';
    final String shopName = shop?.name ?? l10n.appName;
    final int totalDueRupees =
        dashboard != null ? dashboard.totalDueFromSellers.round() : 0;
    final List<SellerSummary> topDue = sellersState.topDueSellers;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
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

            if (dashboard == null) ...<Widget>[
              if (homeState.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                AppCard(
                  backgroundColor: colors.danger.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        homeState.error != null
                            ? RpcErrorMapper.toLocalizedMessage(
                                homeState.error!,
                                l10n,
                              )
                            : l10n.errorGeneric,
                        style: context.text.body.copyWith(color: colors.danger),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: l10n.retryAction,
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            ref.read(homeControllerProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                ),
            ] else ...<Widget>[
              if (homeState.error != null) ...<Widget>[
                AppCard(
                  backgroundColor: colors.danger.withValues(alpha: 0.08),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          RpcErrorMapper.toLocalizedMessage(
                            homeState.error!,
                            l10n,
                          ),
                          style:
                              context.text.caption.copyWith(color: colors.danger),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(homeControllerProvider.notifier).refresh(),
                        child: Text(l10n.retryAction),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (dashboard.todayWinsCount > 0) ...<Widget>[
              AppCard(
                onTap: onGoToResults,
                backgroundColor: colors.gold.withValues(alpha: 0.14),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.emoji_events_rounded, color: colors.gold),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.todayWinsBannerTitle(
                              AppFormatters.count(dashboard.todayWinsCount),
                              AppFormatters.moneyFromRupees(
                                dashboard.todayPrizesTotal.round(),
                              ),
                            ),
                            style: context.text.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (dashboard.unclaimedWinsCount > 0)
                            Text(
                              l10n.unclaimedWinsCountLabel(
                                AppFormatters.count(
                                  dashboard.unclaimedWinsCount,
                                ),
                              ),
                              style: context.text.caption.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (dashboard.toRecoverFromOffice > 0) ...<Widget>[
              AppCard(
                onTap: () => context.push('/reports'),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.account_balance_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.toRecoverOfficeLabel,
                        style: context.text.bodyMedium,
                      ),
                    ),
                    Text(
                      AppFormatters.moneyFromRupees(
                        dashboard.toRecoverFromOffice.round(),
                      ),
                      style: context.text.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 2×2 StatTiles Grid (§8.2) — connected to dashboard_today() RPC
            Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(
                    label: l10n.statInStock,
                    numericValue: dashboard.inStockCount,
                    onTap: onGoToStock,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: l10n.statWithSellers,
                    numericValue: dashboard.withSellerCount,
                    onTap: onGoToSellers ?? onGoToStock,
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
                    numericValue: dashboard.soldCount,
                    onTap: onGoToStock,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: l10n.statDueFromSellers,
                    numericValue: totalDueRupees,
                    isCurrency: true,
                    valueColor:
                        totalDueRupees > 0 ? colors.danger : colors.success,
                    onTap: onGoToSellers,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Quick Actions (§8.2)
            if (sellersState.sellers.isNotEmpty) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: l10n.giveTicketsShortAction,
                      variant: AppButtonVariant.secondary,
                      leadingIcon: Icons.confirmation_number_outlined,
                      onPressed: sellersState.activeSellers.isNotEmpty
                          ? () => GiveTicketsSheet.show(context: context)
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: l10n.recordPaymentShortAction,
                      variant: AppButtonVariant.secondary,
                      leadingIcon: Icons.payments_outlined,
                      onPressed: () =>
                          RecordPaymentSheet.show(context: context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: l10n.viewReportsAction,
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.analytics_outlined,
              onPressed: () => context.push('/reports'),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Top Sellers by Due (§8.2)
            if (topDue.isNotEmpty) ...<Widget>[
              SectionHeader(
                title: l10n.statDueFromSellers,
                actionLabel: l10n.seeAllAction,
                onAction: onGoToSellers,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final SellerSummary s in topDue) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    onTap: () => context.push('/sellers/${s.seller.id}'),
                    child: Row(
                      children: <Widget>[
                        SellerAvatar(name: s.seller.name, size: 38),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                s.seller.name,
                                style: context.text.bodyMedium,
                              ),
                              Text(
                                l10n.ticketsWithSellerCount(
                                  AppFormatters.count(s.ticketsWithSeller),
                                ),
                                style: context.text.caption.copyWith(
                                  color: colors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoneyText(
                          paise: s.balancePaise,
                          tone: MoneyTone.balanceDue,
                          style: context.text.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else if (dashboard.totalTickets == 0)
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
          ],
        ),
        ),
      ),
    );
  }
}
