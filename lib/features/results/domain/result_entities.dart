import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../../stock/domain/stock_entities.dart';

enum WinClaimStatus {
  unclaimed('UNCLAIMED'),
  paidToCustomer('PAID_TO_CUSTOMER'),
  claimedFromOffice('CLAIMED_FROM_OFFICE'),
  unsoldWin('UNSOLD_WIN');

  const WinClaimStatus(this.dbValue);
  final String dbValue;

  static WinClaimStatus fromDb(String raw) {
    return WinClaimStatus.values.firstWhere(
      (WinClaimStatus e) => e.dbValue == raw,
      orElse: () => WinClaimStatus.unclaimed,
    );
  }
}

enum WinSoldBy {
  counter('COUNTER'),
  seller('SELLER'),
  unsold('UNSOLD');

  const WinSoldBy(this.dbValue);
  final String dbValue;

  static WinSoldBy fromDb(String raw) {
    return WinSoldBy.values.firstWhere(
      (WinSoldBy e) => e.dbValue == raw,
      orElse: () => WinSoldBy.unsold,
    );
  }
}

@immutable
class DrawPrizeTier {
  const DrawPrizeTier({
    required this.id,
    required this.drawId,
    required this.tierOrder,
    required this.label,
    required this.amountPaise,
    required this.matchType,
  });

  final String id;
  final String drawId;
  final int tierOrder;
  final String label;
  final int amountPaise;
  final PrizeMatchType matchType;

  factory DrawPrizeTier.fromJson(Map<String, dynamic> json) {
    return DrawPrizeTier(
      id: json['id'] as String,
      drawId: json['draw_id'] as String,
      tierOrder: (json['tier_order'] as num).toInt(),
      label: json['label'] as String,
      amountPaise: AppFormatters.parseNumericToPaise(json['amount'] ?? 0),
      matchType: PrizeMatchType.fromDb(json['match_type'] as String),
    );
  }
}

@immutable
class DrawResultEntry {
  const DrawResultEntry({
    required this.id,
    required this.drawId,
    required this.tierId,
    this.winningSeries,
    required this.winningNumber,
  });

  final String id;
  final String drawId;
  final String tierId;
  final String? winningSeries;
  final String winningNumber;

  factory DrawResultEntry.fromJson(Map<String, dynamic> json) {
    return DrawResultEntry(
      id: json['id'] as String,
      drawId: json['draw_id'] as String,
      tierId: json['tier_id'] as String,
      winningSeries: json['winning_series'] as String?,
      winningNumber: json['winning_number'] as String,
    );
  }
}

@immutable
class ResultEntryInput {
  const ResultEntryInput({
    required this.tierId,
    this.winningSeries,
    required this.winningNumber,
  });

  final String tierId;
  final String? winningSeries;
  final String winningNumber;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tier_id': tierId,
      'winning_series': winningSeries,
      'winning_number': winningNumber,
    };
  }
}

@immutable
class WinningTicket {
  const WinningTicket({
    required this.id,
    required this.shopId,
    required this.drawId,
    required this.ticketId,
    required this.tierId,
    required this.prizeAmountPaise,
    required this.soldBy,
    this.sellerId,
    required this.claimStatus,
    required this.createdAt,
    this.ticketSeries = '',
    this.ticketNumber = '',
    this.tierLabel = '',
    this.tierOrder = 0,
    this.sellerName,
  });

  final String id;
  final String shopId;
  final String drawId;
  final String ticketId;
  final String tierId;
  final int prizeAmountPaise;
  final WinSoldBy soldBy;
  final String? sellerId;
  final WinClaimStatus claimStatus;
  final DateTime createdAt;

  final String ticketSeries;
  final String ticketNumber;
  final String tierLabel;
  final int tierOrder;
  final String? sellerName;

  WinningTicket copyWith({
    WinSoldBy? soldBy,
    String? sellerId,
    bool clearSellerId = false,
    WinClaimStatus? claimStatus,
    String? tierId,
    int? prizeAmountPaise,
    String? tierLabel,
    int? tierOrder,
    String? sellerName,
  }) {
    return WinningTicket(
      id: id,
      shopId: shopId,
      drawId: drawId,
      ticketId: ticketId,
      tierId: tierId ?? this.tierId,
      prizeAmountPaise: prizeAmountPaise ?? this.prizeAmountPaise,
      soldBy: soldBy ?? this.soldBy,
      sellerId: clearSellerId ? null : (sellerId ?? this.sellerId),
      claimStatus: claimStatus ?? this.claimStatus,
      createdAt: createdAt,
      ticketSeries: ticketSeries,
      ticketNumber: ticketNumber,
      tierLabel: tierLabel ?? this.tierLabel,
      tierOrder: tierOrder ?? this.tierOrder,
      sellerName: clearSellerId ? null : (sellerName ?? this.sellerName),
    );
  }

  factory WinningTicket.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? ticketMap =
        json['tickets'] as Map<String, dynamic>?;
    final Map<String, dynamic>? tierMap =
        json['draw_prize_tiers'] as Map<String, dynamic>?;
    final Map<String, dynamic>? sellerMap =
        json['sellers'] as Map<String, dynamic>?;

    return WinningTicket(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      drawId: json['draw_id'] as String,
      ticketId: json['ticket_id'] as String,
      tierId: json['tier_id'] as String,
      prizeAmountPaise: AppFormatters.parseNumericToPaise(
        json['prize_amount'] ?? 0,
      ),
      soldBy: WinSoldBy.fromDb(json['sold_by'] as String),
      sellerId: json['seller_id'] as String?,
      claimStatus: WinClaimStatus.fromDb(json['claim_status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      ticketSeries: (ticketMap?['series'] as String?) ?? '',
      ticketNumber: (ticketMap?['number'] as String?) ?? '',
      tierLabel: (tierMap?['label'] as String?) ?? '',
      tierOrder: (tierMap?['tier_order'] as num?)?.toInt() ?? 0,
      sellerName: sellerMap?['name'] as String?,
    );
  }
}

@immutable
class DrawSummaryRecord {
  const DrawSummaryRecord({
    required this.id,
    required this.shopId,
    required this.drawId,
    required this.ticketsBought,
    required this.ticketsSoldCounter,
    required this.ticketsSoldSeller,
    required this.ticketsUnsold,
    required this.grossRevenuePaise,
    required this.totalPrizesWonPaise,
    required this.closedAt,
  });

  final String id;
  final String shopId;
  final String drawId;
  final int ticketsBought;
  final int ticketsSoldCounter;
  final int ticketsSoldSeller;
  final int ticketsUnsold;
  final int grossRevenuePaise;
  final int totalPrizesWonPaise;
  final DateTime closedAt;

  factory DrawSummaryRecord.fromJson(Map<String, dynamic> json) {
    return DrawSummaryRecord(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      drawId: json['draw_id'] as String,
      ticketsBought: (json['tickets_bought'] as num).toInt(),
      ticketsSoldCounter: (json['tickets_sold_counter'] as num).toInt(),
      ticketsSoldSeller: (json['tickets_sold_seller'] as num).toInt(),
      ticketsUnsold: (json['tickets_unsold'] as num).toInt(),
      grossRevenuePaise: AppFormatters.parseNumericToPaise(
        json['gross_revenue'] ?? 0,
      ),
      totalPrizesWonPaise: AppFormatters.parseNumericToPaise(
        json['total_prizes_won'] ?? 0,
      ),
      closedAt: DateTime.parse(json['closed_at'] as String),
    );
  }
}
