import '../../../core/utils/formatters.dart';
import '../../stock/domain/stock_entities.dart';
import '../../stock/domain/stock_range_logic.dart';
import 'seller_entities.dart';

/// Pure business logic for Seller Khata balances, draw-grouped breakdowns,
/// reversal linking, ticket selection, and advance checks (§7.2–7.4).
abstract final class LedgerMath {
  static const int maxPaymentPaise = 1000000 * 100; // ₹10,00,000

  /// Validates that `amountPaise` is strictly > 0 and <= ₹10,00,000 (A.5).
  static bool isValidPaymentAmountPaise(int amountPaise) {
    return amountPaise > 0 && amountPaise <= maxPaymentPaise;
  }

  /// Returns `true` if `paymentAmountPaise` exceeds the seller's positive balance due (B.13).
  static bool willPaymentExceedBalance({
    required int currentBalancePaise,
    required int paymentAmountPaise,
  }) {
    final int positiveDue = currentBalancePaise > 0 ? currentBalancePaise : 0;
    return paymentAmountPaise > positiveDue;
  }

  /// Computes the advance credit amount (in paise) if `paymentAmountPaise` exceeds `currentBalancePaise`.
  static int computeAdvancePaise({
    required int currentBalancePaise,
    required int paymentAmountPaise,
  }) {
    final int afterPayment = currentBalancePaise - paymentAmountPaise;
    return afterPayment < 0 ? -afterPayment : 0;
  }

  /// Annotates entries that have been reversed by a subsequent `ADJUSTMENT`
  /// entry (`reversedEntryId == original.id`).
  static List<LedgerEntry> linkReversalPairs(List<LedgerEntry> entries) {
    final Map<String, String> reversedByMap = <String, String>{};
    for (final LedgerEntry entry in entries) {
      if (entry.reversedEntryId != null) {
        reversedByMap[entry.reversedEntryId!] = entry.id;
      }
    }
    return entries.map((LedgerEntry entry) {
      final String? revId = reversedByMap[entry.id];
      if (revId == null) {
        return entry;
      }
      return entry.copyWith(
        isReversed: true,
        reversedByEntryId: revId,
      );
    }).toList();
  }

  /// Exact sum of all ledger entries in paise.
  static int computeNetBalancePaise(List<LedgerEntry> entries) {
    int total = 0;
    for (final LedgerEntry e in entries) {
      total += e.amountPaise;
    }
    return total;
  }

  /// Computes the full balance breakdown grouped **by draw** (A.6), plus
  /// payments & adjustments and the grand total.
  static SellerBalanceBreakdown computeBalanceBreakdown({
    required List<LedgerEntry> entries,
    required Map<String, LotteryDraw> drawsById,
  }) {
    final Map<String, _MutableDrawAccumulator> drawAccMap =
        <String, _MutableDrawAccumulator>{};
    int paymentsTotalPaise = 0;
    int generalAdjustmentsPaise = 0;
    int grandTotalPaise = 0;

    for (final LedgerEntry e in entries) {
      grandTotalPaise += e.amountPaise;

      if (e.type == LedgerEntryType.payment) {
        paymentsTotalPaise += e.amountPaise;
        continue;
      }

      if (e.drawId != null &&
          (e.type == LedgerEntryType.issue ||
              e.type == LedgerEntryType.returnTickets ||
              e.type == LedgerEntryType.prizePaidBySeller ||
              e.type == LedgerEntryType.adjustment)) {
        final String dId = e.drawId!;
        final LotteryDraw? draw = drawsById[dId];
        final String label = draw == null
            ? 'Draw'
            : '${draw.lotteryName}${draw.drawNumber == null ? '' : ' (${draw.drawNumber})'} · ${AppFormatters.shortDate(draw.drawDate)}';
        final _MutableDrawAccumulator acc = drawAccMap.putIfAbsent(
          dId,
          () => _MutableDrawAccumulator(
            drawId: dId,
            drawLabel: label,
            drawDate: draw?.drawDate,
          ),
        );

        switch (e.type) {
          case LedgerEntryType.issue:
            acc.issuedPaise += e.amountPaise;
            acc.issuedTicketCount += e.ticketCount ?? 0;
            break;
          case LedgerEntryType.returnTickets:
            acc.returnedPaise += e.amountPaise;
            acc.returnedTicketCount += e.ticketCount ?? 0;
            break;
          case LedgerEntryType.prizePaidBySeller:
            acc.prizePaidPaise += e.amountPaise;
            break;
          case LedgerEntryType.adjustment:
            acc.drawAdjustmentsPaise += e.amountPaise;
            break;
          case LedgerEntryType.payment:
            break;
        }
      } else {
        generalAdjustmentsPaise += e.amountPaise;
      }
    }

    final List<DrawBreakdownRow> drawRows = drawAccMap.values
        .map((_MutableDrawAccumulator a) => a.toRow())
        .toList()
      ..sort((DrawBreakdownRow a, DrawBreakdownRow b) {
        if (a.drawDate == null && b.drawDate == null) {
          return a.drawId.compareTo(b.drawId);
        }
        if (a.drawDate == null) {
          return 1;
        }
        if (b.drawDate == null) {
          return -1;
        }
        return b.drawDate!.compareTo(a.drawDate!);
      });

    return SellerBalanceBreakdown(
      drawRows: drawRows,
      paymentsTotalPaise: paymentsTotalPaise,
      generalAdjustmentsPaise: generalAdjustmentsPaise,
      grandTotalPaise: grandTotalPaise,
    );
  }

