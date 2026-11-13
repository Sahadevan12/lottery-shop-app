import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Design System TicketNumberText (§4.3, §4.5).
/// - Renders in `JetBrains Mono`, letter-spaced (`KR 482913`).
/// - Series in `inkMuted`, number in `ink`.
/// - Optional highlight of matched digits in `gold` (e.g. last 4 digits glow for 4-digit prizes,
///   or all 6 digits + series for full matches).
class TicketNumberText extends StatelessWidget {
  const TicketNumberText({
    super.key,
    required this.series,
    required this.number,
    this.matchedSuffixDigits = 0,
    this.highlightFullTicket = false,
    this.large = false,
  });

  final String series;
  final String number;

  /// Number of trailing digits to highlight in `gold` (e.g., 4 for `LAST_4`, 3 for `LAST_3`).
  final int matchedSuffixDigits;

  /// Highlights the entire ticket number in `gold` (e.g. `FULL` or `CONSOLATION` match).
  final bool highlightFullTicket;

  final bool large;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextStyle baseMono =
        large ? context.text.ticketMonoLarge : context.text.ticketMono;

    final String cleanSeries = series.trim().toUpperCase();
    final String cleanNumber = number.trim().padLeft(6, '0');

    final int clampedSuffix =
        matchedSuffixDigits.clamp(0, cleanNumber.length);
    final int splitIndex = cleanNumber.length - clampedSuffix;
    final String prefixDigits =
        highlightFullTicket ? '' : cleanNumber.substring(0, splitIndex);
    final String highlightedDigits = highlightFullTicket
        ? cleanNumber
        : cleanNumber.substring(splitIndex);

    return RichText(
      text: TextSpan(
        style: baseMono,
        children: <InlineSpan>[
          TextSpan(
            text: '$cleanSeries ',
            style: baseMono.copyWith(
              color: highlightFullTicket ? colors.gold : colors.inkMuted,
            ),
          ),
          if (prefixDigits.isNotEmpty)
            TextSpan(
              text: prefixDigits,
              style: baseMono.copyWith(color: colors.ink),
            ),
          if (highlightedDigits.isNotEmpty)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: colors.goldSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  border: Border.all(
                    color: colors.gold.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  highlightedDigits,
                  style: baseMono.copyWith(
                    color: colors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
