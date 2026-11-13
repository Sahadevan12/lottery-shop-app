import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'stock_controller.dart';

/// Add Stock Bottom Sheet (§8.3, §7.1).
/// - Prefills selected draw & last used cost per ticket.
/// - Auto-calculates quantity and total cost live as the user types.
/// - Validates range (max 5,000, end >= start) and checks overlap inline.
/// - Option "Add another range" keeps the sheet open with series prefilled.
class AddStockSheet extends ConsumerStatefulWidget {
  const AddStockSheet({
    super.key,
    required this.draw,
  });

  final LotteryDraw draw;

  static Future<void> show({
    required BuildContext context,
    required LotteryDraw draw,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String subtitle =
        '${draw.lotteryName} · ${AppFormatters.shortDate(draw.drawDate)}';
    return AppBottomSheet.show<void>(
      context: context,
      title: l10n.addStockTitle,
      subtitle: subtitle,
      child: AddStockSheet(draw: draw),
    );
  }

  @override
  ConsumerState<AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends ConsumerState<AddStockSheet> {
  late final TextEditingController _seriesController;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  late final TextEditingController _costController;

  bool _addAnotherRange = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final StockState stockState = ref.read(stockControllerProvider);
    final String defaultSeries =
        (widget.draw.lotteryCode ?? 'KR').toUpperCase();
    _seriesController = TextEditingController(text: defaultSeries);
    final int lastCostRupees = stockState.lastCostPerTicketPaise ~/ 100;
    _costController = TextEditingController(text: lastCostRupees.toString());
  }

  @override
  void dispose() {
    _seriesController.dispose();
    _startController.dispose();
    _endController.dispose();
    _costController.dispose();
    super.dispose();
  }

  StockRangeEvaluation _currentEvaluation() {
    final int costRupees = int.tryParse(_costController.text.trim()) ?? 0;
    return StockRangeLogic.evaluateRange(
      series: _seriesController.text,
      startNumber: _startController.text,
      endNumber: _endController.text,
      costPerTicketPaise: costRupees * 100,
    );
  }

  void _onFieldChanged(String _) {
    setState(() {
      _validationError = null;
    });
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StockRangeEvaluation eval = _currentEvaluation();
    if (!eval.isValid) {
      setState(() => _validationError = l10n.errorInvalidRange);
      return;
    }

    final List<StockBatch> existingBatches = ref
            .read(stockControllerProvider)
            .batchesByDraw[widget.draw.id] ??
        const <StockBatch>[];

    final String? overlap = StockRangeLogic.findOverlappingRange(
      series: eval.normalizedSeries,
      startNumber: eval.paddedStart,
      endNumber: eval.paddedEnd,
      existingBatches: existingBatches,
    );
    if (overlap != null) {
      setState(
        () => _validationError = l10n.errorStockOverlapDetail(overlap),
      );
      return;
    }

    final int? costRupees = int.tryParse(_costController.text.trim());
    final int? costPaise = costRupees == null ? null : costRupees * 100;

    final bool ok = await ref
        .read(stockControllerProvider.notifier)
        .addStockBatch(
          drawId: widget.draw.id,
          series: eval.normalizedSeries,
          startNumber: eval.paddedStart,
          endNumber: eval.paddedEnd,
          costPerTicketPaise: costPaise,
        );

    if (!mounted) {
      return;
    }

    if (!ok) {
      final String? rawErr = ref.read(stockControllerProvider).errorMessage;
      setState(() {
        _validationError = RpcErrorMapper.toLocalizedMessage(
          rawErr ?? '',
          l10n,
        );
      });
      return;
    }

    final String rangeStr =
        '${eval.normalizedSeries} ${eval.paddedStart}–${eval.paddedEnd}';
    AppSnackbar.show(
      context,
      message: l10n.batchAddedSuccess(
        AppFormatters.count(eval.quantity),
        rangeStr,
      ),
    );

    if (_addAnotherRange) {
      setState(() {
        _startController.clear();
        _endController.clear();
        _validationError = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final StockState stockState = ref.watch(stockControllerProvider);
    final StockRangeEvaluation eval = _currentEvaluation();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 2,
              child: AppTextField(
                label: l10n.seriesFieldLabel,
                controller: _seriesController,
                hintText: l10n.seriesFieldHint,
                useMonoFont: true,
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                onChanged: _onFieldChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 3,
              child: AppTextField(
                label: l10n.costPerTicketFieldLabel,
                controller: _costController,
                hintText: l10n.costPerTicketFieldHint,
                prefixText: '₹',
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: _onFieldChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AppTextField(
                label: l10n.startNumberFieldLabel,
                controller: _startController,
                hintText: l10n.startNumberFieldHint,
                useMonoFont: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: _onFieldChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: l10n.endNumberFieldLabel,
                controller: _endController,
                hintText: l10n.endNumberFieldHint,
                useMonoFont: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: _onFieldChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Live auto-calculated Quantity & Total Cost preview card (§4.7 #4, §8.3)
        AppCard(
          backgroundColor: colors.surfaceAlt,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.quantityLabel,
                    style:
                        context.text.caption.copyWith(color: colors.inkMuted),
                  ),
                  Text(
                    l10n.ticketsCountLabel(
                      AppFormatters.count(eval.isValid ? eval.quantity : 0),
                    ),
                    style: context.text.h2,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    l10n.totalCostLabel,
                    style:
                        context.text.caption.copyWith(color: colors.inkMuted),
                  ),
                  MoneyText(
                    paise: eval.isValid ? eval.totalCostPaise : 0,
                    style: context.text.h2,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_validationError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _validationError!,
            style: context.text.caption.copyWith(color: colors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.md),

        // "Add another range" option (§8.3)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _addAnotherRange = !_addAnotherRange),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Row(
              children: <Widget>[
                Checkbox.adaptive(
                  value: _addAnotherRange,
                  activeColor: colors.primary,
                  onChanged: (bool? v) =>
                      setState(() => _addAnotherRange = v ?? false),
                ),
                Expanded(
                  child: Text(
                    l10n.addAnotherRangeLabel,
                    style: context.text.body,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        AppButton(
          label: l10n.saveAction,
          isLoading: stockState.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
