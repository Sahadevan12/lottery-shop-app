import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_ledger/core/theme/app_theme.dart';
import 'package:lucky_ledger/features/results/domain/prize_matcher.dart';
import 'package:lucky_ledger/features/results/domain/result_entities.dart';
import 'package:lucky_ledger/features/results/presentation/results_controller.dart';
import 'package:lucky_ledger/features/results/presentation/results_screen.dart';
import 'package:lucky_ledger/features/stock/domain/stock_entities.dart';
import 'package:lucky_ledger/features/stock/presentation/stock_controller.dart';
import 'package:lucky_ledger/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/fake_results_repository.dart';

void main() {
  const String shopId = 'shop-1';
  const String drawId = 'draw-1';

  final List<DrawPrizeTier> standardTiers = <DrawPrizeTier>[
    const DrawPrizeTier(
      id: 'tier-1',
      drawId: drawId,
      tierOrder: 1,
      label: '1st Prize',
      amountPaise: 800000000,
      matchType: PrizeMatchType.full,
    ),
    const DrawPrizeTier(
      id: 'tier-con',
      drawId: drawId,
      tierOrder: 2,
      label: 'Consolation',
      amountPaise: 800000,
      matchType: PrizeMatchType.consolation,
    ),
    const DrawPrizeTier(
      id: 'tier-4th',
      drawId: drawId,
      tierOrder: 3,
      label: '4th Prize',
      amountPaise: 500000,
      matchType: PrizeMatchType.last4,
    ),
    const DrawPrizeTier(
      id: 'tier-8th',
      drawId: drawId,
      tierOrder: 4,
      label: '8th Prize',
      amountPaise: 10000,
      matchType: PrizeMatchType.last3,
    ),
  ];

  TicketItem makeTicket(
    String id,
    String series,
    String number, {
    TicketStatus status = TicketStatus.soldCounter,
    String? sellerId,
  }) {
    return TicketItem(
      id: id,
      shopId: shopId,
      drawId: drawId,
      batchId: 'batch-1',
      series: series,
      number: number,
      status: status,
      sellerId: sellerId,
    );
  }

  group('PrizeMatcher (§7.5 8 cases + Rules b, e)', () {
    test('Case 1 & 2: Full match wins 1st, other series same number wins auto-consolation', () {
      final List<WinningTicket> wins = PrizeMatcher.matchTickets(
        tickets: <TicketItem>[
          makeTicket('t1', 'KR', '482910'),
          makeTicket('t2', 'KS', '482910'),
        ],
        tiers: standardTiers,
        entries: const <ResultEntryInput>[
          ResultEntryInput(
            tierId: 'tier-1',
            winningSeries: 'KR',
            winningNumber: '482910',
          ),
        ],
      );

      expect(wins.length, 2);
      expect(wins[0].ticketId, 't1');
      expect(wins[0].tierId, 'tier-1');
      expect(wins[0].prizeAmountPaise, 800000000);
      expect(wins[1].ticketId, 't2');
      expect(wins[1].tierId, 'tier-con');
      expect(wins[1].prizeAmountPaise, 800000);
    });

    test('Case 3 & 4: LAST_4 and LAST_3 matching', () {
      final List<WinningTicket> wins = PrizeMatcher.matchTickets(
        tickets: <TicketItem>[
          makeTicket('t1', 'KA', '112910'),
          makeTicket('t2', 'KB', '999910'),
        ],
        tiers: standardTiers,
        entries: const <ResultEntryInput>[
          ResultEntryInput(tierId: 'tier-4th', winningNumber: '2910'),
          ResultEntryInput(tierId: 'tier-8th', winningNumber: '910'),
        ],
      );

      expect(wins.length, 2);
      expect(wins[0].ticketId, 't1');
      expect(wins[0].tierId, 'tier-4th');
      expect(wins[1].ticketId, 't2');
      expect(wins[1].tierId, 'tier-8th');
    });

    test('Case 5: Ticket matching multiple tiers gets highest prize only', () {
      final List<WinningTicket> wins = PrizeMatcher.matchTickets(
        tickets: <TicketItem>[makeTicket('t1', 'KR', '482910')],
        tiers: standardTiers,
        entries: const <ResultEntryInput>[
          ResultEntryInput(
            tierId: 'tier-1',
            winningSeries: 'KR',
            winningNumber: '482910',
          ),
          ResultEntryInput(tierId: 'tier-4th', winningNumber: '2910'),
          ResultEntryInput(tierId: 'tier-8th', winningNumber: '910'),
        ],
      );

      expect(wins.length, 1);
      expect(wins.first.tierId, 'tier-1');
    });

    test('Case 6: sold_by mapping for all 5 ticket statuses (Rule b)', () {
      final List<WinningTicket> wins = PrizeMatcher.matchTickets(
        tickets: <TicketItem>[
          makeTicket('t1', 'KR', '100910', status: TicketStatus.soldCounter),
          makeTicket(
            't2',
            'KR',
            '101910',
            status: TicketStatus.withSeller,
            sellerId: 'seller-1',
          ),
          makeTicket(
            't3',
            'KR',
            '102910',
            status: TicketStatus.soldBySeller,
            sellerId: 'seller-2',
          ),
          makeTicket('t4', 'KR', '103910', status: TicketStatus.inStock),
          makeTicket('t5', 'KR', '104910', status: TicketStatus.returnedUnsold),
        ],
        tiers: standardTiers,
        entries: const <ResultEntryInput>[
          ResultEntryInput(tierId: 'tier-8th', winningNumber: '910'),
        ],
        sellerNamesById: const <String, String>{
          'seller-1': 'Rajan',
          'seller-2': 'Mani',
        },
      );

      expect(wins.length, 5);
      expect(wins[0].soldBy, WinSoldBy.counter);
      expect(wins[0].claimStatus, WinClaimStatus.unclaimed);

      expect(wins[1].soldBy, WinSoldBy.seller);
      expect(wins[1].sellerId, 'seller-1');
      expect(wins[1].sellerName, 'Rajan');
      expect(wins[1].claimStatus, WinClaimStatus.unclaimed);

      expect(wins[2].soldBy, WinSoldBy.seller);
      expect(wins[2].sellerId, 'seller-2');

      expect(wins[3].soldBy, WinSoldBy.unsold);
      expect(wins[3].sellerId, isNull);
      expect(wins[3].claimStatus, WinClaimStatus.unsoldWin);

      expect(wins[4].soldBy, WinSoldBy.unsold);
      expect(wins[4].claimStatus, WinClaimStatus.unsoldWin);
    });

    test('Case 7 & 8: Non-matching tickets and series-only mismatch without consolation', () {
      final List<DrawPrizeTier> fullOnly = <DrawPrizeTier>[standardTiers.first];
      final List<WinningTicket> wins = PrizeMatcher.matchTickets(
        tickets: <TicketItem>[
          makeTicket('t1', 'KS', '482910'),
          makeTicket('t2', 'KR', '111111'),
        ],
        tiers: fullOnly,
        entries: const <ResultEntryInput>[
          ResultEntryInput(
            tierId: 'tier-1',
            winningSeries: 'KR',
            winningNumber: '482910',
          ),
        ],
      );

      expect(wins, isEmpty);
    });
  });

  group('ResultEntryValidator (Rule f)', () {
    test('validates FULL, LAST_4, LAST_3 and flags duplicates', () {
      expect(
        ResultEntryValidator.validate(
          matchType: PrizeMatchType.full,
          series: 'KR',
          number: '482910',
        ),
        isNull,
      );
      expect(
        ResultEntryValidator.validate(
          matchType: PrizeMatchType.full,
          series: 'K',
          number: '482910',
        ),
        ResultEntryValidationError.invalidFull,
      );
      expect(
        ResultEntryValidator.validate(
          matchType: PrizeMatchType.last4,
          number: '291',
        ),
        ResultEntryValidationError.invalidLast4,
      );
      expect(
        ResultEntryValidator.validate(
          matchType: PrizeMatchType.last3,
          number: '910',
        ),
        isNull,
      );

      final Set<int> dups = ResultEntryValidator.findDuplicateIndexes(
        matchType: PrizeMatchType.last4,
        entries: const <({String? series, String number})>[
          (series: null, number: '2910'),
          (series: null, number: '4455'),
          (series: null, number: '2910'),
        ],
      );
      expect(dups, <int>{2});
    });
  });

  group('FakeResultsRepository & 3000-ticket batch', () {
    test('3000-ticket batch summary & previewTickets count == 3000', () async {
      final FakeStockRepository stockRepo = FakeStockRepository();
      final List<LotteryItem> lotteries = await stockRepo.fetchLotteries();
      final List<PrizeTemplate> templates = await stockRepo.fetchPrizeTemplates();
      final String createdDrawId = await stockRepo.createDraw(
        lotteryId: lotteries.first.id,
        drawDate: DateTime(2026, 11, 13),
        drawNumber: 'KR-900',
        ticketPricePaise: 4000,
        templateId: templates.first.id,
      );

      await stockRepo.createStockBatch(
        drawId: createdDrawId,
        series: 'KR',
        startNumber: '100000',
        endNumber: '102999',
        costPerTicketPaise: 3200,
      );

      final List<StockBatch> batches =
          await stockRepo.fetchBatchesForDraw(createdDrawId);
      expect(batches.single.quantity, 3000);

      final TicketRangePreview preview = await stockRepo.previewTickets(
        drawId: createdDrawId,
        mode: 'COUNT',
        count: 3000,
        series: 'KR',
        status: TicketStatus.inStock,
      );
      expect(preview.totalCount, 3000);
    });

    test('CLAIMED_WIN_AFFECTED blocks without force and succeeds with force=true', () async {
      final FakeStockRepository stockRepo = FakeStockRepository();
      final FakeResultsRepository resultsRepo = FakeResultsRepository(stockRepo);
      final List<LotteryItem> lotteries = await stockRepo.fetchLotteries();
      final List<PrizeTemplate> templates = await stockRepo.fetchPrizeTemplates();
      final String createdDrawId = await stockRepo.createDraw(
        lotteryId: lotteries.first.id,
        drawDate: DateTime(2026, 11, 13),
        drawNumber: 'KR-901',
        ticketPricePaise: 4000,
        templateId: templates.first.id,
      );
      resultsRepo.seedPrizeTiers(createdDrawId, standardTiers);

      await stockRepo.createStockBatch(
        drawId: createdDrawId,
        series: 'KR',
        startNumber: '482910',
        endNumber: '482915',
        costPerTicketPaise: 3200,
      );
      await stockRepo.markCounterSold(
        drawId: createdDrawId,
        series: 'KR',
        startNumber: '482910',
        endNumber: '482915',
      );

      final int count1 = await resultsRepo.saveDrawResultsAndCheck(
        drawId: createdDrawId,
        entries: const <ResultEntryInput>[
          ResultEntryInput(
            tierId: 'tier-1',
            winningSeries: 'KR',
            winningNumber: '482910',
          ),
        ],
      );
      expect(count1, 1);

      final List<WinningTicket> wins =
          await resultsRepo.fetchWinsForDraw(createdDrawId);
      await resultsRepo.updateWinClaimStatus(
        winId: wins.first.id,
        status: WinClaimStatus.paidToCustomer,
      );

      await expectLater(
        resultsRepo.saveDrawResultsAndCheck(
          drawId: createdDrawId,
          entries: const <ResultEntryInput>[
            ResultEntryInput(
              tierId: 'tier-1',
              winningSeries: 'KR',
              winningNumber: '482915',
            ),
          ],
        ),
        throwsA(
          isA<PostgrestException>().having(
            (PostgrestException e) => e.message,
            'message',
            'CLAIMED_WIN_AFFECTED',
          ),
        ),
      );

      final int count2 = await resultsRepo.saveDrawResultsAndCheck(
        drawId: createdDrawId,
        entries: const <ResultEntryInput>[
          ResultEntryInput(
            tierId: 'tier-1',
            winningSeries: 'KR',
            winningNumber: '482915',
          ),
        ],
        force: true,
      );
      expect(count2, 1);
    });
  });

  testWidgets('ResultsScreen renders verify note and empty CTA for upcoming draw', (
    WidgetTester tester,
  ) async {
    final FakeStockRepository stockRepo = FakeStockRepository();
    final FakeResultsRepository resultsRepo = FakeResultsRepository(stockRepo);
    final List<LotteryItem> lotteries = await stockRepo.fetchLotteries();
    final List<PrizeTemplate> templates = await stockRepo.fetchPrizeTemplates();
    await stockRepo.createDraw(
      lotteryId: lotteries.first.id,
      drawDate: DateTime(2026, 11, 13),
      drawNumber: 'KR-902',
      ticketPricePaise: 4000,
      templateId: templates.first.id,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          stockRepositoryProvider.overrideWithValue(stockRepo),
          resultsRepositoryProvider.overrideWithValue(resultsRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.build(
            brightness: Brightness.light,
            locale: const Locale('en'),
            largeText: false,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ResultsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Verify with official Kerala State Lotteries result before paying out.',
      ),
      findsOneWidget,
    );
    expect(find.text('Enter draw results'), findsOneWidget);
  });
}
