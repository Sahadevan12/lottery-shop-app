import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_entities.dart';
import 'stock_controller.dart';

/// Lotteries & Prize Templates Editor Screen (§5, §8.7).
/// Allows viewing, adding, and editing weekly/bumper lotteries and prize structure templates.
class LotteriesTemplatesScreen extends ConsumerStatefulWidget {
  const LotteriesTemplatesScreen({super.key});

  @override
  ConsumerState<LotteriesTemplatesScreen> createState() =>
      _LotteriesTemplatesScreenState();
}

class _LotteriesTemplatesScreenState
    extends ConsumerState<LotteriesTemplatesScreen> {
  int _selectedTab = 0;

  void _openEditLotterySheet(
    BuildContext context,
    AppLocalizations l10n, {
    LotteryItem? existing,
  }) {
    final TextEditingController nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final TextEditingController codeCtrl =
        TextEditingController(text: existing?.code ?? '');
    final TextEditingController priceCtrl = TextEditingController(
      text: ((existing?.defaultTicketPricePaise ?? 4000) ~/ 100).toString(),
    );
    bool isBumper = existing?.isBumper ?? false;
    final int weekday = existing?.defaultWeekday ?? 1;

    AppBottomSheet.show<void>(
      context: context,
      title: existing == null ? l10n.addLotteryAction : l10n.editLotteryTitle,
      child: StatefulBuilder(
        builder: (BuildContext sheetContext, StateSetter setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTextField(
                label: l10n.lotteryNameLabel,
                controller: nameCtrl,
                hintText: 'Win-Win',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      label: l10n.lotteryCodeLabel,
                      controller: codeCtrl,
                      hintText: 'W',
                      useMonoFont: true,
                      maxLength: 3,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: l10n.ticketPriceFieldLabel,
                      controller: priceCtrl,
                      prefixText: '₹',
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(l10n.isBumperLabel, style: sheetContext.text.body),
                  Switch.adaptive(
                    value: isBumper,
                    activeTrackColor: sheetContext.colors.primary,
                    onChanged: (bool val) =>
                        setSheetState(() => isBumper = val),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.saveAction,
                onPressed: () async {
                  final String name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  final int priceRupees =
                      int.tryParse(priceCtrl.text.trim()) ?? 40;
                  final bool ok = await ref
                      .read(stockControllerProvider.notifier)
                      .saveLottery(
                        id: existing?.id,
                        name: name,
                        code: codeCtrl.text.trim(),
                        defaultWeekday: isBumper ? null : weekday,
                        defaultTicketPricePaise: priceRupees * 100,
                        isBumper: isBumper,
                      );
                  if (ok && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final StockState stockState = ref.watch(stockControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lotteriesTemplatesTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              AppChip(
                label: l10n.lotteriesTab,
                selected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                label: l10n.prizeTemplatesTab,
                selected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_selectedTab == 0) ...<Widget>[
            ...stockState.lotteries.map((LotteryItem item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => _openEditLotterySheet(
                    context,
                    l10n,
                    existing: item,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.name, style: context.text.bodyMedium),
                            const SizedBox(height: 2),
                            Text(
                              item.code ?? '',
                              style: context.text.caption.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MoneyText(
                        paise: item.defaultTicketPricePaise,
                        style: context.text.bodyMedium,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.edit_outlined, size: 18, color: colors.inkMuted),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.addLotteryAction,
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.add_rounded,
              onPressed: () => _openEditLotterySheet(context, l10n),
            ),
          ] else ...<Widget>[
            ...stockState.templates.map((PrizeTemplate tpl) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(tpl.name, style: context.text.h2),
                      const SizedBox(height: AppSpacing.sm),
                      ...tpl.tiers.map((PrizeTemplateTier tier) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '${tier.label} (${tier.matchType.dbValue})',
                                  style: context.text.body,
                                ),
                              ),
                              MoneyText(
                                paise: tier.amountPaise,
                                tone: MoneyTone.prizeGold,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
