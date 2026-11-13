import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';

enum LedgerEntryType {
  issue('ISSUE'),
  returnTickets('RETURN'),
  payment('PAYMENT'),
  prizePaidBySeller('PRIZE_PAID_BY_SELLER'),
  adjustment('ADJUSTMENT');

  const LedgerEntryType(this.dbValue);
  final String dbValue;

  bool get isReversible =>
      this == LedgerEntryType.payment ||
      this == LedgerEntryType.prizePaidBySeller ||
      this == LedgerEntryType.adjustment;

  static LedgerEntryType fromDb(String value) {
    for (final LedgerEntryType item in LedgerEntryType.values) {
      if (item.dbValue == value) {
        return item;
      }
    }
    return LedgerEntryType.adjustment;
  }
}

enum PaymentMethod {
  cash('CASH'),
  upi('UPI'),
  other('OTHER');

  const PaymentMethod(this.dbValue);
  final String dbValue;

  static PaymentMethod? fromDb(String? value) {
    if (value == null) {
      return null;
    }
    for (final PaymentMethod item in PaymentMethod.values) {
      if (item.dbValue == value) {
        return item;
      }
    }
    return PaymentMethod.other;
  }
}

enum SellerSortMode {
  highestDue,
  name,
  recent,
}

@immutable
class SellerProfile {
  const SellerProfile({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.area,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? area;
  final bool isActive;
  final DateTime createdAt;

  SellerProfile copyWith({
    String? name,
    String? phone,
    String? area,
    bool? isActive,
  }) {
    return SellerProfile(
      id: id,
      shopId: shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      area: area ?? this.area,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      area: json['area'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class SellerSummary {
  const SellerSummary({
    required this.seller,
    this.balancePaise = 0,
    this.ticketsWithSeller = 0,
    this.hasLedgerHistory = false,
    required this.lastActivityAt,
  });

  final SellerProfile seller;
  final int balancePaise;
  final int ticketsWithSeller;
  final bool hasLedgerHistory;
  final DateTime lastActivityAt;

  bool get canDeleteDirectly => !hasLedgerHistory && ticketsWithSeller == 0;
}

@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.shopId,
    required this.sellerId,
    this.drawId,
    required this.type,
    required this.amountPaise,
    this.ticketCount,
    this.paymentMethod,
    this.reversedEntryId,
    this.note,
    required this.createdAt,
    this.isReversed = false,
    this.reversedByEntryId,
  });

  final String id;
  final String shopId;
  final String sellerId;
  final String? drawId;
  final LedgerEntryType type;

  /// Positive = seller owes more; negative = seller paid / returned / credit.
  final int amountPaise;
  final int? ticketCount;
  final PaymentMethod? paymentMethod;
  final String? reversedEntryId;
  final String? note;
  final DateTime createdAt;

  /// Populated by `LedgerMath.linkReversalPairs` when a later `ADJUSTMENT`
  /// entry has `reversedEntryId == id`.
  final bool isReversed;
  final String? reversedByEntryId;

  bool get isReversalEntry => reversedEntryId != null;

  bool get canReverse =>
      type.isReversible && !isReversed && !isReversalEntry;

  LedgerEntry copyWith({
    bool? isReversed,
    String? reversedByEntryId,
  }) {
    return LedgerEntry(
      id: id,
      shopId: shopId,
      sellerId: sellerId,
      drawId: drawId,
      type: type,
      amountPaise: amountPaise,
      ticketCount: ticketCount,
      paymentMethod: paymentMethod,
      reversedEntryId: reversedEntryId,
      note: note,
      createdAt: createdAt,
      isReversed: isReversed ?? this.isReversed,
      reversedByEntryId: reversedByEntryId ?? this.reversedByEntryId,
    );
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      sellerId: json['seller_id'] as String,
      drawId: json['draw_id'] as String?,
      type: LedgerEntryType.fromDb(json['type'] as String),
      amountPaise: AppFormatters.parseNumericToPaise(json['amount']),
      ticketCount: json['ticket_count'] as int?,
      paymentMethod: PaymentMethod.fromDb(json['payment_method'] as String?),
      reversedEntryId: json['reversed_entry_id'] as String?,
      note: json['note'] as String?,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class DrawBreakdownRow {
  const DrawBreakdownRow({
    required this.drawId,
    required this.drawLabel,
    this.drawDate,
    this.issuedPaise = 0,
    this.issuedTicketCount = 0,
    this.returnedPaise = 0,
    this.returnedTicketCount = 0,
    this.prizePaidPaise = 0,
    this.drawAdjustmentsPaise = 0,
  });

  final String drawId;
  final String drawLabel;
  final DateTime? drawDate;

  /// Positive amount issued for this draw.
  final int issuedPaise;
  final int issuedTicketCount;

  /// Signed negative (or zero) amount returned for this draw.
  final int returnedPaise;
  final int returnedTicketCount;

  /// Signed negative (or zero) amount of prizes paid by seller for this draw.
  final int prizePaidPaise;

  /// Reversals of draw-linked `PRIZE_PAID_BY_SELLER` entries.
  final int drawAdjustmentsPaise;

  int get netDrawPaise =>
      issuedPaise + returnedPaise + prizePaidPaise + drawAdjustmentsPaise;
}

@immutable
class SellerBalanceBreakdown {
  const SellerBalanceBreakdown({
    this.drawRows = const <DrawBreakdownRow>[],
    this.paymentsTotalPaise = 0,
    this.generalAdjustmentsPaise = 0,
    this.grandTotalPaise = 0,
  });

  final List<DrawBreakdownRow> drawRows;

  /// Signed negative sum of all `PAYMENT` entries.
  final int paymentsTotalPaise;

  /// Signed sum of non-draw-linked `ADJUSTMENT` entries (e.g. payment reversals).
  final int generalAdjustmentsPaise;

  /// Exact net balance due (`sum(entry.amountPaise)`).
  final int grandTotalPaise;
}
