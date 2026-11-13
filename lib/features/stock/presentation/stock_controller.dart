import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../settings/presentation/app_preferences_controller.dart';
import '../data/stock_repository.dart';
import '../domain/stock_entities.dart';
import '../domain/stock_range_logic.dart';

@immutable
class StockState {
  const StockState({
    this.lotteries = const <LotteryItem>[],
    this.templates = const <PrizeTemplate>[],
    this.draws = const <LotteryDraw>[],
    this.selectedDrawId,
    this.batchesByDraw = const <String, List<StockBatch>>{},
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.lastCostPerTicketPaise = 3500,
  });

  final List<LotteryItem> lotteries;
  final List<PrizeTemplate> templates;
  final List<LotteryDraw> draws;
  final String? selectedDrawId;
  final Map<String, List<StockBatch>> batchesByDraw;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final int lastCostPerTicketPaise;

  LotteryDraw? get selectedDraw {
    if (selectedDrawId == null) {
      return null;
    }
    for (final LotteryDraw d in draws) {
      if (d.id == selectedDrawId) {
        return d;
      }
    }
    return null;
  }

  LotteryDraw? drawForDate(DateTime date) {
    for (final LotteryDraw d in draws) {
      if (d.isSameDay(date)) {
        return d;
      }
    }
    return null;
  }

  List<StockBatch> get selectedDrawBatches {
    if (selectedDrawId == null) {
      return const <StockBatch>[];
    }
    return batchesByDraw[selectedDrawId!] ?? const <StockBatch>[];
  }

  DrawStockSummary get selectedDrawSummary =>
      StockRangeLogic.summarizeBatches(selectedDrawBatches);

  DrawStockSummary summaryForDate(DateTime date) {
    final LotteryDraw? d = drawForDate(date);
    if (d == null) {
      return const DrawStockSummary();
    }
    final List<StockBatch> batches =
        batchesByDraw[d.id] ?? const <StockBatch>[];
    return StockRangeLogic.summarizeBatches(batches);
  }

  StockState copyWith({
    List<LotteryItem>? lotteries,
    List<PrizeTemplate>? templates,
    List<LotteryDraw>? draws,
    String? selectedDrawId,
    bool clearSelectedDraw = false,
    Map<String, List<StockBatch>>? batchesByDraw,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    int? lastCostPerTicketPaise,
  }) {
    return StockState(
      lotteries: lotteries ?? this.lotteries,
      templates: templates ?? this.templates,
      draws: draws ?? this.draws,
      selectedDrawId:
          clearSelectedDraw ? null : (selectedDrawId ?? this.selectedDrawId),
      batchesByDraw: batchesByDraw ?? this.batchesByDraw,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastCostPerTicketPaise:
          lastCostPerTicketPaise ?? this.lastCostPerTicketPaise,
    );
  }
}

final Provider<StockRepository> stockRepositoryProvider =
    Provider<StockRepository>((Ref ref) {
  final SupabaseClient? client = SupabaseConfig.clientOrNull;
  if (client == null) {
    throw StateError(
      'SupabaseClient is not initialized. Pass --dart-define=SUPABASE_URL and SUPABASE_ANON_KEY, or override stockRepositoryProvider in tests.',
    );
  }
  return SupabaseStockRepository(client);
});

final NotifierProvider<StockController, StockState> stockControllerProvider =
    NotifierProvider<StockController, StockState>(StockController.new);

class StockController extends Notifier<StockState> {
  static const String _keyLastCostPaise = 'pref_last_cost_per_ticket_paise';

  @override
  StockState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final int lastCost = prefs?.getInt(_keyLastCostPaise) ?? 3500;
    Future<void>.microtask(loadInitialData);
    return StockState(
      isLoading: true,
      lastCostPerTicketPaise: lastCost,
    );
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      final List<LotteryItem> lotteries = await repo.fetchLotteries();
      final List<PrizeTemplate> templates = await repo.fetchPrizeTemplates();
      final List<LotteryDraw> draws = await repo.fetchDraws();

      final DateTime today = DateTime.now();
      LotteryDraw? initialDraw;
      for (final LotteryDraw d in draws) {
        if (d.isSameDay(today)) {
          initialDraw = d;
          break;
        }
      }
      initialDraw ??= draws.isNotEmpty ? draws.first : null;

