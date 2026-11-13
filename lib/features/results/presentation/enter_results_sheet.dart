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
import '../domain/prize_matcher.dart';
import '../domain/result_entities.dart';
import 'results_controller.dart';

class EnterResultsSheet extends ConsumerStatefulWidget {
  const EnterResultsSheet({
    super.key,
    required this.draw,
    required this.tiers,
    required this.existingResults,
  });

  final LotteryDraw draw;
  final List<DrawPrizeTier> tiers;
  final List<DrawResultEntry> existingResults;

  static Future<void> show({
    required BuildContext context,
    required LotteryDraw draw,
    required List<DrawPrizeTier> tiers,
    required List<DrawResultEntry> existingResults,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppBottomSheet.show<void>(
      context: context,
      title: existingResults.isEmpty
          ? l10n.enterResultsTitle
          : l10n.editResultsTitle,
      subtitle: '${draw.lotteryName} (${draw.drawNumber})',
      child: EnterResultsSheet(
        draw: draw,
        tiers: tiers,
        existingResults: existingResults,
      ),
    );
  }

  @override
  ConsumerState<EnterResultsSheet> createState() => _EnterResultsSheetState();
}

class _EntryControllers {
  _EntryControllers({String series = '', String number = ''})
      : seriesController = TextEditingController(text: series),
        numberController = TextEditingController(text: number);

  final TextEditingController seriesController;
  final TextEditingController numberController;

  void dispose() {
    seriesController.dispose();
    numberController.dispose();
  }
}

class _EnterResultsSheetState extends ConsumerState<EnterResultsSheet> {
  late final List<DrawPrizeTier> _editableTiers;
  final Map<String, List<_EntryControllers>> _controllersByTier =
      <String, List<_EntryControllers>>{};
  final Map<String, Map<int, ResultEntryValidationError>> _fieldErrors =
      <String, Map<int, ResultEntryValidationError>>{};
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _editableTiers = widget.tiers
        .where((DrawPrizeTier t) => t.matchType != PrizeMatchType.consolation)
        .toList()
      ..sort(
        (DrawPrizeTier a, DrawPrizeTier b) => a.tierOrder.compareTo(b.tierOrder),
      );

    final String defaultSeries =
        (widget.draw.lotteryCode ?? 'KR').toUpperCase();
    for (final DrawPrizeTier tier in _editableTiers) {
      final List<DrawResultEntry> existing = widget.existingResults
          .where((DrawResultEntry r) => r.tierId == tier.id)
          .toList();
      if (existing.isNotEmpty) {
        _controllersByTier[tier.id] = existing
            .map(
              (DrawResultEntry r) => _EntryControllers(
                series: r.winningSeries ?? '',
                number: r.winningNumber,
              ),
            )
            .toList();
      } else {
        _controllersByTier[tier.id] = <_EntryControllers>[
          _EntryControllers(
            series: tier.matchType == PrizeMatchType.full ? defaultSeries : '',
          ),
        ];
      }
    }
  }

