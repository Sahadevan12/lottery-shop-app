import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../results/domain/result_entities.dart';
import '../../results/presentation/results_controller.dart';
import '../../stock/domain/stock_entities.dart';
import '../../stock/presentation/stock_controller.dart';
import '../domain/ledger_math.dart';
import '../domain/seller_entities.dart';
import 'add_edit_seller_sheet.dart';
import 'balance_breakdown_sheet.dart';
import 'give_tickets_sheet.dart';
import 'record_payment_sheet.dart';
import 'return_tickets_sheet.dart';
import 'seller_detail_tabs.dart';
import 'seller_statement_share.dart';
import 'sellers_controller.dart';

/// Seller Detail Screen (§8.4, A.2, A.3, A.6).
class SellerDetailScreen extends ConsumerStatefulWidget {
  const SellerDetailScreen({
    super.key,
    required this.sellerId,
  });

  final String sellerId;

  @override
  ConsumerState<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends ConsumerState<SellerDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future<void>.microtask(() {
      ref
          .read(sellersControllerProvider.notifier)
          .loadSellerDetail(widget.sellerId);
      ref
          .read(resultsControllerProvider.notifier)
          .loadSellerWins(widget.sellerId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmReverseEntry(
    LedgerEntry entry,
    AppLocalizations l10n,
  ) async {
    final bool confirmed = await ConfirmDialog.show(
      context: context,
      title: l10n.reverseEntryTitle,
      message: l10n.reverseEntryBody,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.reverseEntryAction,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final bool ok = await ref
        .read(sellersControllerProvider.notifier)
        .reverseLedgerEntry(sellerId: widget.sellerId, entryId: entry.id);
    if (!mounted) {
      return;
    }
    if (ok) {
      AppSnackbar.show(context, message: l10n.entryReversedSuccess);
    } else {
      final String? err = ref.read(sellersControllerProvider).errorMessage;
      AppSnackbar.show(
        context,
        message: RpcErrorMapper.toLocalizedMessage(err ?? '', l10n),
        isError: true,
      );
    }
  }

  Future<void> _toggleActive(
    SellerProfile seller,
    AppLocalizations l10n,
  ) async {
    if (seller.isActive) {
      final bool confirmed = await ConfirmDialog.show(
        context: context,
        title: l10n.deactivateSellerTitle,
        message: l10n.deactivateSellerBody,
        cancelLabel: l10n.cancelAction,
        confirmLabel: l10n.deactivateSellerAction,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    final bool ok = await ref
        .read(sellersControllerProvider.notifier)
        .setSellerActive(
          sellerId: seller.id,
          isActive: !seller.isActive,
        );
    if (!mounted) {
      return;
    }
    if (ok) {
      AppSnackbar.show(
        context,
        message: seller.isActive
            ? l10n.sellerDeactivatedSuccess
            : l10n.sellerReactivatedSuccess,
      );
    }
  }

  Future<void> _deleteSeller(
    SellerProfile seller,
    AppLocalizations l10n,
  ) async {
    final bool confirmed = await ConfirmDialog.show(
      context: context,
      title: l10n.deleteSellerTitle,
      message: l10n.deleteSellerBody,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final bool ok = await ref
        .read(sellersControllerProvider.notifier)
        .deleteSeller(seller.id);
    if (!mounted) {
      return;
    }
    if (ok) {
      AppSnackbar.show(context, message: l10n.sellerDeletedSuccess);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final SellersState sellersState = ref.watch(sellersControllerProvider);
    final StockState stockState = ref.watch(stockControllerProvider);
    final ResultsState resultsState = ref.watch(resultsControllerProvider);

    final SellerSummary? summary = sellersState.summaryFor(widget.sellerId);
    if (summary == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: AppSpacing.screenPadding,
          child: SkeletonLoader.list(itemCount: 3, itemHeight: 80),
        ),
      );
    }

    final SellerProfile seller = summary.seller;
    final List<LedgerEntry> entries = sellersState.ledgerFor(seller.id);
    final List<TicketItem> tickets = sellersState.ticketsFor(seller.id);

    final Map<String, LotteryDraw> drawsById = <String, LotteryDraw>{
      for (final LotteryDraw d in stockState.draws) d.id: d,
    };
    final SellerBalanceBreakdown breakdown = LedgerMath.computeBalanceBreakdown(
      entries: entries,
      drawsById: drawsById,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(seller.name),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.shareStatementAction,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => SellerStatementShare.shareStatement(
              seller: seller,
              breakdown: breakdown,
              entries: entries,
              l10n: l10n,
            ),
          ),
          IconButton(
            tooltip: l10n.editSellerTitle,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => AddEditSellerSheet.show(
              context: context,
              existingSeller: seller,
            ),
          ),
          IconButton(
            tooltip: seller.isActive
                ? l10n.deactivateSellerAction
                : l10n.reactivateSellerAction,
            icon: Icon(
              seller.isActive
                  ? Icons.person_off_outlined
                  : Icons.person_add_alt_1_outlined,
            ),
            onPressed: () => _toggleActive(seller, l10n),
          ),
          if (summary.canDeleteDirectly)
            IconButton(
              tooltip: l10n.deleteAction,
              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              onPressed: () => _deleteSeller(seller, l10n),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. Tappable Hero Balance Card (§8.4, A.6)
                AppCard(
                  onTap: () async {
                    final SellerBalanceBreakdown serverBreakdown = await ref
                        .read(sellersControllerProvider.notifier)
                        .fetchSellerBalanceBreakdown(seller.id);
                    if (!context.mounted) {
                      return;
                    }
                    await BalanceBreakdownSheet.show(
                      context: context,
                      sellerName: seller.name,
                      breakdown: serverBreakdown,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.sellerBalanceDueLabel,
                              style: context.text.caption.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            MoneyText(
                              paise: summary.balancePaise,
                              tone: MoneyTone.balanceDue,
                              style: context.text.display,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.info_outline_rounded,
                        color: colors.inkMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Three Action Buttons (§8.4)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        label: l10n.giveTicketsShortAction,
                        variant: AppButtonVariant.secondary,
                        onPressed: seller.isActive
                            ? () => GiveTicketsSheet.show(
                                  context: context,
                                  initialSeller: seller,
                                )
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: l10n.takeReturnAction,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => ReturnTicketsSheet.show(
                          context: context,
                          seller: seller,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: l10n.recordPaymentShortAction,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => RecordPaymentSheet.show(
                          context: context,
                          initialSeller: seller,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Tabs: Ledger | Tickets | Wins (§8.4)
          TabBar(
            controller: _tabController,
            labelColor: colors.primary,
            unselectedLabelColor: colors.inkMuted,
            indicatorColor: colors.primary,
            tabs: <Widget>[
              Tab(text: l10n.sellerTabLedger),
              Tab(text: l10n.sellerTabTickets),
              Tab(text: l10n.sellerTabWins),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                SellerLedgerTab(
                  entries: entries,
                  onReverseEntry: (LedgerEntry e) =>
                      _confirmReverseEntry(e, l10n),
                  onGiveTickets: seller.isActive
                      ? () => GiveTicketsSheet.show(
                            context: context,
                            initialSeller: seller,
                          )
                      : null,
                ),
                SellerTicketsTab(
                  tickets: tickets,
                  onGiveTickets: seller.isActive
                      ? () => GiveTicketsSheet.show(
                            context: context,
                            initialSeller: seller,
                          )
                      : null,
                ),
                SellerWinsTab(
                  wins: resultsState.winsForSeller(seller.id),
                  onChangeClaimStatus:
                      (WinningTicket win, WinClaimStatus status) async {
                    final bool ok = await ref
                        .read(resultsControllerProvider.notifier)
                        .updateWinClaimStatus(
                          drawId: win.drawId,
                          winId: win.id,
                          status: status,
                          sellerId: seller.id,
                        );
                    if (!context.mounted) {
                      return;
                    }
                    if (ok) {
                      AppSnackbar.show(
                        context,
                        message: l10n.claimStatusUpdatedSuccess,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
