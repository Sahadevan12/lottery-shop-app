import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_ledger/app/main_shell_screen.dart';
import 'package:lucky_ledger/core/theme/app_theme.dart';
import 'package:lucky_ledger/features/auth/presentation/auth_controller.dart';
import 'package:lucky_ledger/features/sellers/presentation/sellers_controller.dart';
import 'package:lucky_ledger/features/settings/presentation/app_preferences_controller.dart';
import 'package:lucky_ledger/features/stock/domain/stock_entities.dart';
import 'package:lucky_ledger/features/stock/domain/stock_range_logic.dart';
import 'package:lucky_ledger/features/stock/presentation/add_stock_sheet.dart';
import 'package:lucky_ledger/features/stock/presentation/create_draw_sheet.dart';
import 'package:lucky_ledger/features/stock/presentation/stock_controller.dart';
import 'package:lucky_ledger/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/fake_seller_repository.dart';

void main() {
  group('Phase 2 — StockRangeLogic Pure Unit Tests (§7.1)', () {
    test('calculates inclusive quantity, zero-pads, and computes total cost in paise', () {
      final StockRangeEvaluation eval = StockRangeLogic.evaluateRange(
        series: 'kr',
        startNumber: '123',
        endNumber: '222',
        costPerTicketPaise: 3500,
      );
      expect(eval.isValid, isTrue);
      expect(eval.normalizedSeries, 'KR');
      expect(eval.paddedStart, '000123');
      expect(eval.paddedEnd, '000222');
      expect(eval.quantity, 100);
      expect(eval.totalCostPaise, 350000);
    });

    test('rejects end < start, > 5000 batch size, and invalid series', () {
      final StockRangeEvaluation endBeforeStart = StockRangeLogic.evaluateRange(
        series: 'KR',
        startNumber: '482999',
        endNumber: '482900',
      );
      expect(endBeforeStart.isValid, isFalse);
      expect(endBeforeStart.error, StockRangeError.endBeforeStart);

      final StockRangeEvaluation tooBig = StockRangeLogic.evaluateRange(
        series: 'KR',
        startNumber: '000001',
        endNumber: '005001',
      );
      expect(tooBig.isValid, isFalse);
      expect(tooBig.error, StockRangeError.exceedsMaxBatchSize);

      final StockRangeEvaluation badSeries = StockRangeLogic.evaluateRange(
        series: 'KRLA',
        startNumber: '482900',
        endNumber: '482999',
      );
      expect(badSeries.isValid, isFalse);
      expect(badSeries.error, StockRangeError.invalidSeries);
    });

    test('detects overlapping ranges in same series and allows non-overlapping or other series', () {
      const List<StockBatch> existing = <StockBatch>[
        StockBatch(
          id: 'b1',
          shopId: 'shop-1',
          drawId: 'd1',
          series: 'KR',
          startNumber: '482900',
          endNumber: '482999',
          quantity: 100,
          inStockCount: 100,
        ),
      ];

      // Partial overlap
      expect(
        StockRangeLogic.findOverlappingRange(
          series: 'KR',
          startNumber: '482950',
          endNumber: '483049',
          existingBatches: existing,
        ),
        'KR 482950–482999',
      );

      // Same numbers but different series -> allowed
      expect(
        StockRangeLogic.findOverlappingRange(
          series: 'WN',
          startNumber: '482900',
          endNumber: '482999',
          existingBatches: existing,
        ),
        isNull,
      );

      // Adjacent range -> allowed
      expect(
        StockRangeLogic.findOverlappingRange(
          series: 'KR',
          startNumber: '483000',
          endNumber: '483099',
          existingBatches: existing,
        ),
        isNull,
      );
    });
  });

  group('Phase 2 — RPC Constraints & Error Guardrails', () {
    test('enforces DRAW_EXISTS, STOCK_OVERLAP, DRAW_NOT_OPEN, and BATCH_IN_USE', () async {
      final FakeStockRepository repo = FakeStockRepository();
      final DateTime today = DateTime(2026, 11, 12);

      final String drawId = await repo.createDraw(
        lotteryId: 'lot-4',
        drawDate: today,
        drawNumber: 'KN-500',
        ticketPricePaise: 4000,
      );

      // Duplicate draw for same lottery + date -> DRAW_EXISTS
      await expectLater(
        () => repo.createDraw(
          lotteryId: 'lot-4',
          drawDate: today,
          ticketPricePaise: 4000,
        ),
        throwsA(
          isA<PostgrestException>().having(
            (PostgrestException e) => e.message,
            'message',
            'DRAW_EXISTS',
          ),
        ),
      );

      // Create batch 1
      final String batchId = await repo.createStockBatch(
        drawId: drawId,
        series: 'KN',
        startNumber: '100000',
        endNumber: '100099',
        costPerTicketPaise: 3500,
      );

      // Overlap -> STOCK_OVERLAP
      await expectLater(
        () => repo.createStockBatch(
          drawId: drawId,
          series: 'KN',
          startNumber: '100050',
          endNumber: '100149',
        ),
        throwsA(
          isA<PostgrestException>().having(
            (PostgrestException e) => e.message,
            'message',
            'STOCK_OVERLAP',
          ),
        ),
      );

      // Mark 1 ticket as WITH_SELLER -> delete_stock_batch raises BATCH_IN_USE
      repo.markTicketStatus(batchId, '100000', TicketStatus.withSeller);
      await expectLater(
        () => repo.deleteStockBatch(batchId),
        throwsA(
          isA<PostgrestException>().having(
            (PostgrestException e) => e.message,
            'message',
            'BATCH_IN_USE',
          ),
        ),
      );

      // Return ticket to IN_STOCK -> delete_stock_batch succeeds
      repo.markTicketStatus(batchId, '100000', TicketStatus.inStock);
      await repo.deleteStockBatch(batchId);
      expect(await repo.fetchBatchesForDraw(drawId), isEmpty);

      // Draw status RESULT_ENTERED -> create_stock_batch raises DRAW_NOT_OPEN
      repo.setDrawStatus(drawId, DrawStatus.resultEntered);
      await expectLater(
        () => repo.createStockBatch(
          drawId: drawId,
          series: 'KN',
          startNumber: '200000',
          endNumber: '200099',
        ),
        throwsA(
          isA<PostgrestException>().having(
            (PostgrestException e) => e.message,
            'message',
            'DRAW_NOT_OPEN',
          ),
        ),
      );
    });
  });

  group('Phase 2 — Stock UI Flow (Create Today Draw + Add 3 Ranges)', () {
    testWidgets(
      'Shows Create Today Draw when no draw exists, then adds 3 ranges and updates Stock & Home counts',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final FakeAuthRepository fakeAuth = FakeAuthRepository();
        await fakeAuth.signInOrSignUp(phone: '9876543210', pin: '123456');
        await fakeAuth.createShopWithDefaults(
          name: 'Lakshmi Lotteries',
          ownerName: 'Ramesh',
          district: 'Ernakulam',
          language: 'en',
        );
        final FakeStockRepository fakeStock = FakeStockRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(fakeAuth),
              stockRepositoryProvider.overrideWithValue(fakeStock),
              sellerRepositoryProvider.overrideWithValue(
                FakeSellerRepository(fakeStock),
              ),
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
              home: const MainShellScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Stock tab (tab 2)
        await tester.tap(find.text('Stock'));
        await tester.pumpAndSettle();

        // Requirement #7: No auto-created draw -> shows "Create today's draw" card
        expect(find.text("Create today's draw"), findsWidgets);
        await tester.tap(find.text("Create today's draw").last);
        await tester.pumpAndSettle();

        // Confirm Create Draw in bottom sheet
        final Finder createDrawBtn = find.descendant(
          of: find.byType(CreateDrawSheet),
          matching: find.text('Create draw'),
        );
        await tester.ensureVisible(createDrawBtn);
        await tester.pumpAndSettle();
        await tester.tap(createDrawBtn);
        await tester.pumpAndSettle();

        // Helper to add a batch via the Add Stock Bottom Sheet
        Future<void> addRange(String series, String start, String end) async {
          ScaffoldMessenger.of(
            tester.element(find.byType(Scaffold).first),
          ).clearSnackBars();
          await tester.pumpAndSettle();

          final Finder addBtn = find.text('Add stock').last;
          await tester.ensureVisible(addBtn);
          await tester.tap(addBtn);
          await tester.pumpAndSettle();

          final Finder fields = find.descendant(
            of: find.byType(AddStockSheet),
            matching: find.byType(TextField),
          );
          await tester.enterText(fields.at(0), series);
          await tester.enterText(fields.at(2), start);
          await tester.enterText(fields.at(3), end);
          await tester.pump();

          final Finder saveBtn = find.descendant(
            of: find.byType(AddStockSheet),
            matching: find.text('Save'),
          );
          await tester.ensureVisible(saveBtn);
          await tester.pumpAndSettle();
          await tester.tap(saveBtn);
          await tester.pumpAndSettle();
        }

        // Add 3 ranges for today's draw: 100 + 50 + 25 = 175 tickets
        await addRange('KR', '482900', '482999');
        await addRange('KR', '483000', '483049');
        await addRange('WN', '100000', '100024');

        // Verify all 3 batch cards and total count = 175 on Stock tab
        expect(find.textContaining('WN 100000 – 100024'), findsOneWidget);
        expect(find.textContaining('KR 483000 – 483049'), findsOneWidget);
        expect(find.textContaining('KR 482900 – 482999'), findsOneWidget);
        expect(find.text('175'), findsWidgets);

        // Switch to Home tab -> verify In stock StatTile shows 175
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
        expect(find.text('175'), findsOneWidget);
      },
    );
  });
}
