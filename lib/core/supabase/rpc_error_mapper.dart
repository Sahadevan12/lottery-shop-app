import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Maps Postgres RPC exception codes (`STOCK_OVERLAP`, `BATCH_IN_USE`, `DRAW_NOT_OPEN`,
/// `DRAW_EXISTS`, `NOT_FOUND`, `INVALID_RANGE`, `UNAUTHORIZED`, §6.1) to localized messages.
abstract final class RpcErrorMapper {
  static String toLocalizedMessage(Object error, AppLocalizations l10n) {
    String code = '';
    String detail = '';

    if (error is PostgrestException) {
      code = error.message.toUpperCase();
      detail = (error.details?.toString() ?? '').trim();
    } else {
      code = error.toString().toUpperCase();
      final RegExp detailMatch = RegExp(r'DETAIL:\s*(.+)', caseSensitive: false);
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
