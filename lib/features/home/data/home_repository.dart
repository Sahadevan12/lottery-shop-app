import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-computed dashboard snapshot returned by the `dashboard_today()` RPC.
class DashboardTodayData {
  const DashboardTodayData({
    required this.todayDate,
    required this.drawsCount,
    required this.inStockCount,
    required this.withSellerCount,
    required this.soldCounterCount,
    required this.soldSellerCount,
    required this.returnedCount,
    required this.totalTickets,
    required this.todayWinsCount,
    required this.todayPrizesTotal,
    required this.unclaimedWinsCount,
    required this.totalDueFromSellers,
    required this.toRecoverFromOffice,
  });

  final DateTime todayDate;
  final int drawsCount;
  final int inStockCount;
  final int withSellerCount;
  final int soldCounterCount;
  final int soldSellerCount;
  final int returnedCount;
  final int totalTickets;
  final int todayWinsCount;
  final double todayPrizesTotal;
  final int unclaimedWinsCount;
  final double totalDueFromSellers;
  final double toRecoverFromOffice;

  int get soldCount => soldCounterCount + soldSellerCount;

  factory DashboardTodayData.fromJson(Map<String, dynamic> json) {
    return DashboardTodayData(
      todayDate: DateTime.tryParse(json['today_date']?.toString() ?? '') ??
          DateTime.now(),
      drawsCount: (json['draws_count'] as num?)?.toInt() ?? 0,
      inStockCount: (json['in_stock_count'] as num?)?.toInt() ?? 0,
      withSellerCount: (json['with_seller_count'] as num?)?.toInt() ?? 0,
      soldCounterCount: (json['sold_counter_count'] as num?)?.toInt() ?? 0,
      soldSellerCount: (json['sold_seller_count'] as num?)?.toInt() ?? 0,
      returnedCount: (json['returned_count'] as num?)?.toInt() ?? 0,
      totalTickets: (json['total_tickets'] as num?)?.toInt() ?? 0,
      todayWinsCount: (json['today_wins_count'] as num?)?.toInt() ?? 0,
      todayPrizesTotal: (json['today_prizes_total'] as num?)?.toDouble() ?? 0,
      unclaimedWinsCount: (json['unclaimed_wins_count'] as num?)?.toInt() ?? 0,
      totalDueFromSellers:
          (json['total_due_from_sellers'] as num?)?.toDouble() ?? 0,
      toRecoverFromOffice:
          (json['to_recover_from_office'] as num?)?.toDouble() ?? 0,
    );
  }
}

abstract class HomeRepository {
  Future<DashboardTodayData> fetchDashboardToday();
}

class SupabaseHomeRepository implements HomeRepository {
  SupabaseHomeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DashboardTodayData> fetchDashboardToday() async {
    final dynamic response = await _client.rpc<dynamic>('dashboard_today');
    if (response is Map<String, dynamic>) {
      return DashboardTodayData.fromJson(response);
    }
    return DashboardTodayData.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