  /// Picks the next `count` `IN_STOCK` tickets in deterministic `(series, number)` order (§7.2).
  /// Returns `null` if fewer than `count` `IN_STOCK` tickets are available.
  static List<TicketItem>? pickNextInStockTickets({
    required List<TicketItem> tickets,
    required int count,
    String? seriesFilter,
  }) {
    if (count < 1 || count > 5000) {
      return null;
    }
    final String? normalizedSeries =
        (seriesFilter == null || seriesFilter.trim().isEmpty)
            ? null
            : seriesFilter.trim().toUpperCase();

    final List<TicketItem> available = tickets.where((TicketItem t) {
      if (t.status != TicketStatus.inStock) {
        return false;
      }
      if (normalizedSeries != null && t.series != normalizedSeries) {
        return false;
      }
      return true;
    }).toList()
      ..sort((TicketItem a, TicketItem b) {
        final int cmpSeries = a.series.compareTo(b.series);
        if (cmpSeries != 0) {
          return cmpSeries;
        }
        return a.number.compareTo(b.number);
      });

    if (available.length < count) {
      return null;
    }
    return available.sublist(0, count);
  }

  /// Selects all tickets in `[series, startNumber..endNumber]` that match `requiredStatus`
  /// (and `requiredSellerId` if provided). Returns `null` if the range is invalid or any
  /// ticket in the range is missing or does not match `requiredStatus`.
  static List<TicketItem>? selectTicketsInRange({
    required List<TicketItem> tickets,
    required String series,
    required String startNumber,
    required String endNumber,
    required TicketStatus requiredStatus,
    String? requiredSellerId,
  }) {
    final StockRangeEvaluation eval = StockRangeLogic.evaluateRange(
      series: series,
      startNumber: startNumber,
      endNumber: endNumber,
      costPerTicketPaise: 0,
    );
    if (!eval.isValid) {
      return null;
    }

    final int startInt = int.parse(eval.paddedStart);
    final int endInt = int.parse(eval.paddedEnd);
    final Map<int, TicketItem> byNum = <int, TicketItem>{};

    for (final TicketItem t in tickets) {
      if (t.series == eval.normalizedSeries) {
        final int? n = int.tryParse(t.number);
        if (n != null && n >= startInt && n <= endInt) {
          byNum[n] = t;
        }
      }
    }

    if (byNum.length != eval.quantity) {
      return null;
    }

    final List<TicketItem> result = <TicketItem>[];
    for (int n = startInt; n <= endInt; n++) {
      final TicketItem? t = byNum[n];
      if (t == null || t.status != requiredStatus) {
        return null;
      }
      if (requiredSellerId != null && t.sellerId != requiredSellerId) {
        return null;
      }
      result.add(t);
    }
    return result;
  }

