import '../../stock/domain/stock_entities.dart';
import 'result_entities.dart';

enum ResultEntryValidationError {
  invalidFull,
  invalidLast4,
  invalidLast3,
  duplicate,
}

/// Pure validation & prize-matching logic mirroring server-side `check_draw`
/// and `save_draw_results_and_check` (§7.5, Rules a, b, e, f).
abstract final class ResultEntryValidator {
  static final RegExp _seriesPattern = RegExp(r'^[A-Z]{2,3}$');
  static final RegExp _digits6Pattern = RegExp(r'^[0-9]{6}$');
  static final RegExp _digits4Pattern = RegExp(r'^[0-9]{4}$');
  static final RegExp _digits3Pattern = RegExp(r'^[0-9]{3}$');

  static ResultEntryValidationError? validate({
    required PrizeMatchType matchType,
    String? series,
    required String number,
  }) {
    final String normalizedSeries = (series ?? '').trim().toUpperCase();
    final String normalizedNumber = number.trim();

    switch (matchType) {
      case PrizeMatchType.full:
        if (!_seriesPattern.hasMatch(normalizedSeries) ||
            !_digits6Pattern.hasMatch(normalizedNumber)) {
          return ResultEntryValidationError.invalidFull;
        }
        return null;
      case PrizeMatchType.last4:
        if (!_digits4Pattern.hasMatch(normalizedNumber)) {
          return ResultEntryValidationError.invalidLast4;
        }
        return null;
      case PrizeMatchType.last3:
        if (!_digits3Pattern.hasMatch(normalizedNumber)) {
          return ResultEntryValidationError.invalidLast3;
        }
        return null;
      case PrizeMatchType.consolation:
        if (!_digits6Pattern.hasMatch(normalizedNumber)) {
          return ResultEntryValidationError.invalidFull;
        }
        return null;
    }
  }

  /// Returns indexes of entries that duplicate an earlier entry in the same tier.
  static Set<int> findDuplicateIndexes({
    required PrizeMatchType matchType,
    required List<({String? series, String number})> entries,
  }) {
    final Set<String> seen = <String>{};
    final Set<int> duplicates = <int>{};

    for (int i = 0; i < entries.length; i++) {
      final String s = matchType == PrizeMatchType.full
          ? (entries[i].series ?? '').trim().toUpperCase()
          : '';
      final String n = entries[i].number.trim();
      if (n.isEmpty) {
        continue;
      }
      final String key = '$s|$n';
      if (!seen.add(key)) {
        duplicates.add(i);
      }
    }
    return duplicates;
  }

  /// Auto-generates `CONSOLATION` entries from 1st prize (`tier_order == 1` or
  /// lowest `tier_order` `FULL` tier) so the owner never types them (Rule e).
  static List<ResultEntryInput> withAutoConsolation({
    required List<DrawPrizeTier> tiers,
    required List<ResultEntryInput> userEntries,
  }) {
    final List<DrawPrizeTier> consolationTiers = tiers
        .where((DrawPrizeTier t) => t.matchType == PrizeMatchType.consolation)
        .toList();
    if (consolationTiers.isEmpty) {
      return userEntries;
    }

    final List<DrawPrizeTier> fullTiers = tiers
        .where((DrawPrizeTier t) => t.matchType == PrizeMatchType.full)
        .toList()
      ..sort(
        (DrawPrizeTier a, DrawPrizeTier b) => a.tierOrder.compareTo(b.tierOrder),
      );
    if (fullTiers.isEmpty) {
      return userEntries;
    }

    final String firstPrizeTierId = fullTiers.first.id;
    final List<ResultEntryInput> firstPrizeEntries = userEntries
        .where((ResultEntryInput e) => e.tierId == firstPrizeTierId)
        .toList();

    final List<ResultEntryInput> nonConsolation = userEntries
        .where(
          (ResultEntryInput e) => !consolationTiers.any(
            (DrawPrizeTier c) => c.id == e.tierId,
          ),
        )
        .toList();

    final List<ResultEntryInput> generated = <ResultEntryInput>[];
    for (final DrawPrizeTier cTier in consolationTiers) {
      for (final ResultEntryInput first in firstPrizeEntries) {
        generated.add(
          ResultEntryInput(
            tierId: cTier.id,
            winningSeries: first.winningSeries?.trim().toUpperCase(),
            winningNumber: first.winningNumber.trim(),
          ),
        );
      }
    }

    return <ResultEntryInput>[...nonConsolation, ...generated];
  }
}

