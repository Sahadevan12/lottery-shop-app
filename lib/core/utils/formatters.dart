import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Money, Date, Time, and Ticket Formatters (§4.3, §5, §6.1).
/// Never use floating-point math for money; use int paise or `Decimal`.
abstract final class AppFormatters {
  static final NumberFormat _inrWholeFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrDecimalFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _indianNumberFormat = NumberFormat.decimalPattern(
    'en_IN',
  );

  /// Formats integer rupees in Indian format: `₹1,23,450`.
  static String moneyFromRupees(int rupees, {bool showSign = false}) {
    final int absValue = rupees.abs();
    final String formatted = _inrWholeFormat.format(absValue);
    if (rupees < 0) {
      return '−$formatted';
    }
    if (showSign && rupees > 0) {
      return '+$formatted';
    }
    return formatted;
  }

  /// Formats integer paise (100 paise = ₹1) in Indian format.
  /// Omits `.00` when paise is an exact rupee amount (§4.3: `₹1,23,450`).
  static String moneyFromPaise(int paise, {bool showSign = false}) {
    final int absPaise = paise.abs();
    final bool hasSubRupee = absPaise % 100 != 0;
    final Decimal rupees =
        (Decimal.fromInt(absPaise) / Decimal.fromInt(100)).toDecimal();
    final String formatted = hasSubRupee
        ? _inrDecimalFormat.format(double.parse(rupees.toString()))
        : _inrWholeFormat.format(absPaise ~/ 100);
    if (paise < 0) {
      return '−$formatted';
    }
    if (showSign && paise > 0) {
      return '+$formatted';
    }
    return formatted;
  }

  /// Formats a `Decimal` rupee amount in Indian format (`₹1,23,450`).
  static String moneyFromDecimal(Decimal amount, {bool showSign = false}) {
    final int paise = (amount * Decimal.fromInt(100)).toBigInt().toInt();
    return moneyFromPaise(paise, showSign: showSign);
  }

  /// Parses a Postgres `numeric(12,2)` value (String, int, or num) into paise.
  static int parseNumericToPaise(Object? value) {
    if (value == null) {
      return 0;
    }
    final Decimal decimal = Decimal.parse(value.toString());
    return (decimal * Decimal.fromInt(100)).toBigInt().toInt();
  }

  /// Formats a count in Indian numbering format: `1,250`.
  static String count(int value) => _indianNumberFormat.format(value);

  /// Formats a date in `12 Nov, Thu` style (§4.3) in Asia/Kolkata (UTC+05:30).
  static String shortDate(DateTime dateTime, {String? locale}) {
    final DateTime ist = toIst(dateTime);
    return DateFormat('d MMM, EEE', locale).format(ist);
  }

  /// Formats draw time in `3:00 PM` style (§4.3).
  static String time12h(DateTime dateTime, {String? locale}) {
    final DateTime ist = toIst(dateTime);
    return DateFormat('h:mm a', locale).format(ist);
  }

  /// Converts a timestamp to Asia/Kolkata (UTC+5:30) (§6.1).
  static DateTime toIst(DateTime dateTime) {
    if (!dateTime.isUtc) {
      return dateTime;
    }
    return dateTime.add(const Duration(hours: 5, minutes: 30));
  }

  /// Zero-pads a ticket number to 6 digits (`482913` or `000123`) (§7.1).
  static String padTicketNumber(int number) =>
      number.toString().padLeft(6, '0');

  /// Formats series + number for display: `KR 482913` (§5).
  static String formatTicket(String series, String number) =>
      '${series.trim().toUpperCase()} ${number.trim().padLeft(6, '0')}';
}
