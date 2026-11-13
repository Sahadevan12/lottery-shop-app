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

/// Range-based Counter Sale Sheet (A.4 & Addition #2).
/// - Uses server-side `preview_tickets` RPC (no 1000-row cap).
/// - On `TICKETS_NOT_AVAILABLE`, shows friendly message, re-runs `preview_tickets`,
///   and keeps the sheet open.
class MarkCounterSoldSheet extends ConsumerStatefulWidget {
  const MarkCounterSoldSheet({
    super.key,
    required this.draw,
    this.initialSeries,
    this.initialStartNumber,
    this.initialEndNumber,
  });

  final LotteryDraw draw;
  final String? initialSeries;
  final String? initialStartNumber;
  final String? initialEndNumber;

  static Future<void> show({
    required BuildContext context,
    required LotteryDraw draw,
    String? initialSeries,
    String? initialStartNumber,
    String? initialEndNumber,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String subtitle =
        '${draw.lotteryName} · ${AppFormatters.shortDate(draw.drawDate)}';
    return AppBottomSheet.show<void>(
      context: context,
      title: l10n.counterSaleSheetTitle,
      subtitle: subtitle,
      child: MarkCounterSoldSheet(
        draw: draw,
        initialSeries: initialSeries,
        initialStartNumber: initialStartNumber,
        initialEndNumber: initialEndNumber,
      ),
    );
  }

  @override
  ConsumerState<MarkCounterSoldSheet> createState() =>
      _MarkCounterSoldSheetState();
}

class _MarkCounterSoldSheetState extends ConsumerState<MarkCounterSoldSheet> {
  late final TextEditingController _seriesController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  bool _markSold = true;
  bool _isPreviewing = false;
  TicketRangePreview _preview = const TicketRangePreview();
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final String defaultSeries =
        (widget.initialSeries ?? widget.draw.lotteryCode ?? 'KR').toUpperCase();
    _seriesController = TextEditingController(text: defaultSeries);
    _startController = TextEditingController(
      text: widget.initialStartNumber ?? '',
    );
    _endController = TextEditingController(
      text: widget.initialEndNumber ?? '',
    );
    _refreshPreview();
  }

  @override
  void dispose() {
    _seriesController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _refreshPreview() async {
    final StockRangeEvaluation eval = StockRangeLogic.evaluateRange(
      series: _seriesController.text,
      startNumber: _startController.text,
      endNumber: _endController.text,
    );
    if (!eval.isValid) {
      if (mounted) {
        setState(() {
          _preview = const TicketRangePreview();
          _isPreviewing = false;
        });
      }
      return;
    }

    setState(() => _isPreviewing = true);
    try {
      final TicketRangePreview res =
          await ref.read(stockRepositoryProvider).previewTickets(
                drawId: widget.draw.id,
                mode: 'RANGE',
                series: eval.normalizedSeries,
                startNumber: eval.paddedStart,
                endNumber: eval.paddedEnd,
                status: _markSold
                    ? TicketStatus.inStock
                    : TicketStatus.soldCounter,
              );
      if (mounted) {
        setState(() {
          _preview = res;
          _isPreviewing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isPreviewing = false);
      }
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StockRangeEvaluation eval = StockRangeLogic.evaluateRange(
      series: _seriesController.text,
      startNumber: _startController.text,
      endNumber: _endController.text,
    );
    if (!eval.isValid) {
      setState(() => _statusMessage = l10n.errorInvalidRange);
      return;
    }

    final int? updatedCount = await ref
        .read(stockControllerProvider.notifier)
        .updateCounterSoldRange(
          drawId: widget.draw.id,
          series: eval.normalizedSeries,
          startNumber: eval.paddedStart,
          endNumber: eval.paddedEnd,
          markSold: _markSold,
        );

    if (!mounted) {
      return;
    }

    if (updatedCount == null) {
      final String? rawErr = ref.read(stockControllerProvider).errorMessage;
      final String friendly = RpcErrorMapper.toLocalizedMessage(
        rawErr ?? '',
        l10n,
      );
      setState(() => _statusMessage = friendly);

      if (RpcErrorMapper.isTicketAvailabilityConflict(rawErr ?? '')) {
        await _refreshPreview();
      }
      return;
    }

    AppSnackbar.show(
      context,
      message: l10n.counterSaleUpdatedSuccess(
        AppFormatters.count(updatedCount),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final StockState stockState = ref.watch(stockControllerProvider);
    final int matchCount = _preview.totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppChip(
                label: l10n.counterSaleModeMark,
                selected: _markSold,
                onTap: () {
                  setState(() {
                    _markSold = true;
                    _statusMessage = null;
                  });
                  _refreshPreview();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppChip(
                label: l10n.counterSaleModeUnmark,
                selected: !_markSold,
                onTap: () {
                  setState(() {
                    _markSold = false;
                    _statusMessage = null;
                  });
                  _refreshPreview();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.seriesFieldLabel,
          controller: _seriesController,
          hintText: l10n.seriesFieldHint,
          useMonoFont: true,
          maxLength: 3,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) {
            setState(() => _statusMessage = null);
            _refreshPreview();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
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
                onChanged: (_) {
                  setState(() => _statusMessage = null);
                  _refreshPreview();
                },
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
                onChanged: (_) {
                  setState(() => _statusMessage = null);
                  _refreshPreview();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          backgroundColor: colors.surfaceAlt,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                l10n.quantityLabel,
                style: context.text.caption.copyWith(color: colors.inkMuted),
              ),
              Text(
                _isPreviewing
                    ? '…'
                    : l10n.ticketsCountLabel(AppFormatters.count(matchCount)),
                style: context.text.h2.copyWith(
                  color: matchCount > 0 ? colors.primary : colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        if (_statusMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _statusMessage!,
            style: context.text.caption.copyWith(color: colors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.confirmCounterSaleAction,
          isLoading: stockState.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