abstract final class PrizeMatcher {
  /// Maps [TicketStatus] to [WinSoldBy] per Rule b:
  /// - `SOLD_COUNTER` -> `COUNTER`
  /// - `WITH_SELLER` / `SOLD_BY_SELLER` -> `SELLER`
  /// - `IN_STOCK` / `RETURNED_UNSOLD` -> `UNSOLD`
  static WinSoldBy mapSoldBy(TicketStatus status) {
    switch (status) {
      case TicketStatus.soldCounter:
        return WinSoldBy.counter;
      case TicketStatus.withSeller:
      case TicketStatus.soldBySeller:
        return WinSoldBy.seller;
      case TicketStatus.inStock:
      case TicketStatus.returnedUnsold:
        return WinSoldBy.unsold;
    }
  }

  /// Matches [tickets] against [entries] across [tiers], returning at most one
  /// [WinningTicket] per ticket (highest prize / lowest `tierOrder` wins).
  static List<WinningTicket> matchTickets({
    required List<TicketItem> tickets,
    required List<DrawPrizeTier> tiers,
    required List<ResultEntryInput> entries,
    Map<String, String> sellerNamesById = const <String, String>{},
  }) {
    if (tickets.isEmpty || tiers.isEmpty || entries.isEmpty) {
      return const <WinningTicket>[];
    }

    final List<ResultEntryInput> allEntries =
        ResultEntryValidator.withAutoConsolation(
      tiers: tiers,
      userEntries: entries,
    );

    final Map<String, DrawPrizeTier> tierById = <String, DrawPrizeTier>{
      for (final DrawPrizeTier t in tiers) t.id: t,
    };

    final List<({DrawPrizeTier tier, ResultEntryInput entry})> orderedPairs =
        <({DrawPrizeTier tier, ResultEntryInput entry})>[];
    for (final ResultEntryInput entry in allEntries) {
      final DrawPrizeTier? tier = tierById[entry.tierId];
      if (tier != null) {
        orderedPairs.add((tier: tier, entry: entry));
      }
    }
    orderedPairs.sort((a, b) {
      final int orderCmp = a.tier.tierOrder.compareTo(b.tier.tierOrder);
      if (orderCmp != 0) {
        return orderCmp;
      }
      return b.tier.amountPaise.compareTo(a.tier.amountPaise);
    });

    final List<WinningTicket> wins = <WinningTicket>[];
    final DateTime now = DateTime.now().toUtc();

    for (final TicketItem ticket in tickets) {
      DrawPrizeTier? matchedTier;
      for (final pair in orderedPairs) {
        if (_matches(ticket: ticket, tier: pair.tier, entry: pair.entry)) {
          matchedTier = pair.tier;
          break;
        }
      }
      if (matchedTier == null) {
        continue;
      }

      final WinSoldBy soldBy = mapSoldBy(ticket.status);
      final String? sellerId =
          soldBy == WinSoldBy.seller ? ticket.sellerId : null;
      final WinClaimStatus claimStatus = soldBy == WinSoldBy.unsold
          ? WinClaimStatus.unsoldWin
          : WinClaimStatus.unclaimed;

      wins.add(
        WinningTicket(
          id: 'win-${ticket.id}',
          shopId: ticket.shopId,
          drawId: ticket.drawId,
          ticketId: ticket.id,
          tierId: matchedTier.id,
          prizeAmountPaise: matchedTier.amountPaise,
          soldBy: soldBy,
          sellerId: sellerId,
          claimStatus: claimStatus,
          createdAt: now,
          ticketSeries: ticket.series,
          ticketNumber: ticket.number,
          tierLabel: matchedTier.label,
          tierOrder: matchedTier.tierOrder,
          sellerName: sellerId == null ? null : sellerNamesById[sellerId],
        ),
      );
    }

    wins.sort((WinningTicket a, WinningTicket b) {
      final int orderCmp = a.tierOrder.compareTo(b.tierOrder);
      if (orderCmp != 0) {
        return orderCmp;
      }
      final int sCmp = a.ticketSeries.compareTo(b.ticketSeries);
      return sCmp != 0 ? sCmp : a.ticketNumber.compareTo(b.ticketNumber);
    });

    return wins;
  }

  static bool _matches({
    required TicketItem ticket,
    required DrawPrizeTier tier,
    required ResultEntryInput entry,
  }) {
    final String entryNum = entry.winningNumber.trim();
    final String? entrySeries = entry.winningSeries?.trim().toUpperCase();

    switch (tier.matchType) {
      case PrizeMatchType.full:
        return ticket.series.toUpperCase() == entrySeries &&
            ticket.number == entryNum;
      case PrizeMatchType.consolation:
        return ticket.number == entryNum &&
            (entrySeries == null ||
                entrySeries.isEmpty ||
                ticket.series.toUpperCase() != entrySeries);
      case PrizeMatchType.last4:
        return ticket.number.length >= 4 &&
            ticket.number.substring(ticket.number.length - 4) == entryNum;
      case PrizeMatchType.last3:
        return ticket.number.length >= 3 &&
            ticket.number.substring(ticket.number.length - 3) == entryNum;
    }
  }
}
