import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../stock/domain/stock_entities.dart';
import '../../stock/presentation/stock_controller.dart';
import '../data/seller_repository.dart';
import '../domain/ledger_math.dart';
import '../domain/seller_entities.dart';

@immutable
class SellersState {
  const SellersState({
    this.sellers = const <SellerSummary>[],
    this.searchQuery = '',
    this.sortMode = SellerSortMode.highestDue,
    this.showInactive = false,
    this.ledgerBySeller = const <String, List<LedgerEntry>>{},
    this.ticketsBySeller = const <String, List<TicketItem>>{},
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.lastCreatedEntryId,
  });

  final List<SellerSummary> sellers;
  final String searchQuery;
  final SellerSortMode sortMode;
  final bool showInactive;
  final Map<String, List<LedgerEntry>> ledgerBySeller;
  final Map<String, List<TicketItem>> ticketsBySeller;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? lastCreatedEntryId;

  List<SellerSummary> get visibleSellers => LedgerMath.filterAndSortSellers(
        sellers: sellers,
        searchQuery: searchQuery,
        sortMode: sortMode,
        showInactive: showInactive,
      );

  List<SellerSummary> get activeSellers => sellers
      .where((SellerSummary s) => s.seller.isActive)
      .toList(growable: false);

  int get totalDueFromSellersPaise {
    int total = 0;
    for (final SellerSummary s in sellers) {
      if (s.balancePaise > 0) {
        total += s.balancePaise;
      }
    }
    return total;
  }

  List<SellerSummary> get topDueSellers {
    final List<SellerSummary> positive = sellers
        .where((SellerSummary s) => s.balancePaise > 0)
        .toList()
      ..sort((SellerSummary a, SellerSummary b) =>
          b.balancePaise.compareTo(a.balancePaise));
    return positive.take(3).toList();
  }

  SellerSummary? summaryFor(String sellerId) {
    for (final SellerSummary s in sellers) {
      if (s.seller.id == sellerId) {
        return s;
      }
    }
    return null;
  }

  List<LedgerEntry> ledgerFor(String sellerId) =>
      ledgerBySeller[sellerId] ?? const <LedgerEntry>[];

  List<TicketItem> ticketsFor(String sellerId) =>
      ticketsBySeller[sellerId] ?? const <TicketItem>[];

  SellersState copyWith({
    List<SellerSummary>? sellers,
    String? searchQuery,
    SellerSortMode? sortMode,
    bool? showInactive,
    Map<String, List<LedgerEntry>>? ledgerBySeller,
    Map<String, List<TicketItem>>? ticketsBySeller,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? lastCreatedEntryId,
  }) {
    return SellersState(
      sellers: sellers ?? this.sellers,
      searchQuery: searchQuery ?? this.searchQuery,
      sortMode: sortMode ?? this.sortMode,
      showInactive: showInactive ?? this.showInactive,
      ledgerBySeller: ledgerBySeller ?? this.ledgerBySeller,
      ticketsBySeller: ticketsBySeller ?? this.ticketsBySeller,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastCreatedEntryId: lastCreatedEntryId ?? this.lastCreatedEntryId,
    );
  }
}

final Provider<SellerRepository> sellerRepositoryProvider =
    Provider<SellerRepository>((Ref ref) {
  final SupabaseClient? client = SupabaseConfig.clientOrNull;
  if (client == null) {
    throw StateError(
      'SupabaseClient is not initialized. Pass --dart-define=SUPABASE_URL and SUPABASE_ANON_KEY, or override sellerRepositoryProvider in tests.',
    );
  }
  return SupabaseSellerRepository(client);
});

final NotifierProvider<SellersController, SellersState>
    sellersControllerProvider =
    NotifierProvider<SellersController, SellersState>(SellersController.new);

class SellersController extends Notifier<SellersState> {
  @override
  SellersState build() {
    Future<void>.microtask(loadSellers);
    return const SellersState(isLoading: true);
  }

  Future<void> loadSellers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final List<SellerSummary> list = await repo.fetchSellersWithBalances();
      state = state.copyWith(sellers: list, isLoading: false);
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: err.toString(),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortMode(SellerSortMode mode) {
    state = state.copyWith(sortMode: mode);
  }

  void toggleShowInactive(bool value) {
    state = state.copyWith(showInactive: value);
  }

