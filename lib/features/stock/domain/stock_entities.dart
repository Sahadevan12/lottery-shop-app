import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';

enum TicketStatus {
  inStock('IN_STOCK'),
  withSeller('WITH_SELLER'),
  soldCounter('SOLD_COUNTER'),
  soldBySeller('SOLD_BY_SELLER'),
  returnedUnsold('RETURNED_UNSOLD');

  const TicketStatus(this.dbValue);
  final String dbValue;

  static TicketStatus fromDb(String raw) {
    return TicketStatus.values.firstWhere(
      (TicketStatus e) => e.dbValue == raw,
      orElse: () => TicketStatus.inStock,
    );
  }
}

enum DrawStatus {
  upcoming('UPCOMING'),
  resultEntered('RESULT_ENTERED'),
  closed('CLOSED');

  const DrawStatus(this.dbValue);
  final String dbValue;

  static DrawStatus fromDb(String raw) {
    return DrawStatus.values.firstWhere(
      (DrawStatus e) => e.dbValue == raw,
      orElse: () => DrawStatus.upcoming,
    );
  }
}

enum PrizeMatchType {
  full('FULL'),
  consolation('CONSOLATION'),
  last4('LAST_4'),
  last3('LAST_3');

  const PrizeMatchType(this.dbValue);
  final String dbValue;

  static PrizeMatchType fromDb(String raw) {
    return PrizeMatchType.values.firstWhere(
      (PrizeMatchType e) => e.dbValue == raw,
      orElse: () => PrizeMatchType.last4,
    );
  }
}

@immutable
class LotteryItem {
  const LotteryItem({
    required this.id,
    required this.shopId,
    required this.name,
    this.code,
    this.defaultWeekday,
    this.defaultTicketPricePaise = 4000,
    this.isBumper = false,
  });

  final String id;
  final String shopId;
  final String name;
  final String? code;

  /// 1 = Monday .. 7 = Sunday, null for Bumper (§6.3).
  final int? defaultWeekday;
  final int defaultTicketPricePaise;
  final bool isBumper;

  factory LotteryItem.fromJson(Map<String, dynamic> json) {
    return LotteryItem(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      defaultWeekday: json['default_weekday'] as int?,
      defaultTicketPricePaise: AppFormatters.parseNumericToPaise(
        json['default_ticket_price'] ?? 40,
      ),
      isBumper: (json['is_bumper'] as bool?) ?? false,
    );
  }
}

@immutable
class PrizeTemplateTier {
  const PrizeTemplateTier({
    required this.id,
    required this.templateId,
    required this.tierOrder,
    required this.label,
    required this.amountPaise,
    required this.matchType,
  });

  final String id;
  final String templateId;
  final int tierOrder;
  final String label;
  final int amountPaise;
  final PrizeMatchType matchType;

  factory PrizeTemplateTier.fromJson(Map<String, dynamic> json) {
    return PrizeTemplateTier(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      tierOrder: json['tier_order'] as int,
      label: json['label'] as String,
      amountPaise: AppFormatters.parseNumericToPaise(json['amount']),
      matchType: PrizeMatchType.fromDb(json['match_type'] as String),
    );
  }
}

@immutable
class PrizeTemplate {
  const PrizeTemplate({
    required this.id,
    required this.shopId,
    required this.name,
    this.tiers = const <PrizeTemplateTier>[],
  });

  final String id;
  final String shopId;
  final String name;
  final List<PrizeTemplateTier> tiers;
}

@immutable
class LotteryDraw {
  const LotteryDraw({
    required this.id,
    required this.shopId,
    required this.lotteryId,
    required this.lotteryName,
    this.lotteryCode,
    this.drawNumber,
    required this.drawDate,
    this.drawTime = '15:00',
    required this.ticketPricePaise,
    this.status = DrawStatus.upcoming,
    this.isBumper = false,
  });

  final String id;
  final String shopId;
  final String lotteryId;
  final String lotteryName;
  final String? lotteryCode;
  final String? drawNumber;
  final DateTime drawDate;
  final String drawTime;
  final int ticketPricePaise;
  final DrawStatus status;
  final bool isBumper;

  bool isSameDay(DateTime other) =>
      drawDate.year == other.year &&
      drawDate.month == other.month &&
      drawDate.day == other.day;
}

@immutable
class StockBatch {
  const StockBatch({
    required this.id,
    required this.shopId,
    required this.drawId,
    required this.series,
    required this.startNumber,
    required this.endNumber,
    required this.quantity,
    this.costPerTicketPaise,
    required this.inStockCount,
    this.withSellerCount = 0,
    this.soldCount = 0,
    this.returnedCount = 0,
  });

  final String id;
  final String shopId;
  final String drawId;
  final String series;
  final String startNumber;
  final String endNumber;
  final int quantity;
  final int? costPerTicketPaise;
  final int inStockCount;
  final int withSellerCount;
  final int soldCount;
  final int returnedCount;

  /// Deletion is allowed only if ALL tickets in the batch are IN_STOCK.
  bool get canDelete => inStockCount == quantity;
}

@immutable
class TicketItem {
  const TicketItem({
    required this.id,
    required this.shopId,
    required this.drawId,
    required this.batchId,
    required this.series,
    required this.number,
    this.status = TicketStatus.inStock,
    this.sellerId,
  });

  final String id;
  final String shopId;
  final String drawId;
  final String batchId;
  final String series;
  final String number;
  final TicketStatus status;
  final String? sellerId;

  factory TicketItem.fromJson(Map<String, dynamic> json) {
    return TicketItem(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      drawId: json['draw_id'] as String,
      batchId: json['batch_id'] as String,
      series: (json['series'] as String).trim(),
      number: (json['number'] as String).trim(),
      status: TicketStatus.fromDb(json['status'] as String),
      sellerId: json['seller_id'] as String?,
    );
  }
}

@immutable
class DrawStockSummary {
  const DrawStockSummary({
    this.total = 0,
    this.inStock = 0,
    this.withSellers = 0,
    this.sold = 0,
    this.returnedUnsold = 0,
  });

  final int total;
  final int inStock;
  final int withSellers;
  final int sold;
  final int returnedUnsold;
}
