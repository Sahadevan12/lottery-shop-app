import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../stock/domain/stock_entities.dart';
import '../../stock/presentation/stock_controller.dart';
import '../domain/result_entities.dart';
import 'enter_results_sheet.dart';
import 'results_controller.dart';
import 'win_results_view.dart';
import 'winner_poster_share.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  String? _loadedDrawId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_ensureInitialDrawLoaded);
  }

  void _ensureInitialDrawLoaded() {
    final StockState stockState = ref.read(stockControllerProvider);
    final LotteryDraw? draw = stockState.selectedDraw ??
        (stockState.draws.isNotEmpty ? stockState.draws.first : null);
    if (draw != null && _loadedDrawId != draw.id) {
      _loadedDrawId = draw.id;
      ref.read(resultsControllerProvider.notifier).loadDraw(draw.id);
    }
  }

  Future<void> _confirmCloseDraw(
    LotteryDraw draw,
    AppLocalizations l10n,
  ) async {
    final ResultsController controller =
        ref.read(resultsControllerProvider.notifier);
    final int withSellerCount =
        await controller.countWithSellerTickets(draw.id);
    if (!mounted) {
      return;
    }
    final String body = withSellerCount > 0
        ? l10n.closeDrawConfirmBody(AppFormatters.count(withSellerCount))
        : l10n.closeDrawConfirmZeroBody;

    final bool confirmed = await ConfirmDialog.show(
      context: context,
      title: l10n.closeDrawConfirmTitle,
      message: body,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.closeDrawAction,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final bool ok = await controller.closeDraw(draw.id);
    if (!mounted) {
      return;
    }
    if (ok) {
      AppSnackbar.show(context, message: l10n.drawClosedSuccess);
    } else {
      final Object? err = ref.read(resultsControllerProvider).lastError;
      AppSnackbar.show(
        context,
        message: RpcErrorMapper.toLocalizedMessage(err ?? '', l10n),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final StockState stockState = ref.watch(stockControllerProvider);
    final ResultsState resultsState = ref.watch(resultsControllerProvider);

    final List<LotteryDraw> draws = stockState.draws;
    LotteryDraw? selectedDraw;
    final String? activeId =
        resultsState.selectedDrawId ?? stockState.selectedDraw?.id;
    for (final LotteryDraw d in draws) {
      if (d.id == activeId) {
        selectedDraw = d;
        break;
      }
    }
    selectedDraw ??= draws.isNotEmpty ? draws.first : null;

    if (selectedDraw != null && _loadedDrawId != selectedDraw.id) {
      _loadedDrawId = selectedDraw.id;
      Future<void>.microtask(
        () => ref
            .read(resultsControllerProvider.notifier)
            .loadDraw(selectedDraw!.id),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navResults),
      ),
      body: draws.isEmpty
          ? Padding(
              padding: AppSpacing.screenPadding,
              child: EmptyState(
                title: l10n.resultsEmptyTitle,
                message: l10n.resultsEmptyBody,
                icon: Icons.emoji_events_outlined,
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(resultsControllerProvider.notifier)
                  .loadDraw(selectedDraw!.id),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  SizedBox(
                    height: AppSpacing.minTouchTarget,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        for (final LotteryDraw d in draws) ...<Widget>[
                          AppChip(
                            label:
                                '${d.lotteryName} (${AppFormatters.shortDate(d.drawDate)})',
                            badgeText: d.drawNumber,
                            selected: selectedDraw?.id == d.id,
                            onTap: () {
                              _loadedDrawId = d.id;
                              ref
                                  .read(resultsControllerProvider.notifier)
                                  .loadDraw(d.id);
                            },
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (selectedDraw != null) ...<Widget>[
                    _buildVerifyBanner(colors, l10n, context),
                    const SizedBox(height: AppSpacing.md),
                    if (resultsState.isLoading)
                      SkeletonLoader.list(itemCount: 3, itemHeight: 88)
                    else
                      _buildDrawBody(
                        context: context,
                        draw: selectedDraw,
                        resultsState: resultsState,
                        l10n: l10n,
                        colors: colors,
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildVerifyBanner(
    AppColors colors,
    AppLocalizations l10n,
    BuildContext context,
  ) {
    return AppCard(
      backgroundColor: colors.surfaceAlt,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.verified_outlined, size: 18, color: colors.inkMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.verifyOfficialResultNote,
              style: context.text.caption.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawBody({
    required BuildContext context,
    required LotteryDraw draw,
    required ResultsState resultsState,
    required AppLocalizations l10n,
    required AppColors colors,
  }) {
    final List<DrawPrizeTier> tiers = resultsState.tiersFor(draw.id);
    final List<DrawResultEntry> existingResults =
        resultsState.resultsFor(draw.id);
    final List<WinningTicket> wins = resultsState.winsFor(draw.id);
    final DrawSummaryRecord? summary = resultsState.summaryFor(draw.id);

    if (draw.status == DrawStatus.upcoming) {
      return AppCard(
        child: EmptyState(
          title: l10n.resultsNotEnteredTitle,
          message: l10n.resultsNotEnteredSubtitle,
          icon: Icons.fact_check_outlined,
          actionLabel: l10n.enterResultsTitle,
          onAction: () => EnterResultsSheet.show(
            context: context,
            draw: draw,
            tiers: tiers,
            existingResults: existingResults,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (draw.status == DrawStatus.resultEntered) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: l10n.editResultsTitle,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => EnterResultsSheet.show(
                    context: context,
                    draw: draw,
                    tiers: tiers,
                    existingResults: existingResults,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: l10n.closeDrawAction,
                  isLoading: resultsState.isSubmitting,
                  onPressed: resultsState.isSubmitting
                      ? null
                      : () => _confirmCloseDraw(draw, l10n),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (summary != null) ...<Widget>[
          _buildSummaryCard(summary, l10n, colors, context),
          const SizedBox(height: AppSpacing.md),
        ],
        WinResultsView(
          draw: draw,
          wins: wins,
          isClosed: draw.status == DrawStatus.closed,
          onChangeClaimStatus: (WinningTicket win, WinClaimStatus status) async {
            final bool ok = await ref
                .read(resultsControllerProvider.notifier)
                .updateWinClaimStatus(
                  drawId: draw.id,
                  winId: win.id,
                  status: status,
                  sellerId: win.sellerId,
                );
            if (!context.mounted) {
              return;
            }
            if (ok) {
              AppSnackbar.show(context, message: l10n.claimStatusUpdatedSuccess);
            } else {
              final Object? err =
                  ref.read(resultsControllerProvider).lastError;
              AppSnackbar.show(
                context,
                message: RpcErrorMapper.toLocalizedMessage(err ?? '', l10n),
                isError: true,
              );
            }
          },
          onSharePoster: () => WinnerPosterShare.sharePoster(
            context: context,
            draw: draw,
            wins: wins,
            l10n: l10n,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    DrawSummaryRecord summary,
    AppLocalizations l10n,
    AppColors colors,
    BuildContext context,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(l10n.drawSummaryLabel, style: context.text.h2),
              Text(
                AppFormatters.count(summary.ticketsBought),
                style: context.text.caption.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(l10n.soldByCounterBadge, style: context.text.caption),
              Text(
                AppFormatters.count(summary.ticketsSoldCounter),
                style: context.text.label,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(l10n.statWithSellers, style: context.text.caption),
              Text(
                AppFormatters.count(summary.ticketsSoldSeller),
                style: context.text.label,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(l10n.totalPrizeWonLabel, style: context.text.caption),
              MoneyText(
                paise: summary.totalPrizesWonPaise,
                tone: MoneyTone.prizeGold,
                style: context.text.label,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
