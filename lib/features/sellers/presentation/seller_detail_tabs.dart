import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../results/domain/result_entities.dart';
import '../../results/presentation/win_results_view.dart';
import '../../stock/domain/stock_entities.dart';
import '../domain/seller_entities.dart';

/// Ledger, Tickets, and Wins tab bodies for [SellerDetailScreen] (§8.4, A.2).
class SellerLedgerTab extends StatelessWidget {
  const SellerLedgerTab({
    super.key,
    required this.entries,
    required this.onReverseEntry,
    required this.onGiveTickets,
  });

  final List<LedgerEntry> entries;
  final ValueChanged<LedgerEntry> onReverseEntry;
  final VoidCallback? onGiveTickets;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (entries.isEmpty) {
      return ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AppCard(
            child: EmptyState(
              title: l10n.ledgerEmptyTitle,
              message: l10n.ledgerEmptyBody,
              actionLabel:
                  onGiveTickets != null ? l10n.giveTicketsShortAction : null,
              icon: Icons.receipt_long_outlined,
              onAction: onGiveTickets,
            ),
          ),
        ],
      );
    }

    final Map<String, LedgerEntry> reversalsByOriginalId =
        <String, LedgerEntry>{
      for (final LedgerEntry e in entries)
        if (e.reversedEntryId != null) e.reversedEntryId!: e,
    };
    final Set<String> pairedReversalIds =
        reversalsByOriginalId.values.map((LedgerEntry e) => e.id).toSet();

    final List<LedgerEntry> displayRoots = entries
        .where((LedgerEntry e) => !pairedReversalIds.contains(e.id))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.xxl,
      ),
      itemCount: displayRoots.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final LedgerEntry entry = displayRoots[index];
        final LedgerEntry? linkedReversal = reversalsByOriginalId[entry.id];
        return _LedgerEntryCard(
          entry: entry,
          linkedReversal: linkedReversal,
          onReverse: entry.canReverse ? () => onReverseEntry(entry) : null,
        );
      },
    );
  }
}

class _LedgerEntryCard extends StatelessWidget {
  const _LedgerEntryCard({
    required this.entry,
    this.linkedReversal,
    this.onReverse,
  });

  final LedgerEntry entry;
  final LedgerEntry? linkedReversal;
  final VoidCallback? onReverse;

  String _typeLabel(LedgerEntryType type, AppLocalizations l10n) {
    switch (type) {
      case LedgerEntryType.issue:
        return l10n.ledgerTypeIssue;
      case LedgerEntryType.returnTickets:
        return l10n.ledgerTypeReturn;
      case LedgerEntryType.payment:
        return l10n.ledgerTypePayment;
      case LedgerEntryType.prizePaidBySeller:
        return l10n.ledgerTypePrizePaid;
      case LedgerEntryType.adjustment:
        return l10n.ledgerTypeAdjustment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final bool isStruck = entry.isReversed;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            _typeLabel(entry.type, l10n),
                            style: context.text.bodyMedium.copyWith(
                              color: isStruck ? colors.inkMuted : colors.ink,
                              decoration: isStruck
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                        if (isStruck) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.warning.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.chipRadius,
                              ),
                            ),
                            child: Text(
                              l10n.reversedChipLabel,
                              style: context.text.caption.copyWith(
                                color: colors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        AppFormatters.shortDate(entry.createdAt.toLocal()),
                        if (entry.note != null && entry.note!.isNotEmpty)
                          entry.note!,
                      ].join(' · '),
                      style:
                          context.text.caption.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    AppFormatters.moneyFromPaise(
                      entry.amountPaise,
                      showSign: true,
                    ),
                    style: context.text.bodyMedium.copyWith(
                      color: isStruck
                          ? colors.inkMuted
                          : (entry.amountPaise > 0
                              ? colors.danger
                              : colors.success),
                      fontWeight: FontWeight.w700,
                      decoration: isStruck
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (onReverse != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReverse,
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          l10n.reverseEntryAction,
                          style: context.text.caption.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (linkedReversal != null) ...<Widget>[
            Divider(color: colors.border, height: AppSpacing.md),
            Row(
              children: <Widget>[
                Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 16,
                  color: colors.inkMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${l10n.reversalOfLabel} · ${AppFormatters.shortDate(linkedReversal!.createdAt.toLocal())}',
                    style:
                        context.text.caption.copyWith(color: colors.inkMuted),
                  ),
                ),
                MoneyText(
                  paise: linkedReversal!.amountPaise,
                  showSign: true,
                  style: context.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SellerTicketsTab extends StatelessWidget {
  const SellerTicketsTab({
    super.key,
    required this.tickets,
    required this.onGiveTickets,
  });

  final List<TicketItem> tickets;
  final VoidCallback? onGiveTickets;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;

    if (tickets.isEmpty) {
      return ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AppCard(
            child: EmptyState(
              title: l10n.sellerTicketsEmptyTitle,
              message: l10n.sellerTicketsEmptyBody,
              actionLabel:
                  onGiveTickets != null ? l10n.giveTicketsShortAction : null,
              icon: Icons.confirmation_number_outlined,
              onAction: onGiveTickets,
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.xxl,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.8,
      ),
      itemCount: tickets.length,
      itemBuilder: (BuildContext context, int index) {
        final TicketItem t = tickets[index];
        final Color dotColor = t.status == TicketStatus.withSeller
            ? colors.warning
            : colors.inkFaint;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            border: Border.all(
              color: colors.border,
              width: AppSpacing.borderWidth,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TicketNumberText(series: t.series, number: t.number),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SellerWinsTab extends StatelessWidget {
  const SellerWinsTab({
    super.key,
    required this.wins,
    required this.onChangeClaimStatus,
  });

  final List<WinningTicket> wins;
  final void Function(WinningTicket win, WinClaimStatus status)
      onChangeClaimStatus;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (wins.isEmpty) {
      return ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AppCard(
            child: EmptyState(
              title: l10n.sellerWinsEmptyTitle,
              message: l10n.sellerWinsEmptySubtitle,
              icon: Icons.emoji_events_outlined,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.xxl,
      ),
      itemCount: wins.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final WinningTicket win = wins[index];
        return WinTicketCard(
          win: win,
          isClosed: false,
          onChangeClaimStatus: (WinClaimStatus s) =>
              onChangeClaimStatus(win, s),
        );
      },
    );
  }
}
