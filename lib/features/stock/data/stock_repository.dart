import 'package:decimal/decimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../domain/stock_entities.dart';

/// Repository interface for Lotteries, Prize Templates, Draws, Stock Batches, and Tickets (§6.5, §7.1).
abstract interface class StockRepository {
  Future<List<LotteryItem>> fetchLotteries();

  Future<LotteryItem> saveLottery({
    String? id,
    required String name,
    String? code,
    int? defaultWeekday,
    required int defaultTicketPricePaise,
    required bool isBumper,
  });

  Future<List<PrizeTemplate>> fetchPrizeTemplates();

  Future<PrizeTemplate> savePrizeTemplate({
    String? id,
    required String name,
    required List<PrizeTemplateTier> tiers,
  });

  Future<List<LotteryDraw>> fetchDraws();

  /// Calls `create_draw` RPC (§6.5).
  Future<String> createDraw({
    required String lotteryId,
    required DateTime drawDate,
    String? drawNumber,
    required int ticketPricePaise,
    String? templateId,
  });

  Future<List<StockBatch>> fetchBatchesForDraw(String drawId);

  /// Calls `create_stock_batch` RPC (§6.5).
  Future<String> createStockBatch({
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
    int? costPerTicketPaise,
  });

  /// Calls `delete_stock_batch` RPC (allowed only when all tickets are IN_STOCK).
  Future<void> deleteStockBatch(String batchId);

  Future<List<TicketItem>> fetchTicketsForBatch(
    String batchId, {
    TicketStatus? status,
    String? searchNumber,
    int offset = 0,
    int limit = 200,
  });

  /// Calls `preview_tickets` RPC (returns total count + contiguous ranges without 1000-row cap).
  Future<TicketRangePreview> previewTickets({
    required String drawId,
    required String mode, // 'COUNT' | 'RANGE'
    int? count,
    String? series,
    String? startNumber,
    String? endNumber,
    TicketStatus status = TicketStatus.inStock,
    String? sellerId,
  });

  /// Calls `mark_counter_sold` RPC (range-based IN_STOCK -> SOLD_COUNTER).
  Future<int> markCounterSold({
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
  });

  /// Calls `unmark_counter_sold` RPC (range-based SOLD_COUNTER -> IN_STOCK).
  Future<int> unmarkCounterSold({
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
  });
}

/// Production Supabase implementation of [StockRepository].
class SupabaseStockRepository implements StockRepository {
  SupabaseStockRepository(this._client);

  final SupabaseClient _client;

