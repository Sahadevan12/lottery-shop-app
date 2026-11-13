import 'package:lucky_ledger/core/utils/formatters.dart';
import 'package:lucky_ledger/core/utils/validators.dart';
import 'package:lucky_ledger/features/auth/data/auth_repository.dart';
import 'package:lucky_ledger/features/auth/domain/shop_profile.dart';
import 'package:lucky_ledger/features/stock/data/stock_repository.dart';
import 'package:lucky_ledger/features/stock/domain/stock_entities.dart';
import 'package:lucky_ledger/features/stock/domain/stock_range_logic.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test-only fake implementation of [AuthRepository] (kept under `test/` only).
class FakeAuthRepository implements AuthRepository {
  String? _userId;
  String? _phone;
  ShopProfile? _shop;

  @override
  String? get currentUserId => _userId;

  @override
  String? get currentPhone => _phone;

  @override
  Future<void> signInOrSignUp({
    required String phone,
    required String pin,
  }) async {
    final String normalizedPhone = AppValidators.normalizePhone(phone);
    AppValidators.phoneToInternalEmail(normalizedPhone);
    if (!AppValidators.isValidPin(pin)) {
      throw const AuthException('INVALID_PIN');
    }
    _userId = 'user-$normalizedPhone';
    _phone = normalizedPhone;
  }

  @override
  Future<ShopProfile?> fetchCurrentShop() async => _shop;

  @override
  Future<ShopProfile> createShopWithDefaults({
    required String name,
    required String ownerName,
    required String district,
    String? agentCode,
    required String language,
  }) async {
    final ShopProfile created = ShopProfile(
      id: 'shop-1',
      ownerId: _userId ?? 'user-default',
      name: name.trim(),
      ownerName: ownerName.trim(),
      phone: _phone ?? '9876543210',
      district: district,
      agentCode: agentCode,
      defaultLanguage: language,
    );
    _shop = created;
    return created;
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _phone = null;
    _shop = null;
  }
}

/// Test-only fake implementation of [StockRepository] (kept under `test/` only).
class FakeStockRepository implements StockRepository {
  FakeStockRepository() {
    _lotteries.addAll(<LotteryItem>[
      const LotteryItem(
        id: 'lot-1',
        shopId: 'shop-1',
        name: 'Win-Win',
        code: 'W',
        defaultWeekday: 1,
        defaultTicketPricePaise: 4000,
      ),
      const LotteryItem(
        id: 'lot-2',
        shopId: 'shop-1',
        name: 'Sthree Sakthi',
        code: 'SS',
        defaultWeekday: 2,
        defaultTicketPricePaise: 4000,
      ),
      const LotteryItem(
        id: 'lot-3',
        shopId: 'shop-1',
        name: 'Fifty-Fifty',
        code: 'FF',
        defaultWeekday: 3,
        defaultTicketPricePaise: 5000,
      ),
      const LotteryItem(
        id: 'lot-4',
        shopId: 'shop-1',
        name: 'Karunya Plus',
        code: 'KN',
        defaultWeekday: 4,
        defaultTicketPricePaise: 4000,
      ),
      const LotteryItem(
        id: 'lot-5',
        shopId: 'shop-1',
        name: 'Nirmal',
        code: 'NR',
        defaultWeekday: 5,
        defaultTicketPricePaise: 4000,
      ),
      const LotteryItem(
        id: 'lot-6',
        shopId: 'shop-1',
        name: 'Karunya',
        code: 'KR',
        defaultWeekday: 6,
        defaultTicketPricePaise: 4000,
      ),
      const LotteryItem(
        id: 'lot-7',
        shopId: 'shop-1',
        name: 'Akshaya',
        code: 'AK',
        defaultWeekday: 7,
        defaultTicketPricePaise: 4000,
      ),
    ]);

    _templates.add(
      const PrizeTemplate(
        id: 'tpl-1',
        shopId: 'shop-1',
        name: 'Regular Weekly Template',
        tiers: <PrizeTemplateTier>[
          PrizeTemplateTier(
            id: 'tier-1',
            templateId: 'tpl-1',
            tierOrder: 1,
            label: '1st Prize',
            amountPaise: 750000000,
            matchType: PrizeMatchType.full,
          ),
        ],
      ),
    );
  }

  final List<LotteryItem> _lotteries = <LotteryItem>[];
  final List<PrizeTemplate> _templates = <PrizeTemplate>[];
  final List<LotteryDraw> _draws = <LotteryDraw>[];
  final Map<String, List<StockBatch>> _batchesByDraw =
      <String, List<StockBatch>>{};
  final Map<String, List<TicketItem>> _ticketsByBatch =
      <String, List<TicketItem>>{};
  int _idSeq = 1;

