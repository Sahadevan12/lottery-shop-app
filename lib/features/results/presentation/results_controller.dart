import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_codecs.dart';
import '../../../core/cache/cached_fetch.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../stock/presentation/stock_controller.dart';
import '../data/results_repository.dart';
import '../domain/result_entities.dart';

final Provider<ResultsRepository> resultsRepositoryProvider =
    Provider<ResultsRepository>((Ref ref) {
  final SupabaseClient? client = SupabaseConfig.clientOrNull;
  if (client == null) {
    throw StateError(
      'SupabaseClient is not initialized. Pass --dart-define=SUPABASE_URL and SUPABASE_ANON_KEY, or override resultsRepositoryProvider in tests.',
    );
  }
  return SupabaseResultsRepository(client);
});

@immutable
class ResultsState {
  const ResultsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.selectedDrawId,
    this.tiersByDraw = const <String, List<DrawPrizeTier>>{},
    this.resultsByDraw = const <String, List<DrawResultEntry>>{},
    this.winsByDraw = const <String, List<WinningTicket>>{},
    this.winsBySeller = const <String, List<WinningTicket>>{},
    this.summariesByDraw = const <String, DrawSummaryRecord>{},
    this.lastError,
    this.cachedAt,
    this.isFromCache = false,
  });

  final bool isLoading;
  final bool isSubmitting;
  final String? selectedDrawId;
  final Map<String, List<DrawPrizeTier>> tiersByDraw;
  final Map<String, List<DrawResultEntry>> resultsByDraw;
  final Map<String, List<WinningTicket>> winsByDraw;
  final Map<String, List<WinningTicket>> winsBySeller;
  final Map<String, DrawSummaryRecord> summariesByDraw;
  final Object? lastError;
  final DateTime? cachedAt;
  final bool isFromCache;

  List<DrawPrizeTier> tiersFor(String drawId) =>
      tiersByDraw[drawId] ?? const <DrawPrizeTier>[];

  List<DrawResultEntry> resultsFor(String drawId) =>
      resultsByDraw[drawId] ?? const <DrawResultEntry>[];

  List<WinningTicket> winsFor(String drawId) =>
      winsByDraw[drawId] ?? const <WinningTicket>[];

  List<WinningTicket> winsForSeller(String sellerId) =>
      winsBySeller[sellerId] ?? const <WinningTicket>[];

  DrawSummaryRecord? summaryFor(String drawId) => summariesByDraw[drawId];

  ResultsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? selectedDrawId,
    Map<String, List<DrawPrizeTier>>? tiersByDraw,
    Map<String, List<DrawResultEntry>>? resultsByDraw,
    Map<String, List<WinningTicket>>? winsByDraw,
    Map<String, List<WinningTicket>>? winsBySeller,
    Map<String, DrawSummaryRecord>? summariesByDraw,
    Object? lastError,
    bool clearError = false,
    DateTime? cachedAt,
    bool clearCachedAt = false,
    bool? isFromCache,
  }) {
    return ResultsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      selectedDrawId: selectedDrawId ?? this.selectedDrawId,
      tiersByDraw: tiersByDraw ?? this.tiersByDraw,
      resultsByDraw: resultsByDraw ?? this.resultsByDraw,
      winsByDraw: winsByDraw ?? this.winsByDraw,
      winsBySeller: winsBySeller ?? this.winsBySeller,
      summariesByDraw: summariesByDraw ?? this.summariesByDraw,
      lastError: clearError ? null : (lastError ?? this.lastError),
      cachedAt: clearCachedAt ? null : (cachedAt ?? this.cachedAt),
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

final NotifierProvider<ResultsController, ResultsState>
    resultsControllerProvider =
    NotifierProvider<ResultsController, ResultsState>(ResultsController.new);

class ResultsController extends Notifier<ResultsState> {
  @override
  ResultsState build() => const ResultsState();

  Future<void> loadDraw(String drawId) async {
    state = state.copyWith(
      selectedDrawId: drawId,
      isLoading: true,
      clearError: true,
    );
    try {
      final ResultsRepository repo = ref.read(resultsRepositoryProvider);
      final CachedFetchResult<_DrawResultsPayload> res =
          await CachedFetch.run<_DrawResultsPayload>(
        ref: ref,
        cacheKey: 'results_$drawId',
        remoteFetch: () async {
          final List<DrawPrizeTier> tiers = await repo.fetchPrizeTiers(drawId);
          final List<DrawResultEntry> results =
              await repo.fetchDrawResults(drawId);
          final List<WinningTicket> wins = await repo.fetchWinsForDraw(drawId);
          final DrawSummaryRecord? summary =
              await repo.fetchDrawSummary(drawId);
          return _DrawResultsPayload(
            tiers: tiers,
            results: results,
            wins: wins,
            summary: summary,
          );
        },
        toJson: (_DrawResultsPayload p) => <String, dynamic>{
          'tiers': p.tiers.map(CacheCodecs.prizeTierToJson).toList(),
          'results': p.results.map(CacheCodecs.resultEntryToJson).toList(),
          'wins': p.wins.map(CacheCodecs.winningTicketToJson).toList(),
          'summary': p.summary != null
              ? CacheCodecs.drawSummaryToJson(p.summary!)
              : null,
        },
        fromJson: (Object raw) {
          final Map<String, dynamic> map =
              Map<String, dynamic>.from(raw as Map);
          final Object? rawSummary = map['summary'];
          return _DrawResultsPayload(
            tiers: (map['tiers'] as List<dynamic>? ?? <dynamic>[])
                .map((dynamic e) =>
                    DrawPrizeTier.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(growable: false),
            results: (map['results'] as List<dynamic>? ?? <dynamic>[])
                .map((dynamic e) => DrawResultEntry.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList(growable: false),
            wins: (map['wins'] as List<dynamic>? ?? <dynamic>[])
                .map((dynamic e) =>
                    WinningTicket.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(growable: false),
            summary: rawSummary == null
                ? null
                : DrawSummaryRecord.fromJson(
                    Map<String, dynamic>.from(rawSummary as Map),
                  ),
          );
        },
      );

      final _DrawResultsPayload data = res.data;
      final Map<String, DrawSummaryRecord> nextSummaries =
          Map<String, DrawSummaryRecord>.from(state.summariesByDraw);
      if (data.summary != null) {
        nextSummaries[drawId] = data.summary!;
      } else {
        nextSummaries.remove(drawId);
      }

      state = state.copyWith(
        isLoading: false,
        tiersByDraw: <String, List<DrawPrizeTier>>{
          ...state.tiersByDraw,
          drawId: data.tiers,
        },
        resultsByDraw: <String, List<DrawResultEntry>>{
          ...state.resultsByDraw,
          drawId: data.results,
        },
        winsByDraw: <String, List<WinningTicket>>{
          ...state.winsByDraw,
          drawId: data.wins,
        },
        summariesByDraw: nextSummaries,
        cachedAt: res.cachedAt,
        isFromCache: res.isFromCache,
      );
    } catch (err) {
      state = state.copyWith(isLoading: false, lastError: err);
    }
  }

  Future<void> loadSellerWins(String sellerId) async {
    try {
      final CachedFetchResult<List<WinningTicket>> res =
          await CachedFetch.run<List<WinningTicket>>(
        ref: ref,
        cacheKey: 'seller_wins_$sellerId',
        remoteFetch: () =>
            ref.read(resultsRepositoryProvider).fetchWinsForSeller(sellerId),
        toJson: (List<WinningTicket> list) =>
            list.map(CacheCodecs.winningTicketToJson).toList(),
        fromJson: (Object raw) => (raw as List<dynamic>)
            .map((dynamic e) =>
                WinningTicket.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
      );
      state = state.copyWith(
        winsBySeller: <String, List<WinningTicket>>{
          ...state.winsBySeller,
          sellerId: res.data,
        },
      );
    } catch (err) {
      state = state.copyWith(lastError: err);
    }
  }

  Future<int?> saveDrawResultsAndCheck({
    required String drawId,
    required List<ResultEntryInput> entries,
    bool force = false,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final int winCount = await ref
          .read(resultsRepositoryProvider)
          .saveDrawResultsAndCheck(
            drawId: drawId,
            entries: entries,
            force: force,
          );
      await ref.read(stockControllerProvider.notifier).loadInitialData();
      await loadDraw(drawId);
      state = state.copyWith(isSubmitting: false);
      return winCount;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, lastError: err);
      return null;
    }
  }

  Future<bool> updateWinClaimStatus({
    required String drawId,
    required String winId,
    required WinClaimStatus status,
    String? sellerId,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(resultsRepositoryProvider).updateWinClaimStatus(
            winId: winId,
            status: status,
          );
      await loadDraw(drawId);
      if (sellerId != null) {
        await loadSellerWins(sellerId);
      }
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, lastError: err);
      return false;
    }
  }

  Future<int> countWithSellerTickets(String drawId) {
    return ref.read(resultsRepositoryProvider).countWithSellerTickets(drawId);
  }

  Future<bool> closeDraw(String drawId) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(resultsRepositoryProvider).closeDraw(drawId);
      await ref.read(stockControllerProvider.notifier).loadInitialData();
      await loadDraw(drawId);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (err) {
      state = state.copyWith(isSubmitting: false, lastError: err);
      return false;
    }
  }
}

class _DrawResultsPayload {
  const _DrawResultsPayload({
    required this.tiers,
    required this.results,
    required this.wins,
    required this.summary,
  });

  final List<DrawPrizeTier> tiers;
  final List<DrawResultEntry> results;
  final List<WinningTicket> wins;
  final DrawSummaryRecord? summary;
}
