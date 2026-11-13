import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/result_entities.dart';

abstract class ResultsRepository {
  Future<List<DrawPrizeTier>> fetchPrizeTiers(String drawId);

  Future<List<DrawResultEntry>> fetchDrawResults(String drawId);

  Future<List<WinningTicket>> fetchWinsForDraw(
    String drawId, {
    int offset = 0,
    int limit = 200,
  });

  Future<List<WinningTicket>> fetchWinsForSeller(
    String sellerId, {
    int offset = 0,
    int limit = 200,
  });

  Future<DrawSummaryRecord?> fetchDrawSummary(String drawId);

  Future<int> countWithSellerTickets(String drawId);

  Future<int> saveDrawResultsAndCheck({
    required String drawId,
    required List<ResultEntryInput> entries,
    bool force = false,
  });

  Future<int> checkDraw({
    required String drawId,
    bool force = false,
  });

  Future<void> updateWinClaimStatus({
    required String winId,
    required WinClaimStatus status,
  });

  Future<void> closeDraw(String drawId);
}

class SupabaseResultsRepository implements ResultsRepository {
  SupabaseResultsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<DrawPrizeTier>> fetchPrizeTiers(String drawId) async {
    final List<dynamic> rows = await _client
        .from('draw_prize_tiers')
        .select()
        .eq('draw_id', drawId)
        .order('tier_order', ascending: true);

    return rows
        .map((dynamic e) => DrawPrizeTier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<DrawResultEntry>> fetchDrawResults(String drawId) async {
    final List<dynamic> rows = await _client
        .from('draw_results')
        .select()
        .eq('draw_id', drawId)
        .order('created_at', ascending: true);

    return rows
        .map((dynamic e) => DrawResultEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<WinningTicket>> fetchWinsForDraw(
    String drawId, {
    int offset = 0,
    int limit = 200,
  }) async {
    final List<dynamic> rows = await _client
        .from('wins')
        .select(
          '*, tickets!inner(series, number), '
          'draw_prize_tiers!inner(label, tier_order), '
          'sellers(name)',
        )
        .eq('draw_id', drawId)
        .order('prize_amount', ascending: false)
        .order('created_at', ascending: true)
        .range(offset, offset + limit - 1);

    return rows
        .map((dynamic e) => WinningTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<WinningTicket>> fetchWinsForSeller(
    String sellerId, {
    int offset = 0,
    int limit = 200,
  }) async {
    final List<dynamic> rows = await _client
        .from('wins')
        .select(
          '*, tickets!inner(series, number), '
          'draw_prize_tiers!inner(label, tier_order), '
          'sellers(name)',
        )
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows
        .map((dynamic e) => WinningTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DrawSummaryRecord?> fetchDrawSummary(String drawId) async {
    final List<dynamic> rows = await _client
        .from('draw_summaries')
        .select()
        .eq('draw_id', drawId)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }
    return DrawSummaryRecord.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<int> countWithSellerTickets(String drawId) async {
    final PostgrestResponse<dynamic> res = await _client
        .from('tickets')
        .select('id')
        .eq('draw_id', drawId)
        .eq('status', 'WITH_SELLER')
        .count(CountOption.exact);
    return res.count;
  }

  @override
  Future<int> saveDrawResultsAndCheck({
    required String drawId,
    required List<ResultEntryInput> entries,
    bool force = false,
  }) async {
    final dynamic res = await _client.rpc(
      'save_draw_results_and_check',
      params: <String, dynamic>{
        'p_draw_id': drawId,
        'p_entries': entries.map((ResultEntryInput e) => e.toJson()).toList(),
        'p_force': force,
      },
    );
    return (res as num).toInt();
  }

  @override
  Future<int> checkDraw({
    required String drawId,
    bool force = false,
  }) async {
    final dynamic res = await _client.rpc(
      'check_draw',
      params: <String, dynamic>{
        'p_draw_id': drawId,
        'p_force': force,
      },
    );
    return (res as num).toInt();
  }

  @override
  Future<void> updateWinClaimStatus({
    required String winId,
    required WinClaimStatus status,
  }) async {
    await _client.rpc(
      'update_win_claim_status',
      params: <String, dynamic>{
        'p_win_id': winId,
        'p_status': status.dbValue,
      },
    );
  }

  @override
  Future<void> closeDraw(String drawId) async {
    await _client.rpc(
      'close_draw',
      params: <String, dynamic>{
        'p_draw_id': drawId,
      },
    );
  }
}