  void setDrawStatus(String drawId, DrawStatus status) {
    final int idx = _draws.indexWhere((LotteryDraw d) => d.id == drawId);
    if (idx != -1) {
      final LotteryDraw current = _draws[idx];
      _draws[idx] = LotteryDraw(
        id: current.id,
        shopId: current.shopId,
        lotteryId: current.lotteryId,
        lotteryName: current.lotteryName,
        lotteryCode: current.lotteryCode,
        drawNumber: current.drawNumber,
        drawDate: current.drawDate,
        drawTime: current.drawTime,
        ticketPricePaise: current.ticketPricePaise,
        status: status,
        isBumper: current.isBumper,
      );
    }
  }

  void markTicketStatus(String batchId, String number, TicketStatus status) {
    final List<TicketItem>? list = _ticketsByBatch[batchId];
    if (list == null) {
      return;
    }
    for (int i = 0; i < list.length; i++) {
      if (list[i].number == number) {
        list[i] = TicketItem(
          id: list[i].id,
          shopId: list[i].shopId,
          drawId: list[i].drawId,
          batchId: list[i].batchId,
          series: list[i].series,
          number: list[i].number,
          status: status,
        );
      }
    }
    _recomputeBatchCounts(batchId);
  }

  void _recomputeBatchCounts(String batchId) {
    final List<TicketItem> tickets =
        _ticketsByBatch[batchId] ?? const <TicketItem>[];
    int inStock = 0;
    int withSeller = 0;
    int sold = 0;
    int returned = 0;
    for (final TicketItem t in tickets) {
      switch (t.status) {
        case TicketStatus.inStock:
          inStock++;
        case TicketStatus.withSeller:
          withSeller++;
        case TicketStatus.soldCounter:
        case TicketStatus.soldBySeller:
          sold++;
        case TicketStatus.returnedUnsold:
          returned++;
      }
    }
    for (final String drawId in _batchesByDraw.keys) {
      final List<StockBatch> list = _batchesByDraw[drawId]!;
      final int idx = list.indexWhere((StockBatch b) => b.id == batchId);
      if (idx != -1) {
        final StockBatch old = list[idx];
        list[idx] = StockBatch(
          id: old.id,
          shopId: old.shopId,
          drawId: old.drawId,
          series: old.series,
          startNumber: old.startNumber,
          endNumber: old.endNumber,
          quantity: old.quantity,
          costPerTicketPaise: old.costPerTicketPaise,
          inStockCount: inStock,
          withSellerCount: withSeller,
          soldCount: sold,
          returnedCount: returned,
        );
      }
    }
  }

  @override
  Future<List<LotteryItem>> fetchLotteries() async =>
      List<LotteryItem>.unmodifiable(_lotteries);

  @override
  Future<LotteryItem> saveLottery({
    String? id,
    required String name,
    String? code,
    int? defaultWeekday,
    required int defaultTicketPricePaise,
    required bool isBumper,
  }) async {
    final LotteryItem item = LotteryItem(
      id: id ?? 'lot-${++_idSeq}',
      shopId: 'shop-1',
      name: name,
      code: code,
      defaultWeekday: defaultWeekday,
      defaultTicketPricePaise: defaultTicketPricePaise,
      isBumper: isBumper,
    );
    _lotteries.removeWhere((LotteryItem l) => l.id == item.id);
    _lotteries.add(item);
    return item;
  }

  @override
  Future<List<PrizeTemplate>> fetchPrizeTemplates() async =>
      List<PrizeTemplate>.unmodifiable(_templates);

  @override
  Future<PrizeTemplate> savePrizeTemplate({
    String? id,
    required String name,
    required List<PrizeTemplateTier> tiers,
  }) async {
    final PrizeTemplate tpl = PrizeTemplate(
      id: id ?? 'tpl-${++_idSeq}',
      shopId: 'shop-1',
      name: name,
      tiers: tiers,
    );
    _templates.removeWhere((PrizeTemplate t) => t.id == tpl.id);
    _templates.add(tpl);
    return tpl;
  }

  @override
  Future<List<LotteryDraw>> fetchDraws() async =>
      List<LotteryDraw>.unmodifiable(_draws);

