import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../stock/domain/stock_entities.dart';
import '../domain/result_entities.dart';

class WinResultsView extends StatelessWidget {
  const WinResultsView({
    super.key,
    required this.draw,
    required this.wins,
    required this.isClosed,
    required this.onChangeClaimStatus,
    required this.onSharePoster,
  });

  final LotteryDraw draw;
  final List<WinningTicket> wins;
  final bool isClosed;
  final void Function(WinningTicket win, WinClaimStatus status)
      onChangeClaimStatus;
  final VoidCallback onSharePoster;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;

    if (wins.isEmpty) {
      return AppCard(
        child: EmptyState(
          title: l10n.noWinnersFoundTitle,
          message: l10n.noWinnersFoundSubtitle,
          icon: Icons.emoji_events_outlined,
        ),
      );
    }

    final int totalPaise = wins.fold<int>(
      0,
      (int sum, WinningTicket w) => sum + w.prizeAmountPaise,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          backgroundColor: colors.goldSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.winnersFoundHeadline(
                        AppFormatters.count(wins.length),
                      ),
                      style: context.text.h2.copyWith(color: colors.ink),
                    ),
                  ),
                  Icon(Icons.emoji_events_rounded, color: colors.gold),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.totalPrizeWonLabel,
                style: context.text.caption.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              MoneyText(
                paise: totalPaise,
                tone: MoneyTone.prizeGold,
                style: context.text.display,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.shareWinnerPosterAction,
                variant: AppButtonVariant.secondary,
                onPressed: onSharePoster,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final WinningTicket win in wins) ...<Widget>[
          WinTicketCard(
            win: win,
            isClosed: isClosed,
            onChangeClaimStatus: (WinClaimStatus s) =>
                onChangeClaimStatus(win, s),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class WinTicketCard extends StatelessWidget {
  const WinTicketCard({
    super.key,
    required this.win,
    required this.isClosed,
    required this.onChangeClaimStatus,
  });

  final WinningTicket win;
  final bool isClosed;
  final ValueChanged<WinClaimStatus> onChangeClaimStatus;

  String _soldByLabel(AppLocalizations l10n) {
    switch (win.soldBy) {
      case WinSoldBy.counter:
        return l10n.soldByCounterBadge;
      case WinSoldBy.seller:
        return l10n.soldBySellerBadge(win.sellerName ?? '');
      case WinSoldBy.unsold:
        return l10n.soldByUnsoldBadge;
    }
  }

  Color _soldByColor(AppColors colors) {
    switch (win.soldBy) {
      case WinSoldBy.counter:
        return colors.primary;
      case WinSoldBy.seller:
        return colors.gold;
      case WinSoldBy.unsold:
        return colors.inkMuted;
    }
  }

  String _claimLabel(WinClaimStatus status, AppLocalizations l10n) {
    switch (status) {
      case WinClaimStatus.unclaimed:
        return l10n.claimStatusUnclaimed;
      case WinClaimStatus.paidToCustomer:
        return l10n.claimStatusPaidToCustomer;
      case WinClaimStatus.claimedFromOffice:
        return l10n.claimStatusClaimedFromOffice;
      case WinClaimStatus.unsoldWin:
        return l10n.claimStatusUnsoldWin;
    }
  }

  Color _claimColor(WinClaimStatus status, AppColors colors) {
    switch (status) {
      case WinClaimStatus.unclaimed:
        return colors.warning;
      case WinClaimStatus.paidToCustomer:
      case WinClaimStatus.claimedFromOffice:
        return colors.success;
      case WinClaimStatus.unsoldWin:
        return colors.inkMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              TicketNumberText(
                series: win.ticketSeries,
                number: win.ticketNumber,
              ),
              MoneyText(
                paise: win.prizeAmountPaise,
                tone: MoneyTone.prizeGold,
                style: context.text.h2,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                win.tierLabel,
                style: context.text.caption.copyWith(color: colors.inkMuted),
              ),
              _StatusPill(
                label: _soldByLabel(l10n),
                color: _soldByColor(colors),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _StatusPill(
                label: _claimLabel(win.claimStatus, l10n),
                color: _claimColor(win.claimStatus, colors),
              ),
              if (!isClosed)
                PopupMenuButton<WinClaimStatus>(
                  onSelected: onChangeClaimStatus,
                  itemBuilder: (BuildContext context) =>
                      WinClaimStatus.values.map((WinClaimStatus status) {
                    return PopupMenuItem<WinClaimStatus>(
                      value: status,
                      child: Text(_claimLabel(status, l10n)),
                    );
                  }).toList(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _claimLabel(win.claimStatus, l10n),
                          style: context.text.label.copyWith(
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        label,
        style: context.text.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
