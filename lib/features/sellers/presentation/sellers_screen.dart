import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/seller_entities.dart';
import 'add_edit_seller_sheet.dart';
import 'sellers_controller.dart';

/// Sellers Tab — Tab 3 (§8.4, A.3).
/// - Search bar + sort chips (`Highest due`, `Name`, `Recent`) + `Inactive` filter chip.
/// - Seller cards with avatar, name, area, tickets currently with them, and balance due.
/// - Bottom primary action: "Add seller".
class SellersScreen extends ConsumerStatefulWidget {
  const SellersScreen({super.key});

  @override
  ConsumerState<SellersScreen> createState() => _SellersScreenState();
}

class _SellersScreenState extends ConsumerState<SellersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final SellersState state = ref.watch(sellersControllerProvider);
    final SellersController controller =
        ref.read(sellersControllerProvider.notifier);

    final List<SellerSummary> visibleSellers = state.visibleSellers;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sellersScreenTitle),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screenHorizontal),
            child: SyncStatusPill(
              status: SyncStatus.synced,
              label: l10n.syncStatusSynced,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: controller.loadSellers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            // 1. Search Bar
            AppTextField(
              label: l10n.navSellers,
              controller: _searchController,
              hintText: l10n.sellersSearchHint,
              onChanged: controller.setSearchQuery,
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Sort + Inactive Filter Chips (§8.4, A.3)
            SizedBox(
              height: AppSpacing.minTouchTarget,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  AppChip(
                    label: l10n.sortHighestDue,
                    selected: state.sortMode == SellerSortMode.highestDue,
                    onTap: () =>
                        controller.setSortMode(SellerSortMode.highestDue),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                    label: l10n.sortName,
                    selected: state.sortMode == SellerSortMode.name,
                    onTap: () => controller.setSortMode(SellerSortMode.name),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                    label: l10n.sortRecent,
                    selected: state.sortMode == SellerSortMode.recent,
                    onTap: () => controller.setSortMode(SellerSortMode.recent),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                    label: l10n.filterInactive,
                    selected: state.showInactive,
                    onTap: () =>
                        controller.toggleShowInactive(!state.showInactive),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 3. Sellers List or Empty State
            if (state.isLoading)
              SkeletonLoader.list(itemCount: 4, itemHeight: 88)
            else if (visibleSellers.isEmpty)
              AppCard(
                child: EmptyState(
                  title: l10n.sellersEmptyTitle,
                  message: l10n.sellersEmptyBody,
                  actionLabel: l10n.sellersEmptyCta,
                  icon: Icons.people_outline_rounded,
                  onAction: () => AddEditSellerSheet.show(context: context),
                ),
              )
            else
              ...visibleSellers.map((SellerSummary summary) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _SellerListCard(
                    summary: summary,
                    onTap: () =>
                        context.push('/sellers/${summary.seller.id}'),
                  ),
                );
              }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.md,
          ),
          child: AppButton(
            label: l10n.addSellerAction,
            leadingIcon: Icons.person_add_alt_1_rounded,
            onPressed: () => AddEditSellerSheet.show(context: context),
          ),
        ),
      ),
    );
  }
}

class _SellerListCard extends StatelessWidget {
  const _SellerListCard({
    required this.summary,
    required this.onTap,
  });

  final SellerSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final SellerProfile seller = summary.seller;
    final int bal = summary.balancePaise;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          SellerAvatar(name: seller.name),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        seller.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium,
                      ),
                    ),
                    if (!seller.isActive) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.chipRadius),
                          border: Border.all(
                            color: colors.border,
                            width: AppSpacing.borderWidth,
                          ),
                        ),
                        child: Text(
                          l10n.sellerInactiveBadge,
                          style: context.text.caption.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    if (seller.area != null && seller.area!.isNotEmpty)
                      seller.area!,
                    l10n.ticketsWithSellerCount(
                      AppFormatters.count(summary.ticketsWithSeller),
                    ),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (bal == 0)
                Text(
                  l10n.sellerSettledLabel,
                  style: context.text.bodyMedium.copyWith(
                    color: colors.success,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (bal < 0) ...<Widget>[
                MoneyText(
                  paise: bal.abs(),
                  tone: MoneyTone.settled,
                  style: context.text.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.sellerAdvanceLabel,
                  style: context.text.caption.copyWith(color: colors.success),
                ),
              ] else
                MoneyText(
                  paise: bal,
                  tone: MoneyTone.balanceDue,
                  style: context.text.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
