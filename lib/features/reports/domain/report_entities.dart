enum ReportPeriodPreset {
  today,
  week,
  month,
  thirtyDays,
  custom,
}

/// Draw-level P&L row returned inside `get_reports_summary()`.
class DrawPnlRow {
  const DrawPnlRow({
    required this.drawId,
    required this.lotteryName,
    required this.drawNumber,
    required this.drawDate,
    required this.status,
    required this.ticketPrice,
    required this.ticketsBought,
    required this.ticketsSoldCounter,
    required this.ticketsSoldSeller,
    required this.ticketsUnsold,
    required this.sales,
    required this.stockCost,
    required this.grossMargin,
    required this.unsoldPrizeGain,
    required this.netProfit,
    required this.toRecoverFromOffice,
  });

  final String drawId;
  final String lotteryName;
  final String drawNumber;
  final DateTime drawDate;
  final String status;
  final double ticketPrice;
  final int ticketsBought;
  final int ticketsSoldCounter;
  final int ticketsSoldSeller;
  final int ticketsUnsold;
  final double sales;
  final double stockCost;
  final double grossMargin;
  final double unsoldPrizeGain;
  final double netProfit;
  final double toRecoverFromOffice;

  int get ticketsSoldTotal => ticketsSoldCounter + ticketsSoldSeller;

  factory DrawPnlRow.fromJson(Map<String, dynamic> json) {
    return DrawPnlRow(
      drawId: json['draw_id']?.toString() ?? '',
      lotteryName: json['lottery_name']?.toString() ?? '',
      drawNumber: json['draw_number']?.toString() ?? '',
      drawDate:
          DateTime.tryParse(json['draw_date']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'UPCOMING',
      ticketPrice: (json['ticket_price'] as num?)?.toDouble() ?? 0,
      ticketsBought: (json['tickets_bought'] as num?)?.toInt() ?? 0,
      ticketsSoldCounter: (json['tickets_sold_counter'] as num?)?.toInt() ?? 0,
      ticketsSoldSeller: (json['tickets_sold_seller'] as num?)?.toInt() ?? 0,
      ticketsUnsold: (json['tickets_unsold'] as num?)?.toInt() ?? 0,
      sales: (json['sales'] as num?)?.toDouble() ?? 0,
      stockCost: (json['stock_cost'] as num?)?.toDouble() ?? 0,
      grossMargin: (json['gross_margin'] as num?)?.toDouble() ?? 0,
      unsoldPrizeGain: (json['unsold_prize_gain'] as num?)?.toDouble() ?? 0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0,
      toRecoverFromOffice:
          (json['to_recover_from_office'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Period P&L summary returned by `get_reports_summary(p_from_date, p_to_date)`.
class ReportsSummaryData {
  const ReportsSummaryData({
    required this.fromDate,
    required this.toDate,
    required this.totalSales,
    required this.totalStockCost,
    required this.totalGrossMargin,
    required this.totalUnsoldPrizeGain,
    required this.totalNetProfit,
    required this.totalToRecoverFromOffice,
    required this.toCollectFromSellers,
    required this.draws,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final double totalSales;
  final double totalStockCost;
  final double totalGrossMargin;
  final double totalUnsoldPrizeGain;
  final double totalNetProfit;
  final double totalToRecoverFromOffice;
  final double toCollectFromSellers;
  final List<DrawPnlRow> draws;

  int get totalTicketsBought =>
      draws.fold<int>(0, (int sum, DrawPnlRow d) => sum + d.ticketsBought);

  int get totalTicketsSoldCounter =>
      draws.fold<int>(0, (int sum, DrawPnlRow d) => sum + d.ticketsSoldCounter);

  int get totalTicketsSoldSeller =>
      draws.fold<int>(0, (int sum, DrawPnlRow d) => sum + d.ticketsSoldSeller);

  int get totalTicketsSold =>
      totalTicketsSoldCounter + totalTicketsSoldSeller;

  factory ReportsSummaryData.empty(DateTime fromDate, DateTime toDate) {
    return ReportsSummaryData(
      fromDate: fromDate,
      toDate: toDate,
      totalSales: 0,
      totalStockCost: 0,
      totalGrossMargin: 0,
      totalUnsoldPrizeGain: 0,
      totalNetProfit: 0,
      totalToRecoverFromOffice: 0,
      toCollectFromSellers: 0,
      draws: const <DrawPnlRow>[],
    );
  }

  factory ReportsSummaryData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawDraws = (json['draws'] as List<dynamic>?) ?? <dynamic>[];
    return ReportsSummaryData(
      fromDate: DateTime.tryParse(json['from_date']?.toString() ?? '') ??
          DateTime.now(),
      toDate:
          DateTime.tryParse(json['to_date']?.toString() ?? '') ?? DateTime.now(),
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
      totalStockCost: (json['total_stock_cost'] as num?)?.toDouble() ?? 0,
      totalGrossMargin: (json['total_gross_margin'] as num?)?.toDouble() ?? 0,
      totalUnsoldPrizeGain:
          (json['total_unsold_prize_gain'] as num?)?.toDouble() ?? 0,
      totalNetProfit: (json['total_net_profit'] as num?)?.toDouble() ?? 0,
      totalToRecoverFromOffice:
          (json['total_to_recover_from_office'] as num?)?.toDouble() ?? 0,
      toCollectFromSellers:
          (json['to_collect_from_sellers'] as num?)?.toDouble() ?? 0,
      draws: rawDraws
          .map(
            (dynamic item) => DrawPnlRow.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