  Future<void> loadSellerDetail(String sellerId) async {
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final List<SellerSummary> summaries =
          await repo.fetchSellersWithBalances();
      final List<LedgerEntry> ledger = await repo.fetchSellerLedger(sellerId);
      final List<TicketItem> tickets = await repo.fetchSellerTickets(sellerId);

      state = state.copyWith(
        sellers: summaries,
        ledgerBySeller: <String, List<LedgerEntry>>{
          ...state.ledgerBySeller,
          sellerId: ledger,
        },
        ticketsBySeller: <String, List<TicketItem>>{
          ...state.ticketsBySeller,
          sellerId: tickets,
        },
        clearError: true,
      );
    } catch (err) {
      state = state.copyWith(errorMessage: err.toString());
    }
  }

  Future<bool> saveSeller({
    String? id,
    required String name,
    String? phone,
    String? area,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      await repo.saveSeller(id: id, name: name, phone: phone, area: area);
      final List<SellerSummary> list = await repo.fetchSellersWithBalances();
      state = state.copyWith(sellers: list, isSubmitting: false);
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<bool> setSellerActive({
    required String sellerId,
    required bool isActive,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      await repo.setSellerActive(sellerId: sellerId, isActive: isActive);
      final List<SellerSummary> list = await repo.fetchSellersWithBalances();
      state = state.copyWith(sellers: list, isSubmitting: false);
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<bool> deleteSeller(String sellerId) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      await repo.deleteSeller(sellerId);
      final List<SellerSummary> list = await repo.fetchSellersWithBalances();
      state = state.copyWith(sellers: list, isSubmitting: false);
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<bool> issueTickets({
    required String sellerId,
    required String drawId,
    required List<String> ticketIds,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final String entryId = await repo.issueTickets(
        sellerId: sellerId,
        drawId: drawId,
        ticketIds: ticketIds,
      );
      await loadSellerDetail(sellerId);
      await ref.read(stockControllerProvider.notifier).selectDraw(drawId);
      state = state.copyWith(
        isSubmitting: false,
        lastCreatedEntryId: entryId,
      );
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<bool> returnTickets({
    required String sellerId,
    required String drawId,
    required List<String> ticketIds,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final String entryId = await repo.returnTickets(
        sellerId: sellerId,
        drawId: drawId,
        ticketIds: ticketIds,
      );
      await loadSellerDetail(sellerId);
      await ref.read(stockControllerProvider.notifier).selectDraw(drawId);
      state = state.copyWith(
        isSubmitting: false,
        lastCreatedEntryId: entryId,
      );
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<bool> issueTicketsByCount({
    required String sellerId,
    required String drawId,
    required int count,
    String? series,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final String entryId = await repo.issueTicketsByCount(
        sellerId: sellerId,
        drawId: drawId,
        count: count,
        series: series,
      );
      await loadSellerDetail(sellerId);
      await ref.read(stockControllerProvider.notifier).selectDraw(drawId);
      state = state.copyWith(
        isSubmitting: false,
        lastCreatedEntryId: entryId,
      );
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<bool> issueTicketsByRange({
    required String sellerId,
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final String entryId = await repo.issueTicketsByRange(
        sellerId: sellerId,
        drawId: drawId,
        series: series,
        startNumber: startNumber,
        endNumber: endNumber,
      );
      await loadSellerDetail(sellerId);
      await ref.read(stockControllerProvider.notifier).selectDraw(drawId);
      state = state.copyWith(
        isSubmitting: false,
        lastCreatedEntryId: entryId,
      );
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<bool> returnTicketsByRange({
    required String sellerId,
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final String entryId = await repo.returnTicketsByRange(
        sellerId: sellerId,
        drawId: drawId,
        series: series,
        startNumber: startNumber,
        endNumber: endNumber,
      );
      await loadSellerDetail(sellerId);
      await ref.read(stockControllerProvider.notifier).selectDraw(drawId);
      state = state.copyWith(
        isSubmitting: false,
        lastCreatedEntryId: entryId,
      );
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<SellerBalanceBreakdown> fetchSellerBalanceBreakdown(
    String sellerId,
  ) {
    return ref.read(sellerRepositoryProvider).fetchSellerBalanceBreakdown(
          sellerId,
        );
  }

  Future<String?> recordPayment({
    required String sellerId,
    required int amountPaise,
    required PaymentMethod method,
    String? note,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final String entryId = await repo.recordPayment(
        sellerId: sellerId,
        amountPaise: amountPaise,
        method: method,
        note: note,
      );
      await loadSellerDetail(sellerId);
      state = state.copyWith(
        isSubmitting: false,
        lastCreatedEntryId: entryId,
      );
      return entryId;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return null;
    }
  }

  Future<String?> recordPrizePaidBySeller({
    required String sellerId,
    required String drawId,
    required int amountPaise,
    String? note,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      final String entryId = await repo.recordPrizePaidBySeller(
        sellerId: sellerId,
        drawId: drawId,
        amountPaise: amountPaise,
        note: note,
      );
      await loadSellerDetail(sellerId);
      state = state.copyWith(
        isSubmitting: false,
        lastCreatedEntryId: entryId,
      );
      return entryId;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return null;
    }
  }

  Future<bool> reverseLedgerEntry({
    required String sellerId,
    required String entryId,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final SellerRepository repo = ref.read(sellerRepositoryProvider);
      await repo.reverseLedgerEntry(entryId);
      await loadSellerDetail(sellerId);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }
}
