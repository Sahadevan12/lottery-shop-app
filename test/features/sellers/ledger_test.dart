import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_ledger/core/theme/app_theme.dart';
import 'package:lucky_ledger/features/sellers/domain/ledger_math.dart';
import 'package:lucky_ledger/features/sellers/domain/seller_entities.dart';
import 'package:lucky_ledger/features/sellers/presentation/seller_detail_screen.dart';
import 'package:lucky_ledger/features/sellers/presentation/sellers_controller.dart';
import 'package:lucky_ledger/features/sellers/presentation/sellers_screen.dart';
import 'package:lucky_ledger/features/stock/domain/stock_entities.dart';
import 'package:lucky_ledger/features/stock/presentation/stock_controller.dart';
import 'package:lucky_ledger/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/fake_seller_repository.dart';

void main() {
  group('Phase 3 — Pure LedgerMath Unit Tests (§7.2–7.4, A.2, A.5, B.13)', () {
    test('validates payment bounds and seller advance warning math', () {
      expect(LedgerMath.isValidPaymentAmountPaise(0), isFalse);
      expect(LedgerMath.isValidPaymentAmountPaise(-100), isFalse);
      expect(LedgerMath.isValidPaymentAmountPaise(100), isTrue);
      expect(
        LedgerMath.isValidPaymentAmountPaise(LedgerMath.maxPaymentPaise),
        isTrue,
      );
      expect(
        LedgerMath.isValidPaymentAmountPaise(
          LedgerMath.maxPaymentPaise + 1,
        ),
        isFalse,
      );

      // Owes ₹1,000, pays ₹1,500 -> exceeds balance by ₹500
      expect(
        LedgerMath.willPaymentExceedBalance(
          currentBalancePaise: 100000,
          paymentAmountPaise: 150000,
        ),
        isTrue,
      );
      expect(
        LedgerMath.computeAdvancePaise(
          currentBalancePaise: 100000,
          paymentAmountPaise: 150000,
        ),
        50000,
      );
    });

    test('pickNextInStockTickets and selectTicketsInRange work accurately', () {
      final List<TicketItem> tickets = <TicketItem>[
        const TicketItem(
          id: 't1',
          shopId: 's1',
          drawId: 'd1',
          batchId: 'b1',
          series: 'KR',
          number: '100001',
        ),
        const TicketItem(
          id: 't2',
          shopId: 's1',
          drawId: 'd1',
          batchId: 'b1',
          series: 'KR',
          number: '100002',
          status: TicketStatus.withSeller,
          sellerId: 'sel-1',
        ),
        const TicketItem(
          id: 't3',
          shopId: 's1',
          drawId: 'd1',
          batchId: 'b1',
          series: 'KR',
          number: '100003',
        ),
      ];

      final List<TicketItem>? picked = LedgerMath.pickNextInStockTickets(
        tickets: tickets,
        count: 2,
      );
      expect(picked?.map((TicketItem t) => t.id).toList(), <String>['t1', 't3']);

      // Range 100001..100003 fails for IN_STOCK because 100002 is WITH_SELLER
      expect(
        LedgerMath.selectTicketsInRange(
          tickets: tickets,
          series: 'KR',
          startNumber: '100001',
          endNumber: '100003',
          requiredStatus: TicketStatus.inStock,
        ),
        isNull,
      );
    });

    test('filterAndSortSellers filters active vs inactive and sorts by highest due', () {
      final DateTime now = DateTime.utc(2026, 11, 13);
      final List<SellerSummary> list = <SellerSummary>[
        SellerSummary(
          seller: SellerProfile(
            id: 's1',
            shopId: 'shop-1',
            name: 'Babu',
            area: 'Aluva',
            isActive: true,
            createdAt: now,
          ),
          balancePaise: 50000,
          lastActivityAt: now,
        ),
        SellerSummary(
          seller: SellerProfile(
            id: 's2',
            shopId: 'shop-1',
            name: 'Anil',
            area: 'Kaloor',
            isActive: true,
            createdAt: now,
          ),
          balancePaise: 120000,
          lastActivityAt: now,
        ),
        SellerSummary(
          seller: SellerProfile(
            id: 's3',
            shopId: 'shop-1',
            name: 'Old Seller',
            isActive: false,
            createdAt: now,
          ),
          balancePaise: 200000,
          lastActivityAt: now,
        ),
      ];

      final List<SellerSummary> active = LedgerMath.filterAndSortSellers(
        sellers: list,
        searchQuery: '',
        sortMode: SellerSortMode.highestDue,
        showInactive: false,
      );
      expect(active.map((SellerSummary s) => s.seller.id).toList(), <String>[
        's2',
        's1',
      ]);

      final List<SellerSummary> inactive = LedgerMath.filterAndSortSellers(
        sellers: list,
        searchQuery: '',
        sortMode: SellerSortMode.highestDue,
        showInactive: true,
      );
      expect(inactive.map((SellerSummary s) => s.seller.id).toList(), <String>[
        's3',
      ]);
    });
  });

  group('Phase 3 — Property-Style 500-Step Khata Invariant & Atomic Rollback (A.7)', () {
    test('500 seeded random ledger operations always reconcile to exact sum of ledger_entries', () async {
      final FakeStockRepository stockRepo = FakeStockRepository();
      final FakeSellerRepository sellerRepo = FakeSellerRepository(stockRepo);

      final String draw1 = await stockRepo.createDraw(
        lotteryId: 'lot-1',
        drawDate: DateTime(2026, 11, 13),
        drawNumber: 'W-101',
        ticketPricePaise: 4000,
      );
      final String draw2 = await stockRepo.createDraw(
        lotteryId: 'lot-3',
        drawDate: DateTime(2026, 11, 14),
        drawNumber: 'FF-202',
        ticketPricePaise: 5000,
      );

      await stockRepo.createStockBatch(
        drawId: draw1,
        series: 'W',
        startNumber: '100001',
        endNumber: '100300',
      );
      await stockRepo.createStockBatch(
        drawId: draw2,
        series: 'FF',
        startNumber: '200001',
        endNumber: '200300',
      );

      final SellerProfile seller = await sellerRepo.saveSeller(
        name: 'Rajan',
        phone: '9876543210',
        area: 'Aluva',
      );

      final Map<String, LotteryDraw> drawsById = <String, LotteryDraw>{
        for (final LotteryDraw d in await stockRepo.fetchDraws()) d.id: d,
      };
      final List<String> drawIds = <String>[draw1, draw2];
      final Random rng = Random(42);

      for (int step = 0; step < 500; step++) {
        final int op = rng.nextInt(5);
        final String targetDrawId = drawIds[rng.nextInt(drawIds.length)];

        if (op == 0) {
          // Issue 1..3 IN_STOCK tickets
          final List<TicketItem> inStock = (await stockRepo
                  .fetchTicketsForDraw(targetDrawId))
              .where((TicketItem t) => t.status == TicketStatus.inStock)
              .take(1 + rng.nextInt(3))
              .toList();
          if (inStock.isNotEmpty) {
            await sellerRepo.issueTickets(
              sellerId: seller.id,
              drawId: targetDrawId,
              ticketIds: inStock.map((TicketItem t) => t.id).toList(),
            );
          }
        } else if (op == 1) {
          // Return 1..2 WITH_SELLER tickets
          final List<TicketItem> withSeller = (await sellerRepo
                  .fetchSellerTickets(seller.id))
              .where(
                (TicketItem t) =>
                    t.drawId == targetDrawId &&
                    t.status == TicketStatus.withSeller,
              )
              .take(1 + rng.nextInt(2))
              .toList();
          if (withSeller.isNotEmpty) {
            await sellerRepo.returnTickets(
              sellerId: seller.id,
              drawId: targetDrawId,
              ticketIds: withSeller.map((TicketItem t) => t.id).toList(),
            );
          }
        } else if (op == 2) {
          // Record payment
          final int amountPaise = (1 + rng.nextInt(50)) * 10000;
          await sellerRepo.recordPayment(
            sellerId: seller.id,
            amountPaise: amountPaise,
            method: PaymentMethod.values[rng.nextInt(PaymentMethod.values.length)],
          );
        } else if (op == 3) {
          // Record prize paid by seller
          final int amountPaise = (1 + rng.nextInt(20)) * 10000;
          await sellerRepo.recordPrizePaidBySeller(
            sellerId: seller.id,
            drawId: targetDrawId,
            amountPaise: amountPaise,
          );
        } else {
          // Reverse a random reversible entry
          final List<LedgerEntry> currentLedger =
              await sellerRepo.fetchSellerLedger(seller.id, limit: 10000);
          final List<LedgerEntry> reversible =
              currentLedger.where((LedgerEntry e) => e.canReverse).toList();
          if (reversible.isNotEmpty) {
            final LedgerEntry target =
                reversible[rng.nextInt(reversible.length)];
            await sellerRepo.reverseLedgerEntry(target.id);
          }
        }

        // Invariant check after every step
        final List<LedgerEntry> ledger =
            await sellerRepo.fetchSellerLedger(seller.id, limit: 10000);
        final int expectedSum =
            ledger.fold<int>(0, (int acc, LedgerEntry e) => acc + e.amountPaise);
        final List<SellerSummary> summaries =
            await sellerRepo.fetchSellersWithBalances();
        expect(summaries.single.balancePaise, expectedSum);

        final SellerBalanceBreakdown breakdown =
            LedgerMath.computeBalanceBreakdown(
          entries: ledger,
          drawsById: drawsById,
        );
        expect(breakdown.grandTotalPaise, expectedSum);
        final int sumOfParts = breakdown.drawRows.fold<int>(
              0,
              (int acc, DrawBreakdownRow r) => acc + r.netDrawPaise,
            ) +
            breakdown.paymentsTotalPaise +
            breakdown.generalAdjustmentsPaise;
        expect(sumOfParts, expectedSum);
      }
    });

    test('atomic rollback: failed RPCs leave ticket statuses and ledger entries unchanged', () async {
      final FakeStockRepository stockRepo = FakeStockRepository();
      final FakeSellerRepository sellerRepo = FakeSellerRepository(stockRepo);

      final String drawId = await stockRepo.createDraw(
        lotteryId: 'lot-1',
        drawDate: DateTime(2026, 11, 13),
        ticketPricePaise: 4000,
      );
      await stockRepo.createStockBatch(
        drawId: drawId,
        series: 'W',
        startNumber: '100001',
        endNumber: '100005',
      );
      final SellerProfile s1 = await sellerRepo.saveSeller(name: 'S1');
      final SellerProfile s2 = await sellerRepo.saveSeller(name: 'S2');

      final List<TicketItem> tickets =
          await stockRepo.fetchTicketsForDraw(drawId);
      await sellerRepo.issueTickets(
        sellerId: s1.id,
        drawId: drawId,
        ticketIds: <String>[tickets[0].id, tickets[1].id],
      );
      final int countBefore =
          (await sellerRepo.fetchSellerLedger(s1.id)).length;

      // Issuing partially unavailable tickets to s2 fails atomically
      await expectLater(
        () => sellerRepo.issueTickets(
          sellerId: s2.id,
          drawId: drawId,
          ticketIds: <String>[tickets[1].id, tickets[2].id],
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(await sellerRepo.fetchSellerLedger(s2.id), isEmpty);

      // Seller with ledger history cannot be deleted directly
      await expectLater(
        () => sellerRepo.deleteSeller(s1.id),
        throwsA(isA<PostgrestException>()),
      );
      expect((await sellerRepo.fetchSellerLedger(s1.id)).length, countBefore);
    });
  });

  group('Phase 3 — Sellers & SellerDetail Linked Reversal UI Test', () {
    testWidgets('Renders SellerDetailScreen with linked reversed pair and Reversed chip', (WidgetTester tester) async {
      final FakeStockRepository stockRepo = FakeStockRepository();
      final FakeSellerRepository sellerRepo = FakeSellerRepository(stockRepo);

      final SellerProfile seller = await sellerRepo.saveSeller(
        name: 'Kunjumon',
        area: 'Aluva',
      );
      final String payId = await sellerRepo.recordPayment(
        sellerId: seller.id,
        amountPaise: 50000,
        method: PaymentMethod.cash,
        note: 'Morning cash',
      );
      await sellerRepo.reverseLedgerEntry(payId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            stockRepositoryProvider.overrideWithValue(stockRepo),
            sellerRepositoryProvider.overrideWithValue(sellerRepo),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.build(
              brightness: Brightness.light,
              locale: const Locale('en'),
              largeText: false,
            ),
            home: SellerDetailScreen(sellerId: seller.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kunjumon'), findsOneWidget);
      expect(find.text('Reversed'), findsOneWidget);
      expect(find.textContaining('Reverses earlier entry'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            stockRepositoryProvider.overrideWithValue(stockRepo),
            sellerRepositoryProvider.overrideWithValue(sellerRepo),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.build(
              brightness: Brightness.light,
              locale: const Locale('en'),
              largeText: false,
            ),
            home: const SellersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kunjumon'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);
    });
  });
}