  /// Formats a list of tickets into contiguous human-readable ranges
  /// (e.g. `KR 482900–482949, KR 482960–482969`).
  static String summarizeTicketRanges(List<TicketItem> tickets) {
    if (tickets.isEmpty) {
      return '';
    }
    final List<TicketItem> sorted = List<TicketItem>.from(tickets)
      ..sort((TicketItem a, TicketItem b) {
        final int cmpS = a.series.compareTo(b.series);
        if (cmpS != 0) {
          return cmpS;
        }
        return a.number.compareTo(b.number);
      });

    final List<String> parts = <String>[];
    String currentSeries = sorted.first.series;
    String rangeStart = sorted.first.number;
    String rangeEnd = sorted.first.number;
    int prevNum = int.tryParse(sorted.first.number) ?? -10;

    for (int i = 1; i < sorted.length; i++) {
      final TicketItem t = sorted[i];
      final int numVal = int.tryParse(t.number) ?? -10;
      if (t.series == currentSeries && numVal == prevNum + 1) {
        rangeEnd = t.number;
        prevNum = numVal;
      } else {
        parts.add(
          rangeStart == rangeEnd
              ? '$currentSeries $rangeStart'
              : '$currentSeries $rangeStart–$rangeEnd',
        );
        currentSeries = t.series;
        rangeStart = t.number;
        rangeEnd = t.number;
        prevNum = numVal;
      }
    }
    parts.add(
      rangeStart == rangeEnd
          ? '$currentSeries $rangeStart'
          : '$currentSeries $rangeStart–$rangeEnd',
    );
    return parts.join(', ');
  }

  /// Filters and sorts sellers for the Sellers tab (§8.4, A.3).
  static List<SellerSummary> filterAndSortSellers({
    required List<SellerSummary> sellers,
    required String searchQuery,
    required SellerSortMode sortMode,
    required bool showInactive,
  }) {
    final String q = searchQuery.trim().toLowerCase();
    final List<SellerSummary> filtered = sellers.where((SellerSummary s) {
      if (showInactive) {
        if (s.seller.isActive) {
          return false;
        }
      } else {
        if (!s.seller.isActive) {
          return false;
        }
      }

      if (q.isEmpty) {
        return true;
      }
      final bool nameMatch = s.seller.name.toLowerCase().contains(q);
      final bool areaMatch =
          (s.seller.area?.toLowerCase().contains(q) ?? false);
      final bool phoneMatch =
          (s.seller.phone?.toLowerCase().contains(q) ?? false);
      return nameMatch || areaMatch || phoneMatch;
    }).toList();

    filtered.sort((SellerSummary a, SellerSummary b) {
      switch (sortMode) {
        case SellerSortMode.highestDue:
          final int cmpDue = b.balancePaise.compareTo(a.balancePaise);
          if (cmpDue != 0) {
            return cmpDue;
          }
          return a.seller.name
              .toLowerCase()
              .compareTo(b.seller.name.toLowerCase());
        case SellerSortMode.name:
          return a.seller.name
              .toLowerCase()
              .compareTo(b.seller.name.toLowerCase());
        case SellerSortMode.recent:
          return b.lastActivityAt.compareTo(a.lastActivityAt);
      }
    });

    return filtered;
  }
}

class _MutableDrawAccumulator {
  _MutableDrawAccumulator({
    required this.drawId,
    required this.drawLabel,
    this.drawDate,
  });

  final String drawId;
  final String drawLabel;
  final DateTime? drawDate;
  int issuedPaise = 0;
  int issuedTicketCount = 0;
  int returnedPaise = 0;
  int returnedTicketCount = 0;
  int prizePaidPaise = 0;
  int drawAdjustmentsPaise = 0;

  DrawBreakdownRow toRow() {
    return DrawBreakdownRow(
      drawId: drawId,
      drawLabel: drawLabel,
      drawDate: drawDate,
      issuedPaise: issuedPaise,
      issuedTicketCount: issuedTicketCount,
      returnedPaise: returnedPaise,
      returnedTicketCount: returnedTicketCount,
      prizePaidPaise: prizePaidPaise,
      drawAdjustmentsPaise: drawAdjustmentsPaise,
    );
  }
}
