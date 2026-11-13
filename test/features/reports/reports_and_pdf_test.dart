import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_ledger/core/pdf/pdf_font_loader.dart';
import 'package:lucky_ledger/core/theme/app_theme.dart';
import 'package:lucky_ledger/features/auth/presentation/auth_controller.dart';
import 'package:lucky_ledger/features/home/presentation/home_controller.dart';
import 'package:lucky_ledger/features/home/presentation/home_screen.dart';
import 'package:lucky_ledger/features/reports/domain/report_entities.dart';
import 'package:lucky_ledger/features/reports/presentation/reports_controller.dart';
import 'package:lucky_ledger/features/reports/presentation/reports_pdf_share.dart';
import 'package:lucky_ledger/features/reports/presentation/reports_screen.dart';
import 'package:lucky_ledger/features/results/domain/result_entities.dart';
import 'package:lucky_ledger/features/results/presentation/winner_poster_share.dart';
import 'package:lucky_ledger/features/sellers/domain/seller_entities.dart';
import 'package:lucky_ledger/features/sellers/presentation/sellers_controller.dart';
import 'package:lucky_ledger/features/sellers/presentation/seller_statement_share.dart';
import 'package:lucky_ledger/features/settings/presentation/app_preferences_controller.dart';
import 'package:lucky_ledger/features/stock/domain/stock_entities.dart';
import 'package:lucky_ledger/features/stock/presentation/stock_controller.dart';
import 'package:lucky_ledger/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_home_reports_repository.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/fake_seller_repository.dart';

