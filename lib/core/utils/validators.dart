import 'app_constants.dart';

/// Domain Validators for Auth, Tickets, and Stock Ranges (§5, §6.2, §7.1).
abstract final class AppValidators {
  static final RegExp _seriesRegex = RegExp(r'^[A-Z]{1,3}$');
  static final RegExp _ticketNumberRegex = RegExp(r'^\d{6}$');
  static final RegExp _phoneRegex = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _pinRegex = RegExp(r'^\d{6}$');

  /// Strips spaces and non-digit characters from a phone input.
  static String normalizePhone(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '');

  /// Validates a 10-digit Indian mobile number.
  static bool isValidPhone(String raw) {
    final String digits = normalizePhone(raw);
    return _phoneRegex.hasMatch(digits);
  }

  /// Validates a 6-digit numeric PIN.
  static bool isValidPin(String raw) => _pinRegex.hasMatch(raw.trim());

  /// Maps a 10-digit phone number to the internal Supabase email (§6.2):
  /// `<10-digit-phone>@luckyledger.app`.
  static String phoneToInternalEmail(String rawPhone) {
    final String digits = normalizePhone(rawPhone);
    if (!isValidPhone(digits)) {
      throw ArgumentError.value(
        rawPhone,
        'rawPhone',
        'Must be a valid 10-digit Indian mobile number',
      );
    }
    return '$digits@${AppConstants.authEmailDomain}';
  }

  /// Validates a lottery ticket series (`^[A-Z]{1,3}$`, §5).
  static bool isValidSeries(String series) =>
      _seriesRegex.hasMatch(series.trim().toUpperCase());

  /// Validates a 6-digit lottery ticket number (`^\d{6}$`, §5).
  static bool isValidTicketNumber(String number) =>
      _ticketNumberRegex.hasMatch(number.trim());

  /// Validates a stock batch range (`start..end` inclusive, max 5,000, §7.1).
  /// Returns the quantity if valid, or `null` if invalid.
  static int? computeRangeQuantity(String startNumber, String endNumber) {
    if (!isValidTicketNumber(startNumber) || !isValidTicketNumber(endNumber)) {
      return null;
    }
    final int start = int.parse(startNumber.trim());
    final int end = int.parse(endNumber.trim());
    if (end < start) {
      return null;
    }
    final int quantity = end - start + 1;
    if (quantity > AppConstants.maxBatchTickets) {
      return null;
    }
    return quantity;
  }
}
