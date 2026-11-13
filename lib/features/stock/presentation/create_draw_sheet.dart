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

/// Create Draw Bottom Sheet (§8.3, §6.5).
/// Prefills the lottery matching `initialDate.weekday` and its default ticket price.
class CreateDrawSheet extends ConsumerStatefulWidget {
  const CreateDrawSheet({
    super.key,
    required this.initialDate,
    this.initialLottery,
  });

  final DateTime initialDate;
  final LotteryItem? initialLottery;

  static Future<LotteryDraw?> show({
    required BuildContext context,
    required DateTime initialDate,
    LotteryItem? initialLottery,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppBottomSheet.show<LotteryDraw>(
      context: context,
      title: l10n.createDrawTitle,
      subtitle: AppFormatters.shortDate(initialDate),
      child: CreateDrawSheet(
        initialDate: initialDate,
        initialLottery: initialLottery,
      ),
    );
  }

  @override
  ConsumerState<CreateDrawSheet> createState() => _CreateDrawSheetState();
}

class _CreateDrawSheetState extends ConsumerState<CreateDrawSheet> {
  LotteryItem? _selectedLottery;
  PrizeTemplate? _selectedTemplate;
  late DateTime _drawDate;
  final TextEditingController _drawNumberController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _drawDate = widget.initialDate;
    final StockState stockState = ref.read(stockControllerProvider);
    _selectedLottery = widget.initialLottery ??
        StockRangeLogic.findDefaultLotteryForDate(
          stockState.lotteries,
          _drawDate,
        );
    _selectedTemplate =
        stockState.templates.isNotEmpty ? stockState.templates.first : null;
    _applyLotteryDefaults(_selectedLottery);
  }

  void _applyLotteryDefaults(LotteryItem? lottery) {
    if (lottery == null) {
      return;
    }
    final int priceRupees = lottery.defaultTicketPricePaise ~/ 100;
    _priceController.text = priceRupees.toString();
    if (lottery.code != null && lottery.code!.isNotEmpty) {
      _drawNumberController.text = '${lottery.code}-101';
    }
  }

  @override
  void dispose() {
    _drawNumberController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LotteryItem? lottery = _selectedLottery;
    if (lottery == null) {
      return;
    }
    final int priceRupees = int.tryParse(_priceController.text.trim()) ?? 40;
    final int pricePaise = priceRupees * 100;

    final LotteryDraw? created =
        await ref.read(stockControllerProvider.notifier).createDraw(
              lotteryId: lottery.id,
              drawDate: _drawDate,
              drawNumber: _drawNumberController.text.trim(),
              ticketPricePaise: pricePaise,
              templateId: _selectedTemplate?.id,
            );

    if (!mounted) {
      return;
    }
    if (created != null) {
      Navigator.of(context).pop(created);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.lotteryFieldLabel,
          style: context.text.label.copyWith(color: colors.ink),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: stockState.lotteries.map((LotteryItem item) {
            final bool selected = item.id == _selectedLottery?.id;
            return AppChip(
              label: item.name,
              badgeText: item.code,
              selected: selected,
              onTap: () {
                setState(() {
                  _selectedLottery = item;
                  _applyLotteryDefaults(item);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.drawNumberFieldLabel,
          controller: _drawNumberController,
          hintText: 'W-845',
          useMonoFont: true,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.ticketPriceFieldLabel,
          controller: _priceController,
          prefixText: '₹',
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        if (stockState.templates.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.prizeTemplateFieldLabel,
            style: context.text.label.copyWith(color: colors.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: stockState.templates.map((PrizeTemplate tpl) {
              return AppChip(
                label: tpl.name,
                selected: tpl.id == _selectedTemplate?.id,
                onTap: () => setState(() => _selectedTemplate = tpl),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.createDrawTitle,
          isLoading: stockState.isSubmitting,
          onPressed: _selectedLottery == null ? null : _submit,
        ),
      ],
    );
  }
}
