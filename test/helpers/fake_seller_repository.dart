import 'package:lucky_ledger/features/sellers/data/seller_repository.dart';
import 'package:lucky_ledger/features/sellers/domain/ledger_math.dart';
import 'package:lucky_ledger/features/sellers/domain/seller_entities.dart';
import 'package:lucky_ledger/features/stock/domain/stock_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_repositories.dart';

/// Test-only fake implementation of [SellerRepository] (kept under `test/` only).
class FakeSellerRepository implements SellerRepository {
  FakeSellerRepository(this._stockRepository);

  final FakeStockRepository _stockRepository;
  final List<SellerProfile> _sellers = <SellerProfile>[];
  final List<LedgerEntry> _entries = <LedgerEntry>[];
  int _idSeq = 1;

  List<LedgerEntry> get rawEntries => List<LedgerEntry>.unmodifiable(_entries);

  SellerProfile? _findSeller(String sellerId) {
    for (final SellerProfile s in _sellers) {
      if (s.id == sellerId) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<List<SellerSummary>> fetchSellersWithBalances() async {
    final List<TicketItem> allTickets = _stockRepository.getAllTickets();
    final List<SellerSummary> summaries = <SellerSummary>[];

    for (final SellerProfile s in _sellers) {
      final List<LedgerEntry> sellerEntries = _entries
          .where((LedgerEntry e) => e.sellerId == s.id)
          .toList();
      final int balance = LedgerMath.computeNetBalancePaise(sellerEntries);
      final int ticketsWithSeller = allTickets
          .where(
            (TicketItem t) =>
                t.sellerId == s.id && t.status == TicketStatus.withSeller,
          )
          .length;
      DateTime lastActivity = s.createdAt;
      for (final LedgerEntry e in sellerEntries) {
        if (e.createdAt.isAfter(lastActivity)) {
          lastActivity = e.createdAt;
        }
      }
      summaries.add(
        SellerSummary(
          seller: s,
          balancePaise: balance,
          ticketsWithSeller: ticketsWithSeller,
          hasLedgerHistory: sellerEntries.isNotEmpty,
          lastActivityAt: lastActivity,
        ),
      );
    }
    return summaries;
  }

  @override
  Future<SellerProfile> saveSeller({
    String? id,
    required String name,
    String? phone,
    String? area,
  }) async {
    final String trimmedName = name.trim();
    final String? trimmedPhone =
        (phone == null || phone.trim().isEmpty) ? null : phone.trim();
    final String? trimmedArea =
        (area == null || area.trim().isEmpty) ? null : area.trim();

    if (id == null) {
      final SellerProfile created = SellerProfile(
        id: 'seller-${++_idSeq}',
        shopId: 'shop-1',
        name: trimmedName,
        phone: trimmedPhone,
        area: trimmedArea,
        isActive: true,
        createdAt: DateTime.now().toUtc(),
      );
      _sellers.add(created);
      return created;
    }

    final int idx = _sellers.indexWhere((SellerProfile s) => s.id == id);
    if (idx == -1) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final SellerProfile old = _sellers[idx];
    final SellerProfile updated = SellerProfile(
      id: old.id,
      shopId: old.shopId,
      name: trimmedName,
      phone: trimmedPhone,
      area: trimmedArea,
      isActive: old.isActive,
      createdAt: old.createdAt,
    );
    _sellers[idx] = updated;
    return updated;
  }

  @override
  Future<SellerProfile> setSellerActive({
    required String sellerId,
    required bool isActive,
  }) async {
    final int idx = _sellers.indexWhere((SellerProfile s) => s.id == sellerId);
    if (idx == -1) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final SellerProfile updated = _sellers[idx].copyWith(isActive: isActive);
    _sellers[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteSeller(String sellerId) async {
    final SellerProfile? seller = _findSeller(sellerId);
    if (seller == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final bool hasEntries = _entries.any(
      (LedgerEntry e) => e.sellerId == sellerId,
    );
    final bool hasTickets = _stockRepository
        .getAllTickets()
        .any((TicketItem t) => t.sellerId == sellerId);
    if (hasEntries || hasTickets) {
      throw const PostgrestException(
        message: 'update or delete on table "sellers" violates foreign key',
        code: '23503',
      );
    }
    _sellers.removeWhere((SellerProfile s) => s.id == sellerId);
  }

  @override
  Future<List<LedgerEntry>> fetchSellerLedger(String sellerId) async {
    final List<LedgerEntry> filtered = _entries
        .where((LedgerEntry e) => e.sellerId == sellerId)
        .toList()
      ..sort(
        (LedgerEntry a, LedgerEntry b) => b.createdAt.compareTo(a.createdAt),
      );
    return LedgerMath.linkReversalPairs(filtered);
  }

  @override
  Future<List<TicketItem>> fetchSellerTickets(String sellerId) async {
    final List<TicketItem> list = _stockRepository
        .getAllTickets()
        .where((TicketItem t) => t.sellerId == sellerId)
        .toList()
      ..sort((TicketItem a, TicketItem b) {
        final int sCmp = a.series.compareTo(b.series);
        return sCmp != 0 ? sCmp : a.number.compareTo(b.number);
      });
    return list;
  }

  @override
  Future<String> issueTickets({
    required String sellerId,
    required String drawId,
    required List<String> ticketIds,
  }) async {
    if (ticketIds.isEmpty) {
      throw const PostgrestException(message: 'EMPTY_TICKETS');
    }
    final SellerProfile? seller = _findSeller(sellerId);
    if (seller == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    if (!seller.isActive) {
      throw const PostgrestException(message: 'SELLER_INACTIVE');
    }
    final LotteryDraw? draw = _stockRepository.getDrawById(drawId);
    if (draw == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    if (draw.status != DrawStatus.upcoming) {
      throw const PostgrestException(message: 'DRAW_NOT_OPEN');
    }

    final Set<String> distinctIds = ticketIds.toSet();
    final List<TicketItem> allTickets = _stockRepository.getAllTickets();
    final List<TicketItem> matching = allTickets
        .where(
          (TicketItem t) =>
              distinctIds.contains(t.id) &&
              t.drawId == drawId &&
              t.status == TicketStatus.inStock,
        )
        .toList();

    if (matching.length != distinctIds.length) {
      throw const PostgrestException(message: 'TICKETS_NOT_AVAILABLE');
    }

    final DateTime now = DateTime.now().toUtc();
    final Map<String, TicketItem> updates = <String, TicketItem>{
      for (final TicketItem t in matching)
        t.id: TicketItem(
          id: t.id,
          shopId: t.shopId,
          drawId: t.drawId,
          batchId: t.batchId,
          series: t.series,
          number: t.number,
          status: TicketStatus.withSeller,
          sellerId: sellerId,
        ),
    };
    _stockRepository.replaceTicketsById(updates);

    final String entryId = 'entry-${++_idSeq}';
    final int amountPaise = matching.length * draw.ticketPricePaise;
    final String summary = LedgerMath.summarizeTicketRanges(matching);
    _entries.add(
      LedgerEntry(
        id: entryId,
        shopId: 'shop-1',
        sellerId: sellerId,
        drawId: drawId,
        type: LedgerEntryType.issue,
        amountPaise: amountPaise,
        ticketCount: matching.length,
        note: 'Issued ${matching.length} tickets ($summary)',
        createdAt: now,
      ),
    );
    return entryId;
  }

  @override
  Future<String> returnTickets({
    required String sellerId,
    required String drawId,
    required List<String> ticketIds,
  }) async {
    if (ticketIds.isEmpty) {
      throw const PostgrestException(message: 'EMPTY_TICKETS');
    }
    final SellerProfile? seller = _findSeller(sellerId);
    if (seller == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final LotteryDraw? draw = _stockRepository.getDrawById(drawId);
    if (draw == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    if (draw.status == DrawStatus.closed) {
      throw const PostgrestException(message: 'DRAW_NOT_OPEN');
    }

    final Set<String> distinctIds = ticketIds.toSet();
    final List<TicketItem> allTickets = _stockRepository.getAllTickets();
    final List<TicketItem> matching = allTickets
        .where(
          (TicketItem t) =>
              distinctIds.contains(t.id) &&
              t.drawId == drawId &&
              t.sellerId == sellerId &&
              t.status == TicketStatus.withSeller,
        )
        .toList();

    if (matching.length != distinctIds.length) {
      throw const PostgrestException(message: 'TICKETS_NOT_WITH_SELLER');
    }

    final DateTime now = DateTime.now().toUtc();
    final bool backToStock = draw.status == DrawStatus.upcoming;
    final Map<String, TicketItem> updates = <String, TicketItem>{
      for (final TicketItem t in matching)
        t.id: TicketItem(
          id: t.id,
          shopId: t.shopId,
          drawId: t.drawId,
          batchId: t.batchId,
          series: t.series,
          number: t.number,
          status: backToStock
              ? TicketStatus.inStock
              : TicketStatus.returnedUnsold,
          sellerId: backToStock ? null : sellerId,
        ),
    };
    _stockRepository.replaceTicketsById(updates);

    final String entryId = 'entry-${++_idSeq}';
    final int amountPaise = -(matching.length * draw.ticketPricePaise);
    final String summary = LedgerMath.summarizeTicketRanges(matching);
    _entries.add(
      LedgerEntry(
        id: entryId,
        shopId: 'shop-1',
        sellerId: sellerId,
        drawId: drawId,
        type: LedgerEntryType.returnTickets,
        amountPaise: amountPaise,
        ticketCount: matching.length,
        note: 'Returned ${matching.length} unsold tickets ($summary)',
        createdAt: now,
      ),
    );
    return entryId;
  }

  @override
  Future<String> recordPayment({
    required String sellerId,
    required int amountPaise,
    required PaymentMethod method,
    String? note,
  }) async {
    if (!LedgerMath.isValidPaymentAmountPaise(amountPaise)) {
      throw const PostgrestException(message: 'INVALID_AMOUNT');
    }
    final SellerProfile? seller = _findSeller(sellerId);
    if (seller == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final String entryId = 'entry-${++_idSeq}';
    _entries.add(
      LedgerEntry(
        id: entryId,
        shopId: 'shop-1',
        sellerId: sellerId,
        type: LedgerEntryType.payment,
        amountPaise: -amountPaise,
        paymentMethod: method,
        note: (note == null || note.trim().isEmpty)
            ? 'Payment via ${method.dbValue}'
            : note.trim(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return entryId;
  }

  @override
  Future<String> recordPrizePaidBySeller({
    required String sellerId,
    required String drawId,
    required int amountPaise,
    String? note,
  }) async {
    if (!LedgerMath.isValidPaymentAmountPaise(amountPaise)) {
      throw const PostgrestException(message: 'INVALID_AMOUNT');
    }
    final SellerProfile? seller = _findSeller(sellerId);
    if (seller == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final LotteryDraw? draw = _stockRepository.getDrawById(drawId);
    if (draw == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final String entryId = 'entry-${++_idSeq}';
    _entries.add(
      LedgerEntry(
        id: entryId,
        shopId: 'shop-1',
        sellerId: sellerId,
        drawId: drawId,
        type: LedgerEntryType.prizePaidBySeller,
        amountPaise: -amountPaise,
        note: (note == null || note.trim().isEmpty)
            ? 'Small prize paid by seller'
            : note.trim(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return entryId;
  }

  @override
  Future<String> reverseLedgerEntry(String entryId) async {
    final int idx = _entries.indexWhere((LedgerEntry e) => e.id == entryId);
    if (idx == -1) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    final LedgerEntry target = _entries[idx];
    if (target.type != LedgerEntryType.payment &&
        target.type != LedgerEntryType.prizePaidBySeller &&
        target.type != LedgerEntryType.adjustment) {
      throw const PostgrestException(message: 'NOT_REVERSIBLE');
    }
    if (target.reversedEntryId != null) {
      throw const PostgrestException(message: 'ALREADY_REVERSED');
    }
    final bool alreadyReversed = _entries.any(
      (LedgerEntry e) => e.reversedEntryId == entryId,
    );
    if (alreadyReversed) {
      throw const PostgrestException(message: 'ALREADY_REVERSED');
    }

    final String reversalId = 'entry-${++_idSeq}';
    _entries.add(
      LedgerEntry(
        id: reversalId,
        shopId: target.shopId,
        sellerId: target.sellerId,
        drawId: target.drawId,
        type: LedgerEntryType.adjustment,
        amountPaise: -target.amountPaise,
        ticketCount: target.ticketCount,
        paymentMethod: target.paymentMethod,
        reversedEntryId: target.id,
        note: 'Reversal of ${target.type.dbValue}',
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return reversalId;
  }
}
