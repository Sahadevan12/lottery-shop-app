import 'package:decimal/decimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../../stock/domain/stock_entities.dart';
import '../domain/ledger_math.dart';
import '../domain/seller_entities.dart';

/// Repository interface for Sellers & Khata (§6.5, §7.2–7.4).
abstract interface class SellerRepository {
  Future<List<SellerSummary>> fetchSellersWithBalances();

  Future<SellerProfile> saveSeller({
    String? id,
    required String name,
    String? phone,
    String? area,
  });

  Future<SellerProfile> setSellerActive({
    required String sellerId,
    required bool isActive,
  });

  Future<void> deleteSeller(String sellerId);

  Future<List<LedgerEntry>> fetchSellerLedger(String sellerId);

  Future<List<TicketItem>> fetchSellerTickets(String sellerId);

  /// Calls `issue_tickets` RPC (§6.5, §7.2).
  Future<String> issueTickets({
    required String sellerId,
    required String drawId,
    required List<String> ticketIds,
  });

  /// Calls `return_tickets` RPC (§6.5, §7.3).
  Future<String> returnTickets({
    required String sellerId,
    required String drawId,
    required List<String> ticketIds,
  });

  /// Calls `record_payment` RPC (§6.5, §7.4).
  Future<String> recordPayment({
    required String sellerId,
    required int amountPaise,
    required PaymentMethod method,
    String? note,
  });

  /// Calls `record_prize_paid_by_seller` RPC (§7.4).
  Future<String> recordPrizePaidBySeller({
    required String sellerId,
    required String drawId,
    required int amountPaise,
    String? note,
  });

  /// Calls `reverse_ledger_entry` RPC (A.2).
  Future<String> reverseLedgerEntry(String entryId);
}

/// Production Supabase implementation of [SellerRepository].
class SupabaseSellerRepository implements SellerRepository {
  SupabaseSellerRepository(this._client);

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

  @override
  Future<List<SellerSummary>> fetchSellersWithBalances() async {
    final List<dynamic> sellerRows = await _client
        .from('sellers')
        .select()
        .order('created_at', ascending: true);

    final List<dynamic> balanceRows =
        await _client.rpc<List<dynamic>>('seller_balances');

    final List<dynamic> entrySellerRows =
        await _client.from('ledger_entries').select('seller_id');

    final Set<String> sellersWithEntries = <String>{
      for (final dynamic r in entrySellerRows)
        (r as Map<String, dynamic>)['seller_id'] as String,
    };

    final Map<String, Map<String, dynamic>> balancesById =
        <String, Map<String, dynamic>>{
      for (final dynamic r in balanceRows)
        (r as Map<String, dynamic>)['seller_id'] as String: r,
    };

    return sellerRows
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> row) {
      final SellerProfile profile = SellerProfile.fromJson(row);
      final Map<String, dynamic>? bal = balancesById[profile.id];
      final int balancePaise = bal == null
          ? 0
          : AppFormatters.parseNumericToPaise(bal['balance']);
      final int ticketsWithSeller =
          (bal?['tickets_with_seller'] as int?) ?? 0;
      final DateTime lastActivity = bal?['last_activity_at'] == null
          ? profile.createdAt
          : DateTime.parse(bal!['last_activity_at'] as String);

      return SellerSummary(
        seller: profile,
        balancePaise: balancePaise,
        ticketsWithSeller: ticketsWithSeller,
        hasLedgerHistory: sellersWithEntries.contains(profile.id),
        lastActivityAt: lastActivity,
      );
    }).toList();
  }

  @override
  Future<SellerProfile> saveSeller({
    String? id,
    required String name,
    String? phone,
    String? area,
  }) async {
    final String shopId = await _requireShopId();
    final Map<String, dynamic> payload = <String, dynamic>{
      'shop_id': shopId,
      'name': name.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      'area': (area == null || area.trim().isEmpty) ? null : area.trim(),
    };

    final Map<String, dynamic> row;
    if (id == null) {
      row = await _client.from('sellers').insert(payload).select().single();
    } else {
      row = await _client
          .from('sellers')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
    }
    return SellerProfile.fromJson(row);
  }

  @override
  Future<SellerProfile> setSellerActive({
    required String sellerId,
    required bool isActive,
  }) async {
    final Map<String, dynamic> row = await _client
        .from('sellers')
        .update(<String, dynamic>{'is_active': isActive})
        .eq('id', sellerId)
        .select()
        .single();
    return SellerProfile.fromJson(row);
  }

  @override
  Future<void> deleteSeller(String sellerId) async {
    await _client.from('sellers').delete().eq('id', sellerId);
  }

  @override
  Future<List<LedgerEntry>> fetchSellerLedger(String sellerId) async {
    final List<dynamic> rows = await _client
        .from('ledger_entries')
        .select()
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);

    final List<LedgerEntry> parsed = rows
        .cast<Map<String, dynamic>>()
        .map(LedgerEntry.fromJson)
        .toList();
    return LedgerMath.linkReversalPairs(parsed);
  }

  @override
  Future<List<TicketItem>> fetchSellerTickets(String sellerId) async {
    final List<dynamic> rows = await _client
        .from('tickets')
        .select()
        .eq('seller_id', sellerId)
        .order('series', ascending: true)
        .order('number', ascending: true);

    return rows
        .cast<Map<String, dynamic>>()
        .map(TicketItem.fromJson)
        .toList();
  }

  @override
  Future<String> issueTickets({
    required String sellerId,
    required String drawId,
    required List<String> ticketIds,
  }) async {
    final String entryId = await _client.rpc<String>(
      'issue_tickets',
      params: <String, dynamic>{
        'p_seller_id': sellerId,
        'p_draw_id': drawId,
        'p_ticket_ids': ticketIds,
      },
    );
    return entryId;
  }

  @override
  Future<String> returnTickets({
    required String sellerId,
    required String drawId,
    required List<String> ticketIds,
  }) async {
    final String entryId = await _client.rpc<String>(
      'return_tickets',
      params: <String, dynamic>{
        'p_seller_id': sellerId,
        'p_draw_id': drawId,
        'p_ticket_ids': ticketIds,
      },
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
    final String entryId = await _client.rpc<String>(
      'record_payment',
      params: <String, dynamic>{
        'p_seller_id': sellerId,
        'p_amount': _paiseToNumeric(amountPaise),
        'p_payment_method': method.dbValue,
        'p_note': note,
      },
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
    final String entryId = await _client.rpc<String>(
      'record_prize_paid_by_seller',
      params: <String, dynamic>{
        'p_seller_id': sellerId,
        'p_draw_id': drawId,
        'p_amount': _paiseToNumeric(amountPaise),
        'p_note': note,
      },
    );
    return entryId;
  }

  @override
  Future<String> reverseLedgerEntry(String entryId) async {
    final String reversalId = await _client.rpc<String>(
      'reverse_ledger_entry',
      params: <String, dynamic>{'p_entry_id': entryId},
    );
    return reversalId;
  }
}
