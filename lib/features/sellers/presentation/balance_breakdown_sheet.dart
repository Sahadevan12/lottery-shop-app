import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/seller_entities.dart';

/// Seller Balance Breakdown Sheet (§8.4, A.6).
/// Groups `ISSUE`, `RETURN`, and `PRIZE_PAID_BY_SELLER` per draw (`draw_id`),
/// shows `PAYMENT` and `ADJUSTMENT` totals below, and reconciles to the exact net balance due.
class BalanceBreakdownSheet extends StatelessWidget {
  const BalanceBreakdownSheet({
    super.key,
    required this.sellerName,
    required this.breakdown,
  });

  final String sellerName;
  final SellerBalanceBreakdown breakdown;

  static Future<void> show({
    required BuildContext context,
    required String sellerName,
    required SellerBalanceBreakdown breakdown,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppBottomSheet.show<void>(
      context: context,
      title: l10n.balanceBreakdownTitle,
      subtitle: sellerName,
      child: BalanceBreakdownSheet(
        sellerName: sellerName,
        breakdown: breakdown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (breakdown.drawRows.isNotEmpty) ...<Widget>[
          SectionHeader(title: l10n.breakdownPerDrawSection),
          const SizedBox(height: AppSpacing.sm),
          for (final DrawBreakdownRow row in breakdown.drawRows) ...<Widget>[
            AppCard(
              backgroundColor: colors.surfaceAlt,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    row.drawDate == null
                        ? row.drawLabel
                        : '${row.drawLabel} · ${AppFormatters.shortDate(row.drawDate!)}',
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _BreakdownMetricRow(
                    label: l10n.breakdownIssuedRow(
                      AppFormatters.count(row.issuedTicketCount),
                    ),
                    paise: row.issuedPaise,
                    showSign: true,
                  ),
                  if (row.returnedPaise != 0 || row.returnedTicketCount > 0)
                    _BreakdownMetricRow(
                      label: l10n.breakdownReturnedRow(
                        AppFormatters.count(row.returnedTicketCount),
                      ),
                      paise: row.returnedPaise,
                      showSign: true,
                    ),
                  if (row.prizePaidPaise != 0)
                    _BreakdownMetricRow(
                      label: l10n.breakdownPrizePaidRow,
                      paise: row.prizePaidPaise,
                      showSign: true,
                    ),
                  if (row.drawAdjustmentsPaise != 0)
                    _BreakdownMetricRow(
                      label: l10n.breakdownAdjustmentsTotal,
                      paise: row.drawAdjustmentsPaise,
                      showSign: true,
                    ),
                  Divider(color: colors.border, height: AppSpacing.md),
                  _BreakdownMetricRow(
                    label: l10n.breakdownDrawSubtotal,
                    paise: row.netDrawPaise,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
        SectionHeader(title: l10n.breakdownPaymentsSection),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          backgroundColor: colors.surfaceAlt,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _BreakdownMetricRow(
                label: l10n.breakdownPaymentsTotal,
                paise: breakdown.paymentsTotalPaise,
                showSign: true,
              ),
              if (breakdown.generalAdjustmentsPaise != 0) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                _BreakdownMetricRow(
                  label: l10n.breakdownAdjustmentsTotal,
                  paise: breakdown.generalAdjustmentsPaise,
                  showSign: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                l10n.breakdownGrandTotal,
                style: context.text.bodyMedium,
              ),
              MoneyText(
                paise: breakdown.grandTotalPaise,
                tone: MoneyTone.balanceDue,
                style: context.text.h2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownMetricRow extends StatelessWidget {
  const _BreakdownMetricRow({
    required this.label,
    required this.paise,
    this.showSign = false,
    this.isBold = false,
  });

  final String label;
  final int paise;
  final bool showSign;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: isBold
                  ? context.text.bodyMedium
                  : context.text.caption.copyWith(color: colors.inkMuted),
            ),
          ),
          MoneyText(
            paise: paise,
            showSign: showSign,
            style: isBold
                ? context.text.bodyMedium
                : context.text.caption.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}
