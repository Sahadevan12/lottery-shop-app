import 'package:lucky_ledger/features/home/data/home_repository.dart';
import 'package:lucky_ledger/features/reports/data/reports_repository.dart';
import 'package:lucky_ledger/features/reports/domain/report_entities.dart';
import 'package:lucky_ledger/features/stock/domain/stock_entities.dart';

import 'fake_repositories.dart';

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({DashboardTodayData? data})
      : _stockRepo = null,
        _data = data ??
            DashboardTodayData(
              todayDate: DateTime(2026, 11, 13),
              drawsCount: 1,
              inStockCount: 120,
              withSellerCount: 80,
              soldCounterCount: 40,
              soldSellerCount: 60,
              returnedCount: 10,
              totalTickets: 310,
              todayWinsCount: 3,
              todayPrizesTotal: 15000,
              unclaimedWinsCount: 2,
              totalDueFromSellers: 4200,
              toRecoverFromOffice: 5000,
            );

  FakeHomeRepository.fromStock(FakeStockRepository stockRepo)
      : _stockRepo = stockRepo,
        _data = null;

  final FakeStockRepository? _stockRepo;
  final DashboardTodayData? _data;

  @override
  Future<DashboardTodayData> fetchDashboardToday() async {
    if (_stockRepo != null) {
      final List<LotteryDraw> draws = await _stockRepo.fetchDraws();
      int inStock = 0;
      int withSellers = 0;
      int sold = 0;
      int returned = 0;
      for (final LotteryDraw d in draws) {
        final List<TicketItem> tickets = await _stockRepo.fetchTicketsForDraw(
          d.id,
        );
        for (final TicketItem t in tickets) {
          switch (t.status) {
            case TicketStatus.inStock:
              inStock++;
            case TicketStatus.withSeller:
              withSellers++;
            case TicketStatus.soldCounter:
            case TicketStatus.soldBySeller:
              sold++;
            case TicketStatus.returnedUnsold:
              returned++;
          }
        }
      }
      return DashboardTodayData(
        todayDate: DateTime.now(),
        drawsCount: draws.length,
        inStockCount: inStock,
        withSellerCount: withSellers,
        soldCounterCount: sold,
        soldSellerCount: 0,
        returnedCount: returned,
        totalTickets: inStock + withSellers + sold + returned,
        todayWinsCount: 0,
        todayPrizesTotal: 0,
        unclaimedWinsCount: 0,
        totalDueFromSellers: 0,
        toRecoverFromOffice: 0,
      );
    }
    return _data!;
  }
}

class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository({ReportsSummaryData? summary})
      : _summary = summary ?? defaultSampleSummary();

  final ReportsSummaryData _summary;

  static ReportsSummaryData defaultSampleSummary() {
    final DateTime from = DateTime(2026, 10, 15);
    final DateTime to = DateTime(2026, 11, 13);
    // Example: 100 bought @ cost ₹32 = ₹3,200; 80 sold @ ₹40 = ₹3,200;
    // Gross margin = ₹0; Unsold prize gain = ₹500; Net profit = ₹500
    // (Customer prize ₹5,000 is NOT subtracted).
    return ReportsSummaryData(
      fromDate: from,
      toDate: to,
      totalSales: 3200,
      totalStockCost: 3200,
      totalGrossMargin: 0,
      totalUnsoldPrizeGain: 500,
      totalNetProfit: 500,
      totalToRecoverFromOffice: 5000,
      toCollectFromSellers: 1800,
      draws: <DrawPnlRow>[
        DrawPnlRow(
          drawId: 'draw-1',
          lotteryName: 'Karunya',
          drawNumber: 'KR-701',
          drawDate: DateTime(2026, 11, 12),
          status: 'CLOSED',
          ticketPrice: 40,
          ticketsBought: 100,
          ticketsSoldCounter: 30,
          ticketsSoldSeller: 50,
          ticketsUnsold: 20,
          sales: 3200,
          stockCost: 3200,
          grossMargin: 0,
          unsoldPrizeGain: 500,
          netProfit: 500,
          toRecoverFromOffice: 5000,
        ),
      ],
    );
  }

  @override
  Future<ReportsSummaryData> fetchReportsSummary({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return _summary;
  }
}
