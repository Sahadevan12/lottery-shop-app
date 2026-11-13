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

abstract final class WinnerPosterShare {
  static Future<void> sharePoster({
    required BuildContext context,
    required LotteryDraw draw,
    required List<WinningTicket> wins,
    required AppLocalizations l10n,
  }) async {
    final ScreenshotController screenshotController = ScreenshotController();
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.colors;

    final Widget poster = Theme(
      data: theme,
      child: Material(
        color: colors.bg,
        child: _WinnerPosterWidget(
          draw: draw,
          wins: wins.take(12).toList(),
          l10n: l10n,
        ),
      ),
    );

    final Uint8List imageBytes = await screenshotController.captureFromWidget(
      poster,
      context: context,
      pixelRatio: 2.5,
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

class _WinnerPosterWidget extends StatelessWidget {
  const _WinnerPosterWidget({
    required this.draw,
    required this.wins,
    required this.l10n,
  });

  final LotteryDraw draw;
  final List<WinningTicket> wins;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int totalPaise = wins.fold<int>(
      0,
      (int sum, WinningTicket w) => sum + w.prizeAmountPaise,
    );

    return Container(
      width: 380,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.gold, width: 2),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.winnerPosterTitle,
            style: context.text.h1.copyWith(color: colors.gold),
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
          for (final WinningTicket win in wins) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  TicketNumberText(
                    series: win.ticketSeries,
                    number: win.ticketNumber,
                  ),
                  Text(
                    win.tierLabel,
                    style: context.text.caption.copyWith(color: colors.inkMuted),
                  ),
                  MoneyText(
                    paise: win.prizeAmountPaise,
                    tone: MoneyTone.prizeGold,
                    style: context.text.label,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
          ],
          const SizedBox(height: AppSpacing.md),
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
