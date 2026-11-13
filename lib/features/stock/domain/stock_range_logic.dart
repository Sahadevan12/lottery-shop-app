import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import 'stock_entities.dart';

enum StockRangeError {
  invalidSeries,
  invalidStartNumber,
  invalidEndNumber,
  endBeforeStart,
  exceedsMaxBatchSize,
}

@immutable
class StockRangeEvaluation {
  const StockRangeEvaluation({
    required this.isValid,
    this.error,
    required this.normalizedSeries,
    required this.paddedStart,
    required this.paddedEnd,
    required this.quantity,
    required this.totalCostPaise,
  });

  final bool isValid;
  final StockRangeError? error;
  final String normalizedSeries;
  final String paddedStart;
  final String paddedEnd;
  final int quantity;
  final int totalCostPaise;
}

/// Pure business logic for Stock Ranges, Overlap Detection, and Draw Summaries (§7.1).
abstract final class StockRangeLogic {
  static final RegExp _digitsUpTo6 = RegExp(r'^\d{1,6}$');

  /// Evaluates a series + start..end range and calculates quantity and total cost in paise.
  /// - Zero-pads numbers up to 6 digits (`123` -> `000123`).
  /// - Enforces `end >= start` and `quantity <= 5,000`.
  static StockRangeEvaluation evaluateRange({
    required String series,
    required String startNumber,
    required String endNumber,
    int? costPerTicketPaise,
  }) {
    final String cleanSeries = series.trim().toUpperCase();
    final String cleanStart = startNumber.trim();
    final String cleanEnd = endNumber.trim();

    if (!AppValidators.isValidSeries(cleanSeries)) {
      return StockRangeEvaluation(
        isValid: false,
        error: StockRangeError.invalidSeries,
        normalizedSeries: cleanSeries,
        paddedStart: cleanStart,
        paddedEnd: cleanEnd,
        quantity: 0,
        totalCostPaise: 0,
      );
    }

    if (!_digitsUpTo6.hasMatch(cleanStart)) {
      return StockRangeEvaluation(
        isValid: false,
        error: StockRangeError.invalidStartNumber,
        normalizedSeries: cleanSeries,
        paddedStart: cleanStart,
        paddedEnd: cleanEnd,
        quantity: 0,
        totalCostPaise: 0,
      );
    }

    if (!_digitsUpTo6.hasMatch(cleanEnd)) {
      return StockRangeEvaluation(
        isValid: false,
        error: StockRangeError.invalidEndNumber,
        normalizedSeries: cleanSeries,
        paddedStart: cleanStart,
        paddedEnd: cleanEnd,
        quantity: 0,
        totalCostPaise: 0,
      );
    }

    final int startInt = int.parse(cleanStart);
    final int endInt = int.parse(cleanEnd);
    final String paddedStart = AppFormatters.padTicketNumber(startInt);
    final String paddedEnd = AppFormatters.padTicketNumber(endInt);

    if (endInt < startInt) {
      return StockRangeEvaluation(
        isValid: false,
        error: StockRangeError.endBeforeStart,
        normalizedSeries: cleanSeries,
        paddedStart: paddedStart,
        paddedEnd: paddedEnd,
        quantity: 0,
        totalCostPaise: 0,
      );
    }

    final int quantity = endInt - startInt + 1;
    if (quantity > AppConstants.maxBatchTickets) {
      return StockRangeEvaluation(
        isValid: false,
        error: StockRangeError.exceedsMaxBatchSize,
        normalizedSeries: cleanSeries,
        paddedStart: paddedStart,
        paddedEnd: paddedEnd,
        quantity: quantity,
        totalCostPaise: 0,
      );
    }

    final int totalCostPaise = (costPerTicketPaise ?? 0) * quantity;
    return StockRangeEvaluation(
      isValid: true,
      normalizedSeries: cleanSeries,
      paddedStart: paddedStart,
      paddedEnd: paddedEnd,
      quantity: quantity,
      totalCostPaise: totalCostPaise,
    );
  }

  /// Checks if `[startNumber..endNumber]` in `series` overlaps with any batch in `existingBatches`.
  /// Returns the formatted overlapping range (e.g. `KR 482950–482999`) if an overlap exists,
  /// or `null` if no overlap.
  static String? findOverlappingRange({
    required String series,
    required String startNumber,
    required String endNumber,
    required List<StockBatch> existingBatches,
  }) {
    final StockRangeEvaluation eval = evaluateRange(
      series: series,
      startNumber: startNumber,
      endNumber: endNumber,
    );
    if (!eval.isValid) {
      return null;
    }

    final int reqStart = int.parse(eval.paddedStart);
    final int reqEnd = int.parse(eval.paddedEnd);

    for (final StockBatch batch in existingBatches) {
      if (batch.series.trim().toUpperCase() != eval.normalizedSeries) {
        continue;
      }
      final int bStart = int.parse(batch.startNumber.trim());
      final int bEnd = int.parse(batch.endNumber.trim());

      final int overlapStart = math.max(reqStart, bStart);
      final int overlapEnd = math.min(reqEnd, bEnd);
      if (overlapStart <= overlapEnd) {
        final String sStr = AppFormatters.padTicketNumber(overlapStart);
        final String eStr = AppFormatters.padTicketNumber(overlapEnd);
        return '${eval.normalizedSeries} $sStr–$eStr';
      }
    }
    return null;
  }

  /// Aggregates batch counts into a `DrawStockSummary` (§7.1).
  static DrawStockSummary summarizeBatches(List<StockBatch> batches) {
    int total = 0;
    int inStock = 0;
    int withSellers = 0;
    int sold = 0;
    int returned = 0;

    for (final StockBatch b in batches) {
      total += b.quantity;
      inStock += b.inStockCount;
      withSellers += b.withSellerCount;
      sold += b.soldCount;
      returned += b.returnedCount;
    }

    return DrawStockSummary(
      total: total,
      inStock: inStock,
      withSellers: withSellers,
      sold: sold,
      returnedUnsold: returned,
    );
  }

  /// Finds the default lottery for a given date based on `defaultWeekday` (1=Mon..7=Sun).
  static LotteryItem? findDefaultLotteryForDate(
    List<LotteryItem> lotteries,
    DateTime date,
  ) {
    final int weekday = date.weekday;
    for (final LotteryItem lottery in lotteries) {
      if (!lottery.isBumper && lottery.defaultWeekday == weekday) {
        return lottery;
      }
    }
    for (final LotteryItem lottery in lotteries) {
      if (!lottery.isBumper) {
        return lottery;
      }
    }
    return lotteries.isEmpty ? null : lotteries.first;
  }
}
