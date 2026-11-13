import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Maps Postgres RPC exception codes (`STOCK_OVERLAP`, `BATCH_IN_USE`, `DRAW_NOT_OPEN`,
/// `DRAW_EXISTS`, `NOT_FOUND`, `INVALID_RANGE`, `UNAUTHORIZED`, `TICKETS_NOT_AVAILABLE`,
/// `TICKETS_NOT_WITH_SELLER`, `INVALID_AMOUNT`, `NOT_REVERSIBLE`, `ALREADY_REVERSED`,
/// `LEDGER_IMMUTABLE`, `PRICE_LOCKED`, `SELLER_INACTIVE`, §6.1) to localized messages.
abstract final class RpcErrorMapper {
  static String extractCode(Object error) {
    if (error is PostgrestException) {
      return error.message.toUpperCase();
    }
    return error.toString().toUpperCase();
  }

  /// Returns `true` when an RPC failed because tickets changed state concurrently
  /// (`TICKETS_NOT_AVAILABLE` or `TICKETS_NOT_WITH_SELLER`).
  static bool isTicketAvailabilityConflict(Object error) {
    final String code = extractCode(error);
    return code.contains('TICKETS_NOT_AVAILABLE') ||
        code.contains('TICKETS_NOT_WITH_SELLER');
  }

  /// Returns `true` when `check_draw` / `save_draw_results_and_check` raised
  /// `CLAIMED_WIN_AFFECTED` and requires explicit user confirmation (`p_force`).
  static bool isClaimedWinAffected(Object error) {
    return extractCode(error).contains('CLAIMED_WIN_AFFECTED');
  }

  /// Extracts the `DETAIL:` string from a [PostgrestException] or error message.
  static String extractDetail(Object error) {
    if (error is PostgrestException) {
      return (error.details?.toString() ?? '').trim();
    }
    final RegExp detailMatch =
        RegExp(r'DETAIL:\s*(.+)', caseSensitive: false);
    final Match? match = detailMatch.firstMatch(error.toString());
    return match?.group(1)?.trim() ?? '';
  }

  static String toLocalizedMessage(Object error, AppLocalizations l10n) {
    String code = '';
    String detail = '';

    if (error is PostgrestException) {
      code = error.message.toUpperCase();
      detail = (error.details?.toString() ?? '').trim();
    } else {
      code = error.toString().toUpperCase();
      final RegExp detailMatch =
          RegExp(r'DETAIL:\s*(.+)', caseSensitive: false);
      final Match? match = detailMatch.firstMatch(error.toString());
      if (match != null) {
        detail = match.group(1)?.trim() ?? '';
      }
    }

    if (code.contains('STOCK_OVERLAP')) {
      if (detail.isNotEmpty) {
        return l10n.errorStockOverlapDetail(detail);
      }
      return l10n.errorStockOverlap;
    }
    if (code.contains('BATCH_IN_USE')) {
      return l10n.errorBatchInUse;
    }
    if (code.contains('TICKETS_NOT_AVAILABLE')) {
      return l10n.errorTicketsNotAvailable;
    }
    if (code.contains('TICKETS_NOT_WITH_SELLER')) {
      return l10n.errorTicketsNotWithSeller;
    }
    if (code.contains('INVALID_AMOUNT')) {
      return l10n.errorInvalidAmount;
    }
    if (code.contains('NOT_REVERSIBLE')) {
      return l10n.errorNotReversible;
    }
    if (code.contains('ALREADY_REVERSED')) {
      return l10n.errorAlreadyReversed;
    }
    if (code.contains('LEDGER_IMMUTABLE')) {
      return l10n.errorLedgerImmutable;
    }
    if (code.contains('PRICE_LOCKED')) {
      return l10n.errorPriceLocked;
    }
    if (code.contains('SELLER_INACTIVE')) {
      return l10n.errorSellerInactive;
    }
    if (code.contains('DRAW_BEFORE_TIME')) {
      return l10n.errorDrawBeforeTime;
    }
    if (code.contains('DRAW_CLOSED')) {
      return l10n.errorDrawClosed;
    }
    if (code.contains('INVALID_RESULT_ENTRY')) {
      return l10n.errorInvalidResultEntry;
    }
    if (code.contains('DUPLICATE_RESULT_ENTRY')) {
      return l10n.errorDuplicateResultEntry;
    }
    if (code.contains('CLAIMED_WIN_AFFECTED')) {
      return l10n.errorClaimedWinAffected;
    }
    if (code.contains('INVALID_CLAIM_STATUS')) {
      return l10n.errorInvalidClaimStatus;
    }
    if (code.contains('DRAW_NOT_OPEN')) {
      return l10n.errorDrawNotOpen;
    }
    if (code.contains('DRAW_EXISTS')) {
      return l10n.errorDrawExists;
    }
    if (code.contains('NOT_FOUND')) {
      return l10n.errorNotFound;
    }
    if (code.contains('INVALID_RANGE')) {
      return l10n.errorInvalidRange;
    }
    if (code.contains('UNAUTHORIZED')) {
      return l10n.errorUnauthorized;
    }
    return l10n.errorGeneric;
  }
}