  @override
  Future<String> createDraw({
    required String lotteryId,
    required DateTime drawDate,
    String? drawNumber,
    required int ticketPricePaise,
    String? templateId,
  }) async {
    final LotteryItem? lottery = _lotteries
        .cast<LotteryItem?>()
        .firstWhere((LotteryItem? l) => l?.id == lotteryId, orElse: () => null);
    if (lottery == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }

    final bool duplicate = _draws.any(
      (LotteryDraw d) =>
          d.lotteryId == lotteryId && d.isSameDay(drawDate),
    );
    if (duplicate) {
      throw const PostgrestException(message: 'DRAW_EXISTS');
    }

    final String id = 'draw-${++_idSeq}';
    _draws.add(
      LotteryDraw(
        id: id,
        shopId: 'shop-1',
        lotteryId: lotteryId,
        lotteryName: lottery.name,
        lotteryCode: lottery.code,
        drawNumber: drawNumber,
        drawDate: drawDate,
        ticketPricePaise: ticketPricePaise,
        isBumper: lottery.isBumper,
      ),
    );
    return id;
  }

  @override
  Future<List<StockBatch>> fetchBatchesForDraw(String drawId) async {
    return List<StockBatch>.unmodifiable(
      _batchesByDraw[drawId] ?? const <StockBatch>[],
    );
  }

  @override
  Future<String> createStockBatch({
    required String drawId,
    required String series,
    required String startNumber,
    required String endNumber,
    int? costPerTicketPaise,
  }) async {
    final LotteryDraw? draw = _draws
        .cast<LotteryDraw?>()
        .firstWhere((LotteryDraw? d) => d?.id == drawId, orElse: () => null);
    if (draw == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    if (draw.status != DrawStatus.upcoming) {
      throw const PostgrestException(message: 'DRAW_NOT_OPEN');
    }

    final StockRangeEvaluation eval = StockRangeLogic.evaluateRange(
      series: series,
      startNumber: startNumber,
      endNumber: endNumber,
      costPerTicketPaise: costPerTicketPaise,
    );
    if (!eval.isValid) {
      throw const PostgrestException(message: 'INVALID_RANGE');
    }

    final List<StockBatch> existing =
        _batchesByDraw[drawId] ?? <StockBatch>[];
    final String? overlap = StockRangeLogic.findOverlappingRange(
      series: eval.normalizedSeries,
      startNumber: eval.paddedStart,
      endNumber: eval.paddedEnd,
      existingBatches: existing,
    );
    if (overlap != null) {
      throw PostgrestException(
        message: 'STOCK_OVERLAP',
        details: overlap,
      );
    }

    final String batchId = 'batch-${++_idSeq}';
    final StockBatch batch = StockBatch(
      id: batchId,
      shopId: 'shop-1',
      drawId: drawId,
      series: eval.normalizedSeries,
      startNumber: eval.paddedStart,
      endNumber: eval.paddedEnd,
      quantity: eval.quantity,
      costPerTicketPaise: costPerTicketPaise,
      inStockCount: eval.quantity,
    );

    final List<StockBatch> list =
        _batchesByDraw.putIfAbsent(drawId, () => <StockBatch>[]);
    list.insert(0, batch);

    final int sInt = int.parse(eval.paddedStart);
    final int eInt = int.parse(eval.paddedEnd);
    final List<TicketItem> generated = <TicketItem>[
      for (int n = sInt; n <= eInt; n++)
        TicketItem(
          id: 'tkt-$batchId-$n',
          shopId: 'shop-1',
          drawId: drawId,
          batchId: batchId,
          series: eval.normalizedSeries,
          number: AppFormatters.padTicketNumber(n),
        ),
    ];
    _ticketsByBatch[batchId] = generated;
    return batchId;
  }

  @override
  Future<void> deleteStockBatch(String batchId) async {
    StockBatch? target;
    String? targetDrawId;
    for (final MapEntry<String, List<StockBatch>> entry
        in _batchesByDraw.entries) {
      for (final StockBatch b in entry.value) {
        if (b.id == batchId) {
          target = b;
          targetDrawId = entry.key;
          break;
        }
      }
    }
    if (target == null || targetDrawId == null) {
      throw const PostgrestException(message: 'NOT_FOUND');
    }
    if (!target.canDelete) {
      throw const PostgrestException(message: 'BATCH_IN_USE');
    }
    _batchesByDraw[targetDrawId]!.removeWhere((StockBatch b) => b.id == batchId);
    _ticketsByBatch.remove(batchId);
  }

  @override
  Future<List<TicketItem>> fetchTicketsForBatch(String batchId) async {
    return List<TicketItem>.unmodifiable(
      _ticketsByBatch[batchId] ?? const <TicketItem>[],
    );
  }
}
