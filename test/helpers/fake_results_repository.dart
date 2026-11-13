import 'package:lucky_ledger/features/results/data/results_repository.dart';
import 'package:lucky_ledger/features/results/domain/prize_matcher.dart';
import 'package:lucky_ledger/features/results/domain/result_entities.dart';
import 'package:lucky_ledger/features/stock/domain/stock_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_repositories.dart';

class FakeResultsRepository implements ResultsRepository {
  FakeResultsRepository(this._stockRepository);

  final FakeStockRepository _stockRepository;
  final Map<String, List<DrawPrizeTier>> _tiersByDraw =
      <String, List<DrawPrizeTier>>{};
  final Map<String, List<DrawResultEntry>> _resultsByDraw =
      <String, List<DrawResultEntry>>{};
  final Map<String, List<WinningTicket>> _winsByDraw =
      <String, List<WinningTicket>>{};
  final Map<String, DrawSummaryRecord> _summariesByDraw =
      <String, DrawSummaryRecord>{};
  int _idSeq = 0;

  void seedPrizeTiers(String drawId, List<DrawPrizeTier> tiers) {
    _tiersByDraw[drawId] = List<DrawPrizeTier>.from(tiers);
  }

  @override
  Future<List<DrawPrizeTier>> fetchPrizeTiers(String drawId) async {
    return List<DrawPrizeTier>.unmodifiable(
      _tiersByDraw[drawId] ?? const <DrawPrizeTier>[],
    );
  }

  @override
  Future<List<DrawResultEntry>> fetchDrawResults(String drawId) async {
    return List<DrawResultEntry>.unmodifiable(
      _resultsByDraw[drawId] ?? const <DrawResultEntry>[],
    );
  }

  @override
  Future<List<WinningTicket>> fetchWinsForDraw(
    String drawId, {
    int offset = 0,
    int limit = 200,
  }) async {
    final List<WinningTicket> list = _winsByDraw[drawId] ?? <WinningTicket>[];
    if (offset >= list.length) {
      return const <WinningTicket>[];
    }
    final int end = (offset + limit) > list.length ? list.length : offset + limit;
    return list.sublist(offset, end);
  }

  @override
  Future<List<WinningTicket>> fetchWinsForSeller(
    String sellerId, {
    int offset = 0,
    int limit = 200,
  }) async {
    final List<WinningTicket> all = <WinningTicket>[];
    for (final List<WinningTicket> list in _winsByDraw.values) {
      all.addAll(list.where((WinningTicket w) => w.sellerId == sellerId));
    }
    if (offset >= all.length) {
      return const <WinningTicket>[];
    }
    final int end = (offset + limit) > all.length ? all.length : offset + limit;
    return all.sublist(offset, end);
  }

  @override
  Future<DrawSummaryRecord?> fetchDrawSummary(String drawId) async {
    return _summariesByDraw[drawId];
  }

  @override
  Future<int> countWithSellerTickets(String drawId) async {
    final List<TicketItem> all =
        await _stockRepository.fetchTicketsForDraw(drawId);
    return all
        .where((TicketItem t) => t.status == TicketStatus.withSeller)
        .length;
  }