void main() {
  Future<Widget> wrapApp({
    required Widget child,
    List<Override> overrides = const <Override>[],
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final FakeAuthRepository fakeAuth = FakeAuthRepository();
    await fakeAuth.signInOrSignUp(phone: '9876543210', pin: '123456');
    await fakeAuth.createShopWithDefaults(
      name: 'Sree Lakshmi Lottery',
      ownerName: 'Dev',
      district: 'Ernakulam',
      language: 'en',
    );
    final FakeStockRepository fakeStock = FakeStockRepository();

    return ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        stockRepositoryProvider.overrideWithValue(fakeStock),
        sellerRepositoryProvider.overrideWithValue(
          FakeSellerRepository(fakeStock),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.build(
          brightness: Brightness.light,
          locale: locale,
          largeText: false,
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('P&L model & ReportsController', () {
    test(
      'calculates Sales - StockCost + UnsoldPrizeGain without subtracting customer prizes',
      () {
        final ReportsSummaryData summary =
            FakeReportsRepository.defaultSampleSummary();
        expect(summary.totalSales, 3200);
        expect(summary.totalStockCost, 3200);
        expect(summary.totalGrossMargin, 0);
        expect(summary.totalUnsoldPrizeGain, 500);
        expect(summary.totalNetProfit, 500);
        expect(summary.totalToRecoverFromOffice, 5000);
        expect(summary.toCollectFromSellers, 1800);
      },
    );

    test('rejects custom range > 366 days with RANGE_TOO_LARGE', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          reportsRepositoryProvider.overrideWithValue(FakeReportsRepository()),
        ],
      );
      addTearDown(container.dispose);

      final ReportsController ctrl =
          container.read(reportsControllerProvider.notifier);
      await ctrl.selectCustomRange(
        DateTime(2025, 1, 1),
        DateTime(2026, 2, 1),
      );
      final ReportsState state = container.read(reportsControllerProvider);
      expect(state.error.toString(), contains('RANGE_TOO_LARGE'));
    });
  });

  group('Winner Poster', () {
    test('maskTicketNumber masks digits after first 2 characters', () {
      expect(WinnerPosterShare.maskTicketNumber('482910'), '48****');
      expect(WinnerPosterShare.maskTicketNumber('1234'), '12**');
      expect(WinnerPosterShare.maskTicketNumber('12'), '**');
    });

    testWidgets(
      'WinnerPosterSheet defaults masking ON and renders 3 templates',
      (WidgetTester tester) async {
        final LotteryDraw draw = LotteryDraw(
          id: 'd1',
          shopId: 'shop-1',
          lotteryId: 'lot-1',
          lotteryName: 'Karunya',
          drawNumber: 'KR-701',
          drawDate: DateTime(2026, 11, 13),
          ticketPricePaise: 4000,
          status: DrawStatus.resultEntered,
        );
        final List<WinningTicket> wins = <WinningTicket>[
          WinningTicket(
            id: 'w1',
            shopId: 'shop-1',
            drawId: 'd1',
            ticketId: 't1',
            ticketSeries: 'KR',
            ticketNumber: '482910',
            tierId: 'tier1',
            tierOrder: 1,
            tierLabel: '1st Prize',
            prizeAmountPaise: 800000000,
            soldBy: WinSoldBy.counter,
            claimStatus: WinClaimStatus.unclaimed,
            createdAt: DateTime(2026, 11, 13),
          ),
        ];

        await tester.pumpWidget(
          await wrapApp(
            child: Scaffold(
              body: WinnerPosterSheet(draw: draw, wins: wins),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('KR 48****', findRichText: true), findsOneWidget);
        expect(find.text('KR 482910', findRichText: true), findsNothing);
        expect(find.text('Classic Gold'), findsOneWidget);
        expect(find.text('Calm Emerald'), findsOneWidget);
        expect(find.text('Festive Banner'), findsOneWidget);
      },
    );
  });

  group('HomeScreen & ReportsScreen widgets', () {
    testWidgets(
      'HomeScreen displays dashboard_today() stats & wins banner',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          await wrapApp(
            overrides: <Override>[
              homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
            ],
            child: HomeScreen(onGoToStock: () {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('120'), findsOneWidget);
        expect(find.text('80'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(find.textContaining('3 wins today'), findsOneWidget);
        expect(find.text('To recover from office'), findsOneWidget);
      },
    );

    testWidgets(
      'HomeScreen shows error state with Retry (not zeros) when SupabaseClient is missing',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          await wrapApp(
            child: HomeScreen(onGoToStock: () {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('0'), findsNothing);
      },
    );

    testWidgets(
      'ReportsScreen shows P&L figures and formula sheet on tap',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          await wrapApp(
            overrides: <Override>[
              reportsRepositoryProvider
                  .overrideWithValue(FakeReportsRepository()),
            ],
            child: const ReportsScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total sales'), findsOneWidget);
        expect(find.text('Net profit'), findsOneWidget);
        expect(find.text('Karunya (KR-701)'), findsOneWidget);

        await tester.tap(find.text('Net profit'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('customer prizes are paid by the Lottery Dept'),
          findsOneWidget,
        );
      },
    );
  });

  group('Multilingual PDF generation (en, ml, ta) & build/samples output', () {
    test(
      'generates valid statement & report PDFs in en, ml, ta and writes build/samples',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        final SellerProfile seller = SellerProfile(
          id: 's1',
          shopId: 'shop-1',
          name: 'Ravi Kumar',
          phone: '9876543210',
          area: 'Palayam',
          createdAt: DateTime(2026, 11, 1),
        );
        const SellerBalanceBreakdown breakdown = SellerBalanceBreakdown(
          grandTotalPaise: 180000,
        );
        final List<LedgerEntry> entries = <LedgerEntry>[
          LedgerEntry(
            id: 'e1',
            shopId: 'shop-1',
            sellerId: 's1',
            type: LedgerEntryType.issue,
            amountPaise: 320000,
            ticketCount: 100,
            note: 'Karunya KR-701',
            createdAt: DateTime(2026, 11, 12),
          ),
          LedgerEntry(
            id: 'e2',
            shopId: 'shop-1',
            sellerId: 's1',
            type: LedgerEntryType.payment,
            amountPaise: -140000,
            paymentMethod: PaymentMethod.cash,
            note: 'Cash received',
            createdAt: DateTime(2026, 11, 12),
          ),
        ];
        final ReportsSummaryData reportSummary =
            FakeReportsRepository.defaultSampleSummary();

        final Directory samplesDir = Directory('build/samples');
        await samplesDir.create(recursive: true);

        // Provide a fast 2x2 RGBA stub in headless flutter_test where
        // ui.Image.toByteData has no rasterizer surface.
        PdfFontLoader.testIndicRenderer = ({
          required String title,
          required String subtitle,
          required List<PdfIndicRow> rows,
          String? sectionHeading,
          List<PdfIndicRow> secondaryRows = const <PdfIndicRow>[],
          String? footer,
          required String languageCode,
        }) async {
          expect(title, isNotEmpty);
          expect(rows, isNotEmpty);
          return PdfIndicImage(
            rgbaBytes: Uint8List.fromList(List<int>.filled(2 * 2 * 4, 255)),
            width: 2,
            height: 2,
          );
        };
        addTearDown(() => PdfFontLoader.testIndicRenderer = null);

        for (final String code in <String>['en', 'ml', 'ta']) {
          final Locale locale = Locale(code);
          final AppLocalizations l10n = lookupAppLocalizations(locale);

          final Uint8List stmtBytes = await SellerStatementShare.buildPdfBytes(
            seller: seller,
            breakdown: breakdown,
            entries: entries,
            l10n: l10n,
            locale: locale,
          );
          expect(stmtBytes.length, greaterThan(500));
          expect(String.fromCharCodes(stmtBytes.take(5)), '%PDF-');

          final Uint8List reportBytes = await ReportsPdfShare.buildPdfBytes(
            summary: reportSummary,
            l10n: l10n,
            locale: locale,
            shopName: 'Sree Lakshmi Lottery',
          );
          expect(reportBytes.length, greaterThan(500));
          expect(String.fromCharCodes(reportBytes.take(5)), '%PDF-');

          if (code == 'ml' || code == 'ta') {
            await File('${samplesDir.path}/statement_$code.pdf')
                .writeAsBytes(stmtBytes, flush: true);
            await File('${samplesDir.path}/report_$code.pdf')
                .writeAsBytes(reportBytes, flush: true);
          }
        }

        expect(File('build/samples/statement_ml.pdf').existsSync(), isTrue);
        expect(File('build/samples/statement_ta.pdf').existsSync(), isTrue);
        expect(File('build/samples/report_ml.pdf').existsSync(), isTrue);
        expect(File('build/samples/report_ta.pdf').existsSync(), isTrue);
      },
    );
  });
}