  @override
  void dispose() {
    for (final List<_EntryControllers> list in _controllersByTier.values) {
      for (final _EntryControllers c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  bool _validateAll() {
    final Map<String, Map<int, ResultEntryValidationError>> nextErrors =
        <String, Map<int, ResultEntryValidationError>>{};
    bool hasAnyEntry = false;
    bool valid = true;

    for (final DrawPrizeTier tier in _editableTiers) {
      final List<_EntryControllers> rows =
          _controllersByTier[tier.id] ?? const <_EntryControllers>[];
      final Map<int, ResultEntryValidationError> tierErrors =
          <int, ResultEntryValidationError>{};
      final List<({String? series, String number})> nonEmpty =
          <({String? series, String number})>[];
      final List<int> nonEmptyIdx = <int>[];

      for (int i = 0; i < rows.length; i++) {
        final String s = rows[i].seriesController.text.trim().toUpperCase();
        final String n = rows[i].numberController.text.trim();
        if (n.isEmpty) {
          continue;
        }
        hasAnyEntry = true;
        final ResultEntryValidationError? err = ResultEntryValidator.validate(
          matchType: tier.matchType,
          series: s,
          number: n,
        );
        if (err != null) {
          tierErrors[i] = err;
          valid = false;
        } else {
          nonEmpty.add((series: s, number: n));
          nonEmptyIdx.add(i);
        }
      }

      final Set<int> dupIndexes = ResultEntryValidator.findDuplicateIndexes(
        matchType: tier.matchType,
        entries: nonEmpty,
      );
      for (final int dupPos in dupIndexes) {
        tierErrors[nonEmptyIdx[dupPos]] = ResultEntryValidationError.duplicate;
        valid = false;
      }

      if (tierErrors.isNotEmpty) {
        nextErrors[tier.id] = tierErrors;
      }
    }

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(nextErrors);
      _submitError = hasAnyEntry
          ? null
          : AppLocalizations.of(context).errorInvalidResultEntry;
    });
    return valid && hasAnyEntry;
  }

  List<ResultEntryInput> _buildEntries() {
    final List<ResultEntryInput> list = <ResultEntryInput>[];
    for (final DrawPrizeTier tier in _editableTiers) {
      final List<_EntryControllers> rows =
          _controllersByTier[tier.id] ?? const <_EntryControllers>[];
      for (final _EntryControllers row in rows) {
        final String n = row.numberController.text.trim();
        if (n.isEmpty) {
          continue;
        }
        list.add(
          ResultEntryInput(
            tierId: tier.id,
            winningSeries: tier.matchType == PrizeMatchType.full
                ? row.seriesController.text.trim().toUpperCase()
                : null,
            winningNumber: n,
          ),
        );
      }
    }
    return list;
  }

  Future<void> _submit({bool force = false}) async {
    if (!force && !_validateAll()) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<ResultEntryInput> entries = _buildEntries();
    final int? winCount = await ref
        .read(resultsControllerProvider.notifier)
        .saveDrawResultsAndCheck(
          drawId: widget.draw.id,
          entries: entries,
          force: force,
        );

    if (!mounted) {
      return;
    }

    if (winCount == null) {
      final Object? err = ref.read(resultsControllerProvider).lastError;
      if (err != null && !force && RpcErrorMapper.isClaimedWinAffected(err)) {
        final String detail = RpcErrorMapper.extractDetail(err);
        final bool confirmed = await ConfirmDialog.show(
          context: context,
          title: l10n.claimedWinAffectedTitle,
          message: l10n.claimedWinAffectedBody(detail),
          cancelLabel: l10n.cancelAction,
          confirmLabel: l10n.forceUpdateResultsAction,
          isDanger: true,
        );
        if (confirmed && mounted) {
          await _submit(force: true);
        }
        return;
      }
      setState(() {
        _submitError = RpcErrorMapper.toLocalizedMessage(err ?? '', l10n);
      });
      return;
    }

    AppSnackbar.show(
      context,
      message: l10n.resultsSavedSuccess(AppFormatters.count(winCount)),
    );
    Navigator.of(context).pop();
  }

  String _errorText(
    ResultEntryValidationError? err,
    AppLocalizations l10n,
  ) {
    if (err == null) {
      return '';
    }
    switch (err) {
      case ResultEntryValidationError.invalidFull:
        return l10n.invalidFullTicketError;
      case ResultEntryValidationError.invalidLast4:
        return l10n.invalidLast4Error;
      case ResultEntryValidationError.invalidLast3:
        return l10n.invalidLast3Error;
      case ResultEntryValidationError.duplicate:
        return l10n.duplicateEntryError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final ResultsState resultsState = ref.watch(resultsControllerProvider);
    final bool hasConsolation = widget.tiers.any(
      (DrawPrizeTier t) => t.matchType == PrizeMatchType.consolation,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.resultsDrawTimeNote(widget.draw.drawTime),
          style: context.text.caption.copyWith(color: colors.inkMuted),
        ),
        if (hasConsolation) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.autoConsolationNote,
            style: context.text.caption.copyWith(color: colors.primary),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final DrawPrizeTier tier in _editableTiers) ...<Widget>[
          _buildTierSection(tier, l10n, colors),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_submitError != null) ...<Widget>[
          Text(
            _submitError!,
            style: context.text.caption.copyWith(color: colors.danger),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          label: l10n.saveAndCheckResultsAction,
          isLoading: resultsState.isSubmitting,
          onPressed: resultsState.isSubmitting ? null : () => _submit(),
        ),
      ],
    );
  }

  Widget _buildTierSection(
    DrawPrizeTier tier,
    AppLocalizations l10n,
    AppColors colors,
  ) {
    final List<_EntryControllers> rows =
        _controllersByTier[tier.id] ?? <_EntryControllers>[];
    final Map<int, ResultEntryValidationError> errors =
        _fieldErrors[tier.id] ?? const <int, ResultEntryValidationError>{};
    final int maxDigits = switch (tier.matchType) {
      PrizeMatchType.full || PrizeMatchType.consolation => 6,
      PrizeMatchType.last4 => 4,
      PrizeMatchType.last3 => 3,
    };
    final String hint = switch (tier.matchType) {
      PrizeMatchType.full || PrizeMatchType.consolation => l10n.fullTicketHint,
      PrizeMatchType.last4 => l10n.last4DigitsHint,
      PrizeMatchType.last3 => l10n.last3DigitsHint,
    };

    return AppCard(
      backgroundColor: colors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(tier.label, style: context.text.h2),
              MoneyText(
                paise: tier.amountPaise,
                tone: MoneyTone.prizeGold,
                style: context.text.label,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (tier.matchType == PrizeMatchType.full) ...<Widget>[
                  SizedBox(
                    width: 84,
                    child: AppTextField(
                      label: i == 0 ? l10n.seriesFieldLabel : '',
                      controller: rows[i].seriesController,
                      hintText: l10n.seriesFieldHint,
                      useMonoFont: true,
                      maxLength: 3,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() => _submitError = null),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: AppTextField(
                    label: i == 0 ? l10n.startNumberFieldLabel : '',
                    controller: rows[i].numberController,
                    hintText: hint,
                    useMonoFont: true,
                    maxLength: maxDigits,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    errorText: errors[i] != null
                        ? _errorText(errors[i], l10n)
                        : null,
                    onChanged: (_) => setState(() => _submitError = null),
                  ),
                ),
                if (rows.length > 1)
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.inkMuted),
                    onPressed: () {
                      setState(() {
                        final _EntryControllers removed = rows.removeAt(i);
                        removed.dispose();
                      });
                    },
                  ),
              ],
            ),
            if (i < rows.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  rows.add(
                    _EntryControllers(
                      series: tier.matchType == PrizeMatchType.full
                          ? (widget.draw.lotteryCode ?? 'KR').toUpperCase()
                          : '',
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.addWinningNumberAction),
            ),
          ),
        ],
      ),
    );
  }
}
