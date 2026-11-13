import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/report_entities.dart';
import 'reports_controller.dart';
import 'reports_pdf_share.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final ReportsState state = ref.watch(reportsControllerProvider);
    final ReportsController ctrl = ref.read(reportsControllerProvider.notifier);
    final ReportsSummaryData? summary = state.summary;
    final String shopName =
        ref.watch(authControllerProvider).shop?.name ?? l10n.appName;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.exportPdfReportAction,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: summary == null
                ? null
                : () => ReportsPdfShare.sharePdf(
                      context: context,
                      summary: summary,
                      l10n: l10n,
                      locale: Localizations.localeOf(context),
                      shopName: shopName,
                    ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            _PeriodSelectorBar(
              preset: state.preset,
              fromDate: state.fromDate,
              toDate: state.toDate,
              onSelectPreset: ctrl.selectPreset,
              onPickCustomRange: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  initialDateRange: DateTimeRange(
                    start: state.fromDate,
                    end: state.toDate,
                  ),
                );
                if (picked != null) {
                  await ctrl.selectCustomRange(picked.start, picked.end);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.isLoading) const LinearProgressIndicator(),
            if (summary == null) ...<Widget>[
              if (!state.isLoading)
                AppCard(
                  backgroundColor: colors.danger.withValues(alpha: 0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        state.error != null
                            ? RpcErrorMapper.toLocalizedMessage(
                                state.error!,
                                l10n,
                              )
                            : l10n.errorGeneric,
                        style: context.text.body.copyWith(color: colors.danger),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: l10n.retryAction,
                        variant: AppButtonVariant.secondary,
                        onPressed: ctrl.refresh,
                      ),
                    ],
                  ),
                ),
            ] else ...<Widget>[
              if (state.error != null) ...<Widget>[
                AppCard(
                  backgroundColor: colors.danger.withValues(alpha: 0.1),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          RpcErrorMapper.toLocalizedMessage(
                            state.error!,
                            l10n,
                          ),
                          style: context.text.body.copyWith(
                            color: colors.danger,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: ctrl.refresh,
                        child: Text(l10n.retryAction),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.pnlTapToExplainHint,
                    style: context.text.caption.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PnlFigureRow(
                    label: l10n.pnlSalesLabel,
                    amount: summary.totalSales,
                    onTap: () => _showFormulaSheet(
                      context: context,
                      title: l10n.pnlSalesLabel,
                      amount: summary.totalSales,
                      formula: l10n.pnlFormulaSales(
                        AppFormatters.count(summary.totalTicketsSold),
                        summary.draws.isNotEmpty
                            ? AppFormatters.moneyFromRupees(
                                summary.draws.first.ticketPrice.round(),
                              )
                            : '-',
                        AppFormatters.count(summary.totalTicketsSoldCounter),
                        AppFormatters.count(summary.totalTicketsSoldSeller),
                      ),
                    ),
                  ),
                  _PnlFigureRow(
                    label: l10n.pnlStockCostLabel,
                    amount: summary.totalStockCost,
                    onTap: () => _showFormulaSheet(
                      context: context,
                      title: l10n.pnlStockCostLabel,
                      amount: summary.totalStockCost,
                      formula: l10n.pnlFormulaStockCost(
                        AppFormatters.count(summary.totalTicketsBought),
                      ),
                    ),
                  ),
                  _PnlFigureRow(
                    label: l10n.pnlGrossMarginLabel,
                    amount: summary.totalGrossMargin,
                    onTap: () => _showFormulaSheet(
                      context: context,
                      title: l10n.pnlGrossMarginLabel,
                      amount: summary.totalGrossMargin,
                      formula: l10n.pnlFormulaGrossMargin,
                    ),
                  ),
                  _PnlFigureRow(
                    label: l10n.pnlUnsoldGainLabel,
                    amount: summary.totalUnsoldPrizeGain,
                    valueColor: colors.success,
                    onTap: () => _showFormulaSheet(
                      context: context,
                      title: l10n.pnlUnsoldGainLabel,
                      amount: summary.totalUnsoldPrizeGain,
                      formula: l10n.pnlFormulaUnsoldGain,
                    ),
                  ),
                  const Divider(height: AppSpacing.lg),
                  _PnlFigureRow(
                    label: l10n.pnlNetProfitLabel,
                    amount: summary.totalNetProfit,
                    isBold: true,
                    valueColor: summary.totalNetProfit >= 0
                        ? colors.success
                        : colors.danger,
                    onTap: () => _showFormulaSheet(
                      context: context,
                      title: l10n.pnlNetProfitLabel,
                      amount: summary.totalNetProfit,
                      formula: l10n.pnlFormulaNetProfit,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppCard(
                    onTap: () => _showFormulaSheet(
                      context: context,
                      title: l10n.pnlToRecoverOfficeLabel,
                      amount: summary.totalToRecoverFromOffice,
                      formula: l10n.pnlFormulaRecoverOffice,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.pnlToRecoverOfficeLabel,
                          style: context.text.caption.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          AppFormatters.moneyFromRupees(
                            summary.totalToRecoverFromOffice.round(),
                          ),
                          style: context.text.h2.copyWith(color: colors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppCard(
                    onTap: () => _showFormulaSheet(
                      context: context,
                      title: l10n.pnlToCollectSellersLabel,
                      amount: summary.toCollectFromSellers,
                      formula: l10n.pnlFormulaCollectSellers,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.pnlToCollectSellersLabel,
                          style: context.text.caption.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          AppFormatters.moneyFromRupees(
                            summary.toCollectFromSellers.round(),
                          ),
                          style: context.text.h2.copyWith(
                            color: summary.toCollectFromSellers > 0
                                ? colors.danger
                                : colors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.pnlDrawBreakdownTitle),
            const SizedBox(height: AppSpacing.sm),
            if (summary.draws.isEmpty)
              AppCard(
                child: EmptyState(
                  title: l10n.reportsEmptyTitle,
                  message: l10n.reportsEmptySubtitle,
                  icon: Icons.bar_chart_outlined,
                ),
              )
            else
              for (final DrawPnlRow draw in summary.draws) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${draw.lotteryName} (${draw.drawNumber})',
                                style: context.text.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              AppFormatters.moneyFromRupees(
                                draw.netProfit.round(),
                              ),
                              style: context.text.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: draw.netProfit >= 0
                                    ? colors.success
                                    : colors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${AppFormatters.shortDate(draw.drawDate)} · ${draw.ticketsSoldTotal}/${draw.ticketsBought} · ${draw.status}',
                          style: context.text.caption.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static void _showFormulaSheet({
    required BuildContext context,
    required String title,
    required double amount,
    required String formula,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: context.text.h2),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppFormatters.moneyFromRupees(amount.round()),
                style: context.text.h1,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(formula, style: context.text.body),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSelectorBar extends StatelessWidget {
  const _PeriodSelectorBar({
    required this.preset,
    required this.fromDate,
    required this.toDate,
    required this.onSelectPreset,
    required this.onPickCustomRange,
  });

  final ReportPeriodPreset preset;
  final DateTime fromDate;
  final DateTime toDate;
  final ValueChanged<ReportPeriodPreset> onSelectPreset;
  final VoidCallback onPickCustomRange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<(ReportPeriodPreset, String)> options =
        <(ReportPeriodPreset, String)>[
      (ReportPeriodPreset.today, l10n.reportsPeriodToday),
      (ReportPeriodPreset.week, l10n.reportsPeriodWeek),
      (ReportPeriodPreset.month, l10n.reportsPeriodMonth),
      (ReportPeriodPreset.thirtyDays, l10n.reportsPeriod30Days),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final (ReportPeriodPreset p, String label) in options) ...<Widget>[
            ChoiceChip(
              label: Text(label),
              selected: preset == p,
              onSelected: (_) => onSelectPreset(p),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          ActionChip(
            avatar: const Icon(Icons.date_range_outlined, size: 18),
            label: Text(
              '${AppFormatters.shortDate(fromDate)} - ${AppFormatters.shortDate(toDate)}',
            ),
            onPressed: onPickCustomRange,
          ),
        ],
      ),
    );
  }
}

class _PnlFigureRow extends StatelessWidget {
  const _PnlFigureRow({
    required this.label,
    required this.amount,
    required this.onTap,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final double amount;
  final VoidCallback onTap;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: (isBold ? context.text.bodyMedium : context.text.body)
                    .copyWith(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              AppFormatters.moneyFromRupees(amount.round()),
              style: (isBold ? context.text.bodyMedium : context.text.body)
                  .copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.info_outline,
              size: 16,
              color: context.colors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