  Future<String> _requireShopId() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const PostgrestException(message: 'UNAUTHORIZED');
    }
    final Map<String, dynamic>? row = await _client
        .from('shops')
        .select('id')
        .eq('owner_id', uid)
        .maybeSingle();
    if (row == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    return row['id'] as String;
  }

  static String _paiseToNumeric(int paise) {
    final Decimal dec =
        (Decimal.fromInt(paise) / Decimal.fromInt(100)).toDecimal();
    return dec.toStringAsFixed(2);
  }

  static String _formatDateIso(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<List<LotteryItem>> fetchLotteries() async {
    final List<dynamic> rows = await _client
        .from('lotteries')
        .select()
        .order('is_bumper', ascending: true)
        .order('default_weekday', ascending: true);
    return rows
        .cast<Map<String, dynamic>>()
        .map(LotteryItem.fromJson)
        .toList();
  }

  @override
  Future<LotteryItem> saveLottery({
    String? id,
    required String name,
    String? code,
    int? defaultWeekday,
    required int defaultTicketPricePaise,
    required bool isBumper,
  }) async {
    final String shopId = await _requireShopId();
    final Map<String, dynamic> payload = <String, dynamic>{
      'shop_id': shopId,
      'name': name.trim(),
      'code': (code == null || code.trim().isEmpty)
          ? null
          : code.trim().toUpperCase(),
      'default_weekday': isBumper ? null : defaultWeekday,
      'default_ticket_price': _paiseToNumeric(defaultTicketPricePaise),
      'is_bumper': isBumper,
    };

    final Map<String, dynamic> row;
    if (id == null) {
      row = await _client.from('lotteries').insert(payload).select().single();
    } else {
      row = await _client
          .from('lotteries')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
    }
    return LotteryItem.fromJson(row);
  }

  @override
  Future<List<PrizeTemplate>> fetchPrizeTemplates() async {
    final List<dynamic> rows = await _client
        .from('prize_templates')
        .select('id, shop_id, name, prize_template_tiers(*)');
    return rows.cast<Map<String, dynamic>>().map((Map<String, dynamic> r) {
      final List<dynamic> rawTiers =
          (r['prize_template_tiers'] as List<dynamic>?) ?? <dynamic>[];
      final List<PrizeTemplateTier> tiers = rawTiers
          .cast<Map<String, dynamic>>()
          .map(PrizeTemplateTier.fromJson)
          .toList()
        ..sort((PrizeTemplateTier a, PrizeTemplateTier b) =>
            a.tierOrder.compareTo(b.tierOrder));
      return PrizeTemplate(
        id: r['id'] as String,
        shopId: r['shop_id'] as String,
        name: r['name'] as String,
        tiers: tiers,
      );
    }).toList();
  }

  @override
  Future<PrizeTemplate> savePrizeTemplate({
    String? id,
    required String name,
    required List<PrizeTemplateTier> tiers,
  }) async {
    final String shopId = await _requireShopId();
    final String templateId;
    if (id == null) {
      final Map<String, dynamic> row = await _client
          .from('prize_templates')
          .insert(<String, dynamic>{'shop_id': shopId, 'name': name.trim()})
          .select()
          .single();
      templateId = row['id'] as String;
    } else {
      templateId = id;
      await _client
          .from('prize_templates')
          .update(<String, dynamic>{'name': name.trim()}).eq('id', templateId);
      await _client
          .from('prize_template_tiers')
          .delete()
          .eq('template_id', templateId);
    }

    if (tiers.isNotEmpty) {
      final List<Map<String, dynamic>> tierRows =
          tiers.asMap().entries.map((MapEntry<int, PrizeTemplateTier> entry) {
        final PrizeTemplateTier t = entry.value;
        return <String, dynamic>{
          'template_id': templateId,
          'tier_order': entry.key + 1,
          'label': t.label.trim(),
          'amount': _paiseToNumeric(t.amountPaise),
          'match_type': t.matchType.dbValue,
        };
      }).toList();
      await _client.from('prize_template_tiers').insert(tierRows);
    }

    final List<PrizeTemplate> updated = await fetchPrizeTemplates();
    return updated.firstWhere((PrizeTemplate t) => t.id == templateId);
  }

  @override
  Future<List<LotteryDraw>> fetchDraws() async {
    final List<dynamic> rows = await _client
        .from('draws')
        .select('*, lotteries(name, code, is_bumper)')
        .order('draw_date', ascending: true);

    return rows.cast<Map<String, dynamic>>().map((Map<String, dynamic> r) {
      final Map<String, dynamic>? lottery =
          r['lotteries'] as Map<String, dynamic>?;
      return LotteryDraw(
        id: r['id'] as String,
        shopId: r['shop_id'] as String,
        lotteryId: r['lottery_id'] as String,
        lotteryName: (lottery?['name'] as String?) ?? '',
        lotteryCode: lottery?['code'] as String?,
        drawNumber: r['draw_number'] as String?,
        drawDate: DateTime.parse(r['draw_date'] as String),
        drawTime: (r['draw_time'] as String?) ?? '15:00',
        ticketPricePaise: AppFormatters.parseNumericToPaise(r['ticket_price']),
        status: DrawStatus.fromDb(r['status'] as String),
        isBumper: (lottery?['is_bumper'] as bool?) ?? false,
      );
    }).toList();
  }

  @override
  Future<String> createDraw({
    required String lotteryId,
    required DateTime drawDate,
    String? drawNumber,
    required int ticketPricePaise,
    String? templateId,
  }) async {
    final String drawId = await _client.rpc<String>(
      'create_draw',
      params: <String, dynamic>{
        'p_lottery_id': lotteryId,
        'p_draw_date': _formatDateIso(drawDate),
        'p_draw_number': drawNumber,
        'p_ticket_price': _paiseToNumeric(ticketPricePaise),
        'p_template_id': templateId,
      },
    );
    return drawId;
  }

  @override
  Future<List<StockBatch>> fetchBatchesForDraw(String drawId) async {
    final List<dynamic> rows = await _client.rpc<List<dynamic>>(
      'get_batches_for_draw',
      params: <String, dynamic>{'p_draw_id': drawId},
    );

    return rows.cast<Map<String, dynamic>>().map((Map<String, dynamic> r) {
      return StockBatch(
        id: r['id'] as String,
        shopId: r['shop_id'] as String,
        drawId: r['draw_id'] as String,
        series: (r['series'] as String).trim(),
        startNumber: (r['start_number'] as String).trim(),
        endNumber: (r['end_number'] as String).trim(),
        quantity: r['quantity'] as int,
        costPerTicketPaise: r['cost_per_ticket'] == null
            ? null
            : AppFormatters.parseNumericToPaise(r['cost_per_ticket']),
        inStockCount: (r['in_stock_count'] as int?) ?? 0,
        withSellerCount: (r['with_seller_count'] as int?) ?? 0,
        soldCount: (r['sold_count'] as int?) ?? 0,
        returnedCount: (r['returned_count'] as int?) ?? 0,
      );
    }).toList();
  }

  @override
  Future<String> createStockBatch({
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
    int? costPerTicketPaise,
  }) async {
    final String batchId = await _client.rpc<String>(
      'create_stock_batch',
      params: <String, dynamic>{
        'p_draw_id': drawId,
        'p_series': series.trim().toUpperCase(),
        'p_start_number': startNumber.trim(),
        'p_end_number': endNumber.trim(),
        'p_cost_per_ticket': costPerTicketPaise == null
            ? null
            : _paiseToNumeric(costPerTicketPaise),
      },
    );
    return batchId;
  }

  @override
  Future<void> deleteStockBatch(String batchId) async {
    await _client.rpc<void>(
      'delete_stock_batch',
      params: <String, dynamic>{'p_batch_id': batchId},
    );
  }

  @override
  Future<List<TicketItem>> fetchTicketsForBatch(
    String batchId, {
    TicketStatus? status,
    String? searchNumber,
    int offset = 0,
    int limit = 200,
  }) async {
    dynamic query = _client.from('tickets').select().eq('batch_id', batchId);

    if (status != null) {
      if (status == TicketStatus.soldCounter) {
        query = query.inFilter('status', <String>[
          TicketStatus.soldCounter.dbValue,
          TicketStatus.soldBySeller.dbValue,
        ]);
      } else {
        query = query.eq('status', status.dbValue);
      }
    }

    final String cleanSearch = (searchNumber ?? '').trim();
    if (cleanSearch.isNotEmpty) {
      query = query.ilike('number', '%$cleanSearch%');
    }

    final List<dynamic> rows = await query
        .order('number', ascending: true)
        .range(offset, offset + limit - 1);

    return rows
        .cast<Map<String, dynamic>>()
        .map(TicketItem.fromJson)
        .toList();
  }

  @override
  Future<TicketRangePreview> previewTickets({
    required String drawId,
    required String mode,
    int? count,
    String? series,
    String? startNumber,
    String? endNumber,
    TicketStatus status = TicketStatus.inStock,
    String? sellerId,
  }) async {
    final List<dynamic> rows = await _client.rpc<List<dynamic>>(
      'preview_tickets',
      params: <String, dynamic>{
        'p_draw_id': drawId,
        'p_mode': mode,
        'p_count': count,
        'p_series': series,
        'p_start_number': startNumber,
        'p_end_number': endNumber,
        'p_status': status.dbValue,
        'p_seller_id': sellerId,
      },
    );
    if (rows.isEmpty) {
      return const TicketRangePreview();
    }
    final Map<String, dynamic> row = rows.first as Map<String, dynamic>;
    return TicketRangePreview(
      totalCount: (row['total_count'] as int?) ?? 0,
      rangesSummary: row['ranges_summary'] as String?,
    );
  }

  @override
  Future<int> markCounterSold({
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
  }) async {
    final int count = await _client.rpc<int>(
      'mark_counter_sold',
      params: <String, dynamic>{
        'p_draw_id': drawId,
        'p_series': series.trim().toUpperCase(),
        'p_start_number': startNumber.trim(),
        'p_end_number': endNumber.trim(),
      },
    );
    return count;
  }

  @override
  Future<int> unmarkCounterSold({
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
  }) async {
    final int count = await _client.rpc<int>(
      'unmark_counter_sold',
      params: <String, dynamic>{
        'p_draw_id': drawId,
        'p_series': series.trim().toUpperCase(),
        'p_start_number': startNumber.trim(),
        'p_end_number': endNumber.trim(),
      },
    );
    return count;
  }
}
