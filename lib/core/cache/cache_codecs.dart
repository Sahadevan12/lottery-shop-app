import '../../features/results/domain/result_entities.dart';
import '../../features/sellers/domain/seller_entities.dart';
import '../../features/stock/domain/stock_entities.dart';

abstract final class CacheCodecs {
  // ---------------------------------------------------------------------------
  // Stock
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> lotteryToJson(LotteryItem item) =>
      <String, dynamic>{
        'id': item.id,
        'shop_id': item.shopId,
        'name': item.name,
        'code': item.code,
        'default_weekday': item.defaultWeekday,
        'default_ticket_price': item.defaultTicketPricePaise / 100.0,
      };

  static Map<String, dynamic> templateToJson(PrizeTemplate tpl) =>
      <String, dynamic>{
        'id': tpl.id,
        'shop_id': tpl.shopId,
        'name': tpl.name,
        'tiers': tpl.tiers
            .map(
              (PrizeTemplateTier t) => <String, dynamic>{
                'id': t.id,
                'template_id': t.templateId,
                'tier_order': t.tierOrder,
                'label': t.label,
                'amount': t.amountPaise / 100.0,
                'match_type': t.matchType.dbValue,
              },
            )
            .toList(growable: false),
      };

  static PrizeTemplate templateFromJson(Map<String, dynamic> json) {
    final List<dynamic> rawTiers =
        (json['tiers'] as List<dynamic>?) ?? <dynamic>[];
    return PrizeTemplate(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      name: json['name'] as String,
      tiers: rawTiers
          .map(
            (dynamic t) => PrizeTemplateTier.fromJson(
              Map<String, dynamic>.from(t as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> drawToJson(LotteryDraw d) => <String, dynamic>{
        'id': d.id,
        'shop_id': d.shopId,
        'lottery_id': d.lotteryId,
        'lottery_name': d.lotteryName,
        'lottery_code': d.lotteryCode,
        'draw_number': d.drawNumber,
        'draw_date': d.drawDate.toIso8601String(),
        'draw_time': d.drawTime,
        'ticket_price_paise': d.ticketPricePaise,
        'status': d.status.dbValue,
        'is_bumper': d.isBumper,
      };

  static LotteryDraw drawFromJson(Map<String, dynamic> json) => LotteryDraw(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        lotteryId: json['lottery_id'] as String,
        lotteryName: json['lottery_name'] as String,
        lotteryCode: json['lottery_code'] as String?,
        drawNumber: json['draw_number'] as String?,
        drawDate: DateTime.parse(json['draw_date'] as String),
        drawTime: (json['draw_time'] as String?) ?? '15:00',
        ticketPricePaise: (json['ticket_price_paise'] as num).toInt(),
        status: DrawStatus.fromDb((json['status'] as String?) ?? 'UPCOMING'),
        isBumper: (json['is_bumper'] as bool?) ?? false,
      );

  static Map<String, dynamic> batchToJson(StockBatch b) => <String, dynamic>{
        'id': b.id,
        'shop_id': b.shopId,
        'draw_id': b.drawId,
        'series': b.series,
        'start_number': b.startNumber,
        'end_number': b.endNumber,
        'quantity': b.quantity,
        'cost_per_ticket_paise': b.costPerTicketPaise,
        'in_stock_count': b.inStockCount,
        'with_seller_count': b.withSellerCount,
        'sold_count': b.soldCount,
        'returned_count': b.returnedCount,
      };

  static StockBatch batchFromJson(Map<String, dynamic> json) => StockBatch(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        drawId: json['draw_id'] as String,
        series: json['series'] as String,
        startNumber: json['start_number'] as String,
        endNumber: json['end_number'] as String,
        quantity: (json['quantity'] as num).toInt(),
        costPerTicketPaise: (json['cost_per_ticket_paise'] as num?)?.toInt(),
        inStockCount: (json['in_stock_count'] as num).toInt(),
        withSellerCount: (json['with_seller_count'] as num?)?.toInt() ?? 0,
        soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
        returnedCount: (json['returned_count'] as num?)?.toInt() ?? 0,
      );

  // ---------------------------------------------------------------------------
  // Sellers & Ledger
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> sellerSummaryToJson(SellerSummary s) =>
      <String, dynamic>{
        'seller': <String, dynamic>{
          'id': s.seller.id,
          'shop_id': s.seller.shopId,
          'name': s.seller.name,
          'phone': s.seller.phone,
          'area': s.seller.area,
          'is_active': s.seller.isActive,
          'created_at': s.seller.createdAt.toIso8601String(),
        },
        'balance_paise': s.balancePaise,
        'tickets_with_seller': s.ticketsWithSeller,
        'has_ledger_history': s.hasLedgerHistory,
        'last_activity_at': s.lastActivityAt.toIso8601String(),
      };

  static SellerSummary sellerSummaryFromJson(Map<String, dynamic> json) =>
      SellerSummary(
        seller: SellerProfile.fromJson(
          Map<String, dynamic>.from(json['seller'] as Map),
        ),
        balancePaise: (json['balance_paise'] as num).toInt(),
        ticketsWithSeller: (json['tickets_with_seller'] as num).toInt(),
        hasLedgerHistory: (json['has_ledger_history'] as bool?) ?? false,
        lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
      );

  static Map<String, dynamic> ledgerEntryToJson(LedgerEntry e) =>
      <String, dynamic>{
        'id': e.id,
        'shop_id': e.shopId,
        'seller_id': e.sellerId,
        'draw_id': e.drawId,
        'type': e.type.dbValue,
        'amount': e.amountPaise / 100.0,
        'ticket_count': e.ticketCount,
        'payment_method': e.paymentMethod?.dbValue,
        'reversed_entry_id': e.reversedEntryId,
        'note': e.note,
        'created_at': e.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> ticketToJson(TicketItem t) => <String, dynamic>{
        'id': t.id,
        'shop_id': t.shopId,
        'draw_id': t.drawId,
        'batch_id': t.batchId,
        'series': t.series,
        'number': t.number,
        'status': t.status.dbValue,
        'seller_id': t.sellerId,
      };

  // ---------------------------------------------------------------------------
  // Results & Wins
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> prizeTierToJson(DrawPrizeTier t) =>
      <String, dynamic>{
        'id': t.id,
        'draw_id': t.drawId,
        'tier_order': t.tierOrder,
        'label': t.label,
        'amount': t.amountPaise / 100.0,
        'match_type': t.matchType.dbValue,
      };

  static Map<String, dynamic> resultEntryToJson(DrawResultEntry r) =>
      <String, dynamic>{
        'id': r.id,
        'draw_id': r.drawId,
        'tier_id': r.tierId,
        'series': r.winningSeries,
        'number': r.winningNumber,
      };

  static Map<String, dynamic> winningTicketToJson(WinningTicket w) =>
      <String, dynamic>{
        'id': w.id,
        'shop_id': w.shopId,
        'draw_id': w.drawId,
        'ticket_id': w.ticketId,
        'tier_id': w.tierId,
        'amount': w.prizeAmountPaise / 100.0,
        'sold_by': w.soldBy.dbValue,
        'seller_id': w.sellerId,
        'claim_status': w.claimStatus.dbValue,
        'created_at': w.createdAt.toIso8601String(),
        'tickets': <String, dynamic>{
          'series': w.ticketSeries,
          'number': w.ticketNumber,
        },
        'draw_prize_tiers': <String, dynamic>{
          'label': w.tierLabel,
          'tier_order': w.tierOrder,
        },
        if (w.sellerName != null)
          'sellers': <String, dynamic>{'name': w.sellerName},
      };

  static Map<String, dynamic> drawSummaryToJson(DrawSummaryRecord s) =>
      <String, dynamic>{
        'shop_id': s.shopId,
        'draw_id': s.drawId,
        'total_tickets':
            s.ticketsBought,
        'sold_counter': s.ticketsSoldCounter,
        'sold_by_sellers': s.ticketsSoldSeller,
        'returned_unsold': s.ticketsUnsold,
        'total_cost': s.totalCostPaise / 100.0,
        'total_sales': s.grossRevenuePaise / 100.0,
        'total_prizes': s.totalPrizesWonPaise / 100.0,
      };
}
