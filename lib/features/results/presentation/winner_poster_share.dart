import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../stock/domain/stock_entities.dart';
import '../domain/result_entities.dart';

enum WinnerPosterTemplate {
  classic,
  emerald,
  festive,
}

/// Interactive bottom sheet to customize & share a 1080×1350 winner poster PNG.
class WinnerPosterSheet extends StatefulWidget {
  const WinnerPosterSheet({
    super.key,
    required this.draw,
    required this.wins,
  });

  final LotteryDraw draw;
  final List<WinningTicket> wins;

  static Future<void> show({
    required BuildContext context,
    required LotteryDraw draw,
    required List<WinningTicket> wins,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => WinnerPosterSheet(draw: draw, wins: wins),
    );
  }

  @override
  State<WinnerPosterSheet> createState() => _WinnerPosterSheetState();
}

class _WinnerPosterSheetState extends State<WinnerPosterSheet> {
  WinnerPosterTemplate _template = WinnerPosterTemplate.classic;
  late String _langCode;
  bool _maskNumbers = true; // Rule: ticket masking ON by default
  bool _isSharing = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final String code = Localizations.localeOf(context).languageCode;
      _langCode = (code == 'ml' || code == 'ta') ? code : 'en';
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLocalizations posterL10n = lookupAppLocalizations(Locale(_langCode));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.posterTemplateLabel, style: context.text.label),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(l10n.posterTemplateClassic),
                    selected: _template == WinnerPosterTemplate.classic,
                    onSelected: (_) => setState(
                      () => _template = WinnerPosterTemplate.classic,
                    ),
                  ),
                  ChoiceChip(
                    label: Text(l10n.posterTemplateEmerald),
                    selected: _template == WinnerPosterTemplate.emerald,
                    onSelected: (_) => setState(
                      () => _template = WinnerPosterTemplate.emerald,
                    ),
                  ),
                  ChoiceChip(
                    label: Text(l10n.posterTemplateFestive),
                    selected: _template == WinnerPosterTemplate.festive,
                    onSelected: (_) => setState(
                      () => _template = WinnerPosterTemplate.festive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.posterLanguageLabel, style: context.text.label),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('English'),
                    selected: _langCode == 'en',
                    onSelected: (_) => setState(() => _langCode = 'en'),
                  ),
                  ChoiceChip(
                    label: const Text('മലയാളം'),
                    selected: _langCode == 'ml',
                    onSelected: (_) => setState(() => _langCode = 'ml'),
                  ),
                  ChoiceChip(
                    label: const Text('தமிழ்'),
                    selected: _langCode == 'ta',
                    onSelected: (_) => setState(() => _langCode = 'ta'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.posterMaskNumbersLabel),
                value: _maskNumbers,
                onChanged: (bool val) => setState(() => _maskNumbers = val),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: SizedBox(
                  height: 260,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: WinnerPosterCanvas(
                      draw: widget.draw,
                      wins: widget.wins.take(10).toList(),
                      l10n: posterL10n,
                      template: _template,
                      maskNumbers: _maskNumbers,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.posterShareNowAction,
                isLoading: _isSharing,
                leadingIcon: Icons.share_outlined,
                onPressed: _isSharing
                    ? null
                    : () async {
                        setState(() => _isSharing = true);
                        try {
                          await WinnerPosterShare.sharePoster(
                            context: context,
                            draw: widget.draw,
                            wins: widget.wins,
                            l10n: posterL10n,
                            template: _template,
                            maskNumbers: _maskNumbers,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSharing = false);
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class WinnerPosterShare {
  /// Masks all characters after the first two digits (e.g. `482910` -> `48****`).
  static String maskTicketNumber(String number) {
    final String trimmed = number.trim();
    if (trimmed.length <= 2) {
      return '*' * trimmed.length;
    }
    return '${trimmed.substring(0, 2)}${'*' * (trimmed.length - 2)}';
  }

  /// Captures an exact 1080×1350 PNG (540×675 logical px at pixelRatio 2.0).
  static Future<Uint8List> capturePosterPng({
    required BuildContext context,
    required LotteryDraw draw,
    required List<WinningTicket> wins,
    required AppLocalizations l10n,
    WinnerPosterTemplate template = WinnerPosterTemplate.classic,
    bool maskNumbers = true,
  }) async {
    final ScreenshotController screenshotController = ScreenshotController();
    final ThemeData theme = Theme.of(context);

    final Widget poster = Theme(
      data: theme,
      child: Material(
        color: Colors.transparent,
        child: WinnerPosterCanvas(
          draw: draw,
          wins: wins.take(10).toList(),
          l10n: l10n,
          template: template,
          maskNumbers: maskNumbers,
        ),
      ),
    );

    return screenshotController.captureFromWidget(
      poster,
      context: context,
      pixelRatio: 2.0,
      delay: Duration.zero,
    );
  }

  static Future<void> sharePoster({
    required BuildContext context,
    required LotteryDraw draw,
    required List<WinningTicket> wins,
    required AppLocalizations l10n,
    WinnerPosterTemplate template = WinnerPosterTemplate.classic,
    bool maskNumbers = true,
  }) async {
    final Uint8List imageBytes = await capturePosterPng(
      context: context,
      draw: draw,
      wins: wins,
      l10n: l10n,
      template: template,
      maskNumbers: maskNumbers,
    );

    final Directory dir = await getTemporaryDirectory();
    final File file = File(
      '${dir.path}/winner_poster_${draw.drawNumber}.png',
    );
    await file.writeAsBytes(imageBytes, flush: true);

    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      text: '${draw.lotteryName} (${draw.drawNumber}) - ${l10n.winnerPosterTitle}',
    );
  }
}

/// 540×675 canvas (renders at 1080×1350 PNG with pixelRatio 2.0).
class WinnerPosterCanvas extends StatelessWidget {
  const WinnerPosterCanvas({
    super.key,
    required this.draw,
    required this.wins,
    required this.l10n,
    this.template = WinnerPosterTemplate.classic,
    this.maskNumbers = true,
  });

  final LotteryDraw draw;
  final List<WinningTicket> wins;
  final AppLocalizations l10n;
  final WinnerPosterTemplate template;
  final bool maskNumbers;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int totalPaise = wins.fold<int>(
      0,
      (int sum, WinningTicket w) => sum + w.prizeAmountPaise,
    );

    final (Color bgColor, Color borderColor, Color accentColor) =
        switch (template) {
      WinnerPosterTemplate.classic => (
          colors.surface,
          colors.gold,
          colors.gold,
        ),
      WinnerPosterTemplate.emerald => (
          const Color(0xFFF1FAF5),
          colors.primary,
          colors.primary,
        ),
      WinnerPosterTemplate.festive => (
          const Color(0xFFFFF8EC),
          colors.danger,
          colors.gold,
        ),
    };

    return Container(
      width: 540,
      height: 675,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.winnerPosterTitle,
            style: context.text.h1.copyWith(color: accentColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${draw.lotteryName} • ${draw.drawNumber} • ${AppFormatters.shortDate(draw.drawDate)}',
            style: context.text.caption.copyWith(color: colors.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.goldSoft,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  l10n.totalPrizeWonLabel,
                  style: context.text.label.copyWith(color: colors.ink),
                ),
                MoneyText(
                  paise: totalPaise,
                  tone: MoneyTone.prizeGold,
                  style: context.text.h2,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: wins.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colors.border),
              itemBuilder: (BuildContext ctx, int idx) {
                final WinningTicket win = wins[idx];
                final String displayedNumber = maskNumbers
                    ? WinnerPosterShare.maskTicketNumber(win.ticketNumber)
                    : win.ticketNumber;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      TicketNumberText(
                        series: win.ticketSeries,
                        number: displayedNumber,
                      ),
                      Text(
                        win.tierLabel,
                        style: context.text.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      MoneyText(
                        paise: win.prizeAmountPaise,
                        tone: MoneyTone.prizeGold,
                        style: context.text.label,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.winnerPosterVerifyNote,
            style: context.text.caption.copyWith(color: colors.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.winnerPosterFooter,
            style: context.text.caption.copyWith(color: colors.primary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
