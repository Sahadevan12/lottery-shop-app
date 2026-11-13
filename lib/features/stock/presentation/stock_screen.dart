import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_entities.dart';
import '../domain/stock_range_logic.dart';
import 'add_stock_sheet.dart';
import 'batch_detail_screen.dart';
import 'create_draw_sheet.dart';
import 'stock_controller.dart';

/// Stock Tab — Tab 2 (§8.3).
/// - Draw selector chip row (Today, Tomorrow, upcoming draws, Bumper, + New draw).
/// - If no draw exists for today, shows "Create today's draw" card prefilled with today's lottery.
/// - Summary bar for selected draw.
/// - Batch list with status breakdown mini bar, search, delete action with ConfirmDialog, and tap -> ticket grid.
/// - Bottom primary action: "Add stock".
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteBatch(
    BuildContext context,
    StockBatch batch,
    AppLocalizations l10n,
  ) async {
    final String rangeStr =
        '${batch.series} ${batch.startNumber}–${batch.endNumber}';
    final bool confirmed = await ConfirmDialog.show(
      context: context,
      title: l10n.deleteBatchTitle,
      message: l10n.deleteBatchBody(
        rangeStr,
        AppFormatters.count(batch.quantity),
      ),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final bool ok = await ref
        .read(stockControllerProvider.notifier)
        .deleteStockBatch(drawId: batch.drawId, batchId: batch.id);

    if (!context.mounted) {
      return;
    }
    if (ok) {
      AppSnackbar.show(context, message: l10n.batchDeletedSuccess);
    } else {
      final String? err = ref.read(stockControllerProvider).errorMessage;
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
    final StockController controller =
        ref.read(stockControllerProvider.notifier);

    final DateTime today = DateTime.now();
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final LotteryDraw? todayDraw = stockState.drawForDate(today);
    final LotteryDraw? selectedDraw = stockState.selectedDraw;
    final LotteryItem? todayDefaultLottery =
        StockRangeLogic.findDefaultLotteryForDate(stockState.lotteries, today);

    final String query = _searchController.text.trim().toUpperCase();
    final List<StockBatch> batches =
        stockState.selectedDrawBatches.where((StockBatch b) {
      if (query.isEmpty) {
        return true;
      }
      final String label = '${b.series} ${b.startNumber} ${b.endNumber}';
      return label.toUpperCase().contains(query);
    }).toList();

    final DrawStockSummary summary = stockState.selectedDrawSummary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStock),
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
        onRefresh: controller.loadInitialData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            // 1. Draw Selector Chip Row (§8.3)
            SizedBox(
              height: AppSpacing.minTouchTarget,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  AppChip(
                    label: l10n.drawSelectorToday,
                    badgeText: todayDraw?.drawNumber ?? todayDraw?.lotteryCode,
                    selected: selectedDraw != null &&
                        todayDraw != null &&
                        selectedDraw.id == todayDraw.id,
                    onTap: () {
                      if (todayDraw != null) {
                        controller.selectDraw(todayDraw.id);
                      } else {
                        controller.selectDraw(null);
                      }
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  for (final LotteryDraw d in stockState.draws)
                    if (todayDraw == null || d.id != todayDraw.id) ...<Widget>[
                      AppChip(
                        label: d.isBumper
                            ? '${l10n.drawSelectorBumper}: ${d.lotteryName}'
                            : (d.isSameDay(tomorrow)
                                ? '${l10n.drawSelectorTomorrow} · ${d.lotteryName}'
                                : '${d.lotteryName} (${AppFormatters.shortDate(d.drawDate)})'),
                        badgeText: d.drawNumber,
                        selected: selectedDraw?.id == d.id,
                        onTap: () => controller.selectDraw(d.id),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  AppChip(
                    label: l10n.newDrawChip,
                    selected: false,
                    onTap: () => CreateDrawSheet.show(
                      context: context,
                      initialDate: todayDraw == null ? today : tomorrow,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (stockState.isLoading)
              SkeletonLoader.list(itemCount: 3, itemHeight: 96)
            else if (selectedDraw == null)
              // Requirement #7: No auto-creating today's draw; show "Create today's draw" card
              AppCard(
                child: EmptyState(
                  title: l10n.createTodayDrawTitle,
                  message: l10n.createTodayDrawBody(
                    todayDefaultLottery?.name ?? l10n.lotteryFieldLabel,
                  ),
                  actionLabel: l10n.createTodayDrawTitle,
                  icon: Icons.event_available_outlined,
                  onAction: () => CreateDrawSheet.show(
                    context: context,
                    initialDate: today,
                    initialLottery: todayDefaultLottery,
                  ),
                ),
              )
            else ...<Widget>[
              // 2. Summary Bar for Selected Draw (§7.1, §8.3)
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatTile(
                      label: l10n.statTotalTickets,
                      numericValue: summary.total,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      label: l10n.statInStock,
                      numericValue: summary.inStock,
                      valueColor: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _MiniStatMetric(
                      label: l10n.statWithSellers,
                      value: summary.withSellers,
                      color: colors.warning,
                    ),
                    _MiniStatMetric(
                      label: l10n.statSold,
                      value: summary.sold,
                      color: colors.success,
                    ),
                    _MiniStatMetric(
                      label: l10n.statReturned,
                      value: summary.returnedUnsold,
                      color: colors.inkMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. Search Bar
              if (stockState.selectedDrawBatches.isNotEmpty) ...<Widget>[
                AppTextField(
                  label: selectedDraw.lotteryName,
                  controller: _searchController,
                  hintText: l10n.searchHint,
                  useMonoFont: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // 4. Batches List or Empty State
              if (batches.isEmpty)
                AppCard(
                  child: EmptyState(
                    title: l10n.stockEmptyTitle,
                    message: l10n.stockEmptyBody,
                    actionLabel: selectedDraw.status == DrawStatus.upcoming
                        ? l10n.stockEmptyCta
                        : null,
                    onAction: selectedDraw.status == DrawStatus.upcoming
                        ? () => AddStockSheet.show(
                              context: context,
                              draw: selectedDraw,
                            )
                        : null,
                  ),
                )
              else
                ...batches.map((StockBatch batch) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _BatchCard(
                      batch: batch,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BatchDetailScreen(batch: batch),
                          ),
                        );
                      },
                      onDelete: () => _confirmDeleteBatch(context, batch, l10n),
                    ),
                  );
                }),

              // 30-day retention note for closed draws (§6.6)
              if (selectedDraw.status == DrawStatus.closed) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.ticketRetentionNote,
                  textAlign: TextAlign.center,
                  style: context.text.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar:
          (selectedDraw != null && selectedDraw.status == DrawStatus.upcoming)
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AppButton(
                          label: l10n.stockEmptyCta,
                          leadingIcon: Icons.add_rounded,
                          onPressed: () => AddStockSheet.show(
                            context: context,
                            draw: selectedDraw,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
    );
  }
}

class _MiniStatMetric extends StatelessWidget {
  const _MiniStatMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style:
              context.text.caption.copyWith(color: context.colors.inkMuted),
        ),
        Text(
          AppFormatters.count(value),
          style: context.text.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.onTap,
    required this.onDelete,
  });

  final StockBatch batch;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final int total = batch.quantity > 0 ? batch.quantity : 1;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${batch.series} ${batch.startNumber} – ${batch.endNumber} · ${l10n.ticketsCountLabel(AppFormatters.count(batch.quantity))}',
                  style: context.text.ticketMono.copyWith(color: colors.ink),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTarget,
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: batch.canDelete ? colors.danger : colors.inkFaint,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            child: SizedBox(
              height: 6,
              child: Row(
                children: <Widget>[
                  if (batch.inStockCount > 0)
                    Expanded(
                      flex: (batch.inStockCount * 100 ~/ total).clamp(1, 100),
                      child: Container(color: colors.primary),
                    ),
                  if (batch.withSellerCount > 0)
                    Expanded(
                      flex:
                          (batch.withSellerCount * 100 ~/ total).clamp(1, 100),
                      child: Container(color: colors.warning),
                    ),
                  if (batch.soldCount > 0)
                    Expanded(
                      flex: (batch.soldCount * 100 ~/ total).clamp(1, 100),
                      child: Container(color: colors.success),
                    ),
                  if (batch.returnedCount > 0)
                    Expanded(
                      flex: (batch.returnedCount * 100 ~/ total).clamp(1, 100),
                      child: Container(color: colors.inkFaint),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