      final Map<String, List<StockBatch>> batchesMap =
          <String, List<StockBatch>>{...state.batchesByDraw};
      if (initialDraw != null) {
        batchesMap[initialDraw.id] =
            await repo.fetchBatchesForDraw(initialDraw.id);
      }

      state = state.copyWith(
        lotteries: lotteries,
        templates: templates,
        draws: draws,
        selectedDrawId: initialDraw?.id,
        clearSelectedDraw: initialDraw == null,
        batchesByDraw: batchesMap,
        isLoading: false,
      );
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: err.toString(),
      );
    }
  }

  Future<void> selectDraw(String? drawId) async {
    if (drawId == null) {
      state = state.copyWith(clearSelectedDraw: true);
      return;
    }
    state = state.copyWith(selectedDrawId: drawId, clearError: true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      final List<StockBatch> batches = await repo.fetchBatchesForDraw(drawId);
      state = state.copyWith(
        batchesByDraw: <String, List<StockBatch>>{
          ...state.batchesByDraw,
          drawId: batches,
        },
      );
    } catch (err) {
      state = state.copyWith(errorMessage: err.toString());
    }
  }

  Future<LotteryDraw?> createDraw({
    required String lotteryId,
    required DateTime drawDate,
    String? drawNumber,
    required int ticketPricePaise,
    String? templateId,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      final String drawId = await repo.createDraw(
        lotteryId: lotteryId,
        drawDate: drawDate,
        drawNumber: drawNumber,
        ticketPricePaise: ticketPricePaise,
        templateId: templateId,
      );
      final List<LotteryDraw> draws = await repo.fetchDraws();
      final List<StockBatch> batches = await repo.fetchBatchesForDraw(drawId);
      state = state.copyWith(
        draws: draws,
        selectedDrawId: drawId,
        batchesByDraw: <String, List<StockBatch>>{
          ...state.batchesByDraw,
          drawId: batches,
        },
        isSubmitting: false,
      );
      return state.selectedDraw;
    } catch (err) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: err.toString(),
      );
      return null;
    }
  }

  Future<bool> addStockBatch({
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
    int? costPerTicketPaise,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      await repo.createStockBatch(
        drawId: drawId,
        series: series,
        startNumber: startNumber,
        endNumber: endNumber,
        costPerTicketPaise: costPerTicketPaise,
      );
      if (costPerTicketPaise != null && costPerTicketPaise > 0) {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs?.setInt(_keyLastCostPaise, costPerTicketPaise);
      }
      final List<StockBatch> batches = await repo.fetchBatchesForDraw(drawId);
      state = state.copyWith(
        selectedDrawId: drawId,
        batchesByDraw: <String, List<StockBatch>>{
          ...state.batchesByDraw,
          drawId: batches,
        },
        lastCostPerTicketPaise:
            costPerTicketPaise ?? state.lastCostPerTicketPaise,
        isSubmitting: false,
      );
      return true;
    } catch (err) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: err.toString(),
      );
      return false;
    }
  }

  Future<bool> deleteStockBatch({
    required String drawId,
    required String batchId,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      await repo.deleteStockBatch(batchId);
      final List<StockBatch> batches = await repo.fetchBatchesForDraw(drawId);
      state = state.copyWith(
        batchesByDraw: <String, List<StockBatch>>{
          ...state.batchesByDraw,
          drawId: batches,
        },
        isSubmitting: false,
      );
      return true;
    } catch (err) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: err.toString(),
      );
      return false;
    }
  }

  Future<bool> saveLottery({
    String? id,
    required String name,
    String? code,
    int? defaultWeekday,
    required int defaultTicketPricePaise,
    required bool isBumper,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      await repo.saveLottery(
        id: id,
        name: name,
        code: code,
        defaultWeekday: defaultWeekday,
        defaultTicketPricePaise: defaultTicketPricePaise,
        isBumper: isBumper,
      );
      final List<LotteryItem> lotteries = await repo.fetchLotteries();
      state = state.copyWith(lotteries: lotteries, isSubmitting: false);
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }

  Future<bool> savePrizeTemplate({
    String? id,
    required String name,
    required List<PrizeTemplateTier> tiers,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      await repo.savePrizeTemplate(id: id, name: name, tiers: tiers);
      final List<PrizeTemplate> templates = await repo.fetchPrizeTemplates();
      state = state.copyWith(templates: templates, isSubmitting: false);
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, errorMessage: err.toString());
      return false;
    }
  }
}
