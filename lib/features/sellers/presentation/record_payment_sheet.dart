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
import '../../stock/domain/stock_entities.dart';
import '../../stock/presentation/stock_controller.dart';
import '../domain/ledger_math.dart';
import '../domain/seller_entities.dart';
import 'sellers_controller.dart';

/// Record Payment or Prize Paid by Seller Sheet (§7.4, §8.4, A.2, A.5, B.13).
/// - Validates `0 < amount <= 10,00,000`.
/// - Shows Seller Advance Warning card if payment exceeds current balance due (B.13).
/// - Shows Undo snackbar that calls `reverseLedgerEntry` (A.2).
class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({
    super.key,
    this.initialSeller,
  });

  final SellerProfile? initialSeller;

  static Future<void> show({
    required BuildContext context,
    SellerProfile? initialSeller,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppBottomSheet.show<void>(
      context: context,
      title: l10n.recordPaymentSheetTitle,
      subtitle: initialSeller?.name,
      child: RecordPaymentSheet(initialSeller: initialSeller),
    );
  }

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedSellerId;
  String? _selectedDrawId;
  bool _isPrizePaidMode = false;
  PaymentMethod _method = PaymentMethod.cash;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _selectedSellerId = widget.initialSeller?.id;
    final StockState stockState = ref.read(stockControllerProvider);
    _selectedDrawId = stockState.selectedDraw?.id ??
        (stockState.draws.isNotEmpty ? stockState.draws.first.id : null);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int _enteredAmountPaise() {
    final int rupees = int.tryParse(_amountController.text.trim()) ?? 0;
    return rupees * 100;
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SellersController controller =
        ref.read(sellersControllerProvider.notifier);
    final String? sellerId = _selectedSellerId;
    if (sellerId == null) {
      setState(() => _validationError = l10n.errorNotFound);
      return;
    }

    final int amountPaise = _enteredAmountPaise();
    if (!LedgerMath.isValidPaymentAmountPaise(amountPaise)) {
      setState(() => _validationError = l10n.errorInvalidAmount);
      return;
    }

    String? entryId;
    if (_isPrizePaidMode) {
      final String? drawId = _selectedDrawId;
      if (drawId == null) {
        setState(() => _validationError = l10n.errorNotFound);
        return;
      }
      entryId = await controller.recordPrizePaidBySeller(
        sellerId: sellerId,
        drawId: drawId,
        amountPaise: amountPaise,
        note: _noteController.text.trim(),
      );
    } else {
      entryId = await controller.recordPayment(
        sellerId: sellerId,
        amountPaise: amountPaise,
        method: _method,
        note: _noteController.text.trim(),
      );
    }

    if (!mounted) {
      return;
    }

    if (entryId == null) {
      final String? rawErr = ref.read(sellersControllerProvider).errorMessage;
      setState(() {
        _validationError = RpcErrorMapper.toLocalizedMessage(
          rawErr ?? '',
          l10n,
        );
      });
      return;
    }

    final String createdId = entryId;
    AppSnackbar.show(
      context,
      message: l10n.paymentRecordedSuccess(
        AppFormatters.moneyFromPaise(amountPaise),
      ),
      undoLabel: l10n.undoAction,
      onUndo: () {
        controller.reverseLedgerEntry(
          sellerId: sellerId,
          entryId: createdId,
        );
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final SellersState sellersState = ref.watch(sellersControllerProvider);
    final StockState stockState = ref.watch(stockControllerProvider);

    final SellerSummary? currentSummary = _selectedSellerId == null
        ? null
        : sellersState.summaryFor(_selectedSellerId!);
    final int currentBalancePaise = currentSummary?.balancePaise ?? 0;
    final int amountPaise = _enteredAmountPaise();

    final bool exceedsBalance = !_isPrizePaidMode &&
        _selectedSellerId != null &&
        LedgerMath.willPaymentExceedBalance(
          currentBalancePaise: currentBalancePaise,
          paymentAmountPaise: amountPaise,
        );
    final int advancePaise = LedgerMath.computeAdvancePaise(
      currentBalancePaise: currentBalancePaise,
      paymentAmountPaise: amountPaise,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.initialSeller == null) ...<Widget>[
          Text(l10n.selectSellerLabel, style: context.text.label),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: AppSpacing.minTouchTarget,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final SellerSummary s in sellersState.sellers) ...<Widget>[
                  AppChip(
                    label: s.seller.name,
                    selected: _selectedSellerId == s.seller.id,
                    onTap: () => setState(() {
                      _selectedSellerId = s.seller.id;
                      _validationError = null;
                    }),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: AppChip(
                label: l10n.entryKindPayment,
                selected: !_isPrizePaidMode,
                onTap: () => setState(() {
                  _isPrizePaidMode = false;
                  _validationError = null;
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppChip(
                label: l10n.entryKindPrizePaid,
                selected: _isPrizePaidMode,
                onTap: () => setState(() {
                  _isPrizePaidMode = true;
                  _validationError = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_isPrizePaidMode && stockState.draws.isNotEmpty) ...<Widget>[
          SizedBox(
            height: AppSpacing.minTouchTarget,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final LotteryDraw d in stockState.draws) ...<Widget>[
                  AppChip(
                    label:
                        '${d.lotteryName} (${AppFormatters.shortDate(d.drawDate)})',
                    selected: _selectedDrawId == d.id,
                    onTap: () => setState(() {
                      _selectedDrawId = d.id;
                      _validationError = null;
                    }),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppTextField(
          label: l10n.amountRupeesLabel,
          controller: _amountController,
          hintText: l10n.amountRupeesHint,
          prefixText: '₹',
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => setState(() => _validationError = null),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_isPrizePaidMode) ...<Widget>[
          Text(l10n.paymentMethodLabel, style: context.text.label),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: AppChip(
                  label: l10n.paymentMethodCash,
                  selected: _method == PaymentMethod.cash,
                  onTap: () => setState(() => _method = PaymentMethod.cash),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppChip(
                  label: l10n.paymentMethodUpi,
                  selected: _method == PaymentMethod.upi,
                  onTap: () => setState(() => _method = PaymentMethod.upi),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppChip(
                  label: l10n.paymentMethodOther,
                  selected: _method == PaymentMethod.other,
                  onTap: () => setState(() => _method = PaymentMethod.other),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppTextField(
          label: l10n.noteOptionalLabel,
          controller: _noteController,
          hintText: l10n.noteOptionalHint,
        ),
        if (exceedsBalance) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            backgroundColor: colors.warning.withValues(alpha: 0.12),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.advanceWarningTitle,
                  style: context.text.bodyMedium.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.advanceWarningBody(
                    AppFormatters.moneyFromPaise(advancePaise),
                  ),
                  style: context.text.caption.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
        ],
        if (_validationError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _validationError!,
            style: context.text.caption.copyWith(color: colors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: exceedsBalance ? l10n.confirmAdvanceAction : l10n.saveAction,
          isLoading: sellersState.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
