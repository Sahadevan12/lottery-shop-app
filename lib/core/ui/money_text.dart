import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

enum MoneyTone {
  /// Automatically colors positive balance due as `danger` and <= 0 as `success`.
  balanceDue,

  /// Always colors as `gold` (reserved strictly for winning prize amounts, §4.1).
  prizeGold,

  /// Always colors as `success` (paid/settled).
  settled,

  /// Neutral `ink` color.
  neutral,
}

/// Design System MoneyText (§4.3, §4.5).
/// - Formats ₹ in Indian format (`₹1,23,450`) with tabular figures.
/// - Semantic colors: positive due = `danger`, settled = `success`, prize = `gold`.
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.paise,
    this.tone = MoneyTone.neutral,
    this.style,
    this.showSign = false,
  });

  /// Convenience constructor from whole integer rupees.
  const MoneyText.fromRupees({
    super.key,
    required int rupees,
    this.tone = MoneyTone.neutral,
    this.style,
    this.showSign = false,
  }) : paise = rupees * 100;

  final int paise;
  final MoneyTone tone;
  final TextStyle? style;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color resolvedColor;

    switch (tone) {
      case MoneyTone.balanceDue:
        resolvedColor = paise > 0 ? colors.danger : colors.success;
      case MoneyTone.prizeGold:
        resolvedColor = colors.gold;
      case MoneyTone.settled:
        resolvedColor = colors.success;
      case MoneyTone.neutral:
        resolvedColor = colors.ink;
    }

    final TextStyle baseStyle = style ?? context.text.bodyMedium;
    return Text(
      AppFormatters.moneyFromPaise(paise, showSign: showSign),
      style: baseStyle.copyWith(color: resolvedColor),
    );
  }
}