  @override
  Future<int> saveDrawResultsAndCheck({
    required String drawId,
    required List<ResultEntryInput> entries,
    bool force = false,
  }) async {
    final LotteryDraw? draw = _stockRepository.getDrawById(drawId);
    if (draw == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    if (draw.status == DrawStatus.closed) {
      throw const PostgrestException(message: 'DRAW_CLOSED');
    }

    final List<DrawPrizeTier> tiers = _tiersByDraw[drawId] ?? <DrawPrizeTier>[];
    final List<ResultEntryInput> allEntries =
        ResultEntryValidator.withAutoConsolation(
      tiers: tiers,
      userEntries: entries,
    );

    final List<DrawResultEntry> saved = allEntries
        .map(
          (ResultEntryInput e) => DrawResultEntry(
            id: 'res-${++_idSeq}',
            drawId: drawId,
            tierId: e.tierId,
            winningSeries: e.winningSeries,
            winningNumber: e.winningNumber,
          ),
        )
        .toList();

    final List<DrawResultEntry>? previous = _resultsByDraw[drawId];
    _resultsByDraw[drawId] = saved;
    try {
      return await checkDraw(drawId: drawId, force: force);
    } catch (_) {
      if (previous == null) {
        _resultsByDraw.remove(drawId);
      } else {
        _resultsByDraw[drawId] = previous;
      }
      rethrow;
    }
  }

  @override
  Future<int> checkDraw({
    required String drawId,
    bool force = false,
  }) async {
    final LotteryDraw? draw = _stockRepository.getDrawById(drawId);
    if (draw == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    if (draw.status == DrawStatus.closed) {
      throw const PostgrestException(message: 'DRAW_CLOSED');
    }

    final List<TicketItem> tickets =
        await _stockRepository.fetchTicketsForDraw(drawId);
    final List<DrawPrizeTier> tiers = _tiersByDraw[drawId] ?? <DrawPrizeTier>[];
    final List<ResultEntryInput> entries = (_resultsByDraw[drawId] ??
            const <DrawResultEntry>[])
        .map(
          (DrawResultEntry r) => ResultEntryInput(
            tierId: r.tierId,
            winningSeries: r.winningSeries,
            winningNumber: r.winningNumber,
          ),
        )
        .toList();

    final List<WinningTicket> computed = PrizeMatcher.matchTickets(
      tickets: tickets,
      tiers: tiers,
      entries: entries,
    );

    final List<WinningTicket> existing =
        _winsByDraw[drawId] ?? const <WinningTicket>[];
    final Map<String, WinningTicket> computedByTicket =
        <String, WinningTicket>{
      for (final WinningTicket w in computed) w.ticketId: w,
    };

    if (!force) {
      final List<String> affected = <String>[];
      for (final WinningTicket oldWin in existing) {
        if (oldWin.claimStatus != WinClaimStatus.unclaimed) {
          final WinningTicket? nextWin = computedByTicket[oldWin.ticketId];
          if (nextWin == null ||
              nextWin.prizeAmountPaise != oldWin.prizeAmountPaise) {
            affected.add('${oldWin.ticketSeries} ${oldWin.ticketNumber}');
          }
        }
      }
      if (affected.isNotEmpty) {
        throw PostgrestException(
          message: 'CLAIMED_WIN_AFFECTED',
          details: affected.join(', '),
        );
      }
    }

    final Map<String, WinningTicket> existingByTicket =
        <String, WinningTicket>{
      for (final WinningTicket w in existing) w.ticketId: w,
    };
    final List<WinningTicket> merged = computed.map((WinningTicket w) {
      final WinningTicket? oldWin = existingByTicket[w.ticketId];
      if (oldWin != null && oldWin.claimStatus != WinClaimStatus.unclaimed) {
        return w.copyWith(claimStatus: oldWin.claimStatus);
      }
      return w;
    }).toList();

    _winsByDraw[drawId] = merged;
    return merged.length;
  }

  @override
  Future<void> updateWinClaimStatus({
    required String winId,
    required WinClaimStatus status,
  }) async {
    for (final MapEntry<String, List<WinningTicket>> entry
        in _winsByDraw.entries) {
      final int idx =
          entry.value.indexWhere((WinningTicket w) => w.id == winId);
      if (idx != -1) {
        entry.value[idx] = entry.value[idx].copyWith(claimStatus: status);
        return;
      }
    }
    throw const PostgrestException(message: 'NOT_FOUND');
  }

  @override
  Future<void> closeDraw(String drawId) async {
    final LotteryDraw? draw = _stockRepository.getDrawById(drawId);
    if (draw == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final List<TicketItem> tickets =
        await _stockRepository.fetchTicketsForDraw(drawId);
    final int counter = tickets
        .where((TicketItem t) => t.status == TicketStatus.soldCounter)
        .length;
    final int seller = tickets
        .where(
          (TicketItem t) =>
              t.status == TicketStatus.withSeller ||
              t.status == TicketStatus.soldBySeller,
        )
        .length;
    final int unsold = tickets.length - counter - seller;
    final int totalPrizes = (_winsByDraw[drawId] ?? const <WinningTicket>[])
        .fold<int>(0, (int sum, WinningTicket w) => sum + w.prizeAmountPaise);

    _summariesByDraw[drawId] = DrawSummaryRecord(
      shopId: draw.shopId,
      drawId: drawId,
      ticketsBought: tickets.length,
      ticketsSoldCounter: counter,
      ticketsSoldSeller: seller,
      ticketsUnsold: unsold,
      totalCostPaise: tickets.length * 3500,
      grossRevenuePaise: (counter + seller) * draw.ticketPricePaise,
      totalPrizesWonPaise: totalPrizes,
    );
  }
}
