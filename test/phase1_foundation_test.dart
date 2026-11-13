import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_ledger/app/app.dart';
import 'package:lucky_ledger/core/theme/app_theme.dart';
import 'package:lucky_ledger/core/ui/seller_avatar.dart';
import 'package:lucky_ledger/core/utils/formatters.dart';
import 'package:lucky_ledger/core/utils/validators.dart';
import 'package:lucky_ledger/features/auth/presentation/auth_controller.dart';
import 'package:lucky_ledger/features/settings/presentation/app_preferences_controller.dart';
import 'package:lucky_ledger/features/settings/presentation/design_preview_screen.dart';
import 'package:lucky_ledger/features/stock/presentation/stock_controller.dart';
import 'package:lucky_ledger/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_repositories.dart';

void main() {
  group('Phase 1 — Formatters & Validators', () {
    test('formats money in Indian numbering system (§4.3)', () {
      expect(AppFormatters.moneyFromRupees(123450), '₹1,23,450');
      expect(AppFormatters.moneyFromRupees(0), '₹0');
      expect(AppFormatters.moneyFromRupees(-2500), '−₹2,500');
      expect(
        AppFormatters.moneyFromDecimal(Decimal.parse('7500000.00')),
        '₹75,00,000',
      );
    });

    test('maps 10-digit phone to internal luckyledger.app email (§6.2)', () {
      expect(
        AppValidators.phoneToInternalEmail('98765 43210'),
        '9876543210@luckyledger.app',
      );
      expect(
        () => AppValidators.phoneToInternalEmail('12345'),
        throwsArgumentError,
      );
    });

    test('validates ticket series, numbers, and batch ranges (§5, §7.1)', () {
      expect(AppValidators.isValidSeries('KR'), isTrue);
      expect(AppValidators.isValidSeries('W'), isTrue);
      expect(AppValidators.isValidSeries('ABCD'), isFalse);

      expect(AppValidators.isValidTicketNumber('482913'), isTrue);
      expect(AppValidators.isValidTicketNumber('000123'), isTrue);
      expect(AppValidators.isValidTicketNumber('48291'), isFalse);

      expect(AppValidators.computeRangeQuantity('482900', '482999'), 100);
      expect(AppValidators.computeRangeQuantity('482999', '482900'), isNull);
      expect(AppValidators.computeRangeQuantity('000001', '006000'), isNull);
    });

    test('computes deterministic initials and palette index for SellerAvatar', () {
      expect(SellerAvatar.extractInitials('Ramesh Nair'), 'RN');
      expect(SellerAvatar.extractInitials('Babu'), 'BA');
      final int idx1 = SellerAvatar.paletteIndexForName('Ramesh Nair', 6);
      final int idx2 = SellerAvatar.paletteIndexForName('Ramesh Nair', 6);
      expect(idx1, equals(idx2));
      expect(idx1, inInclusiveRange(0, 5));
    });
  });

  group('Phase 1 — Onboarding & Design System Widget Tests', () {
    testWidgets(
      'Can pick Malayalam, view Welcome disclaimer, sign up, set up shop, and reach Home',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
              stockRepositoryProvider.overrideWithValue(FakeStockRepository()),
            ],
            child: const LuckyLedgerApp(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Language Picker Screen shown first, Malayalam selected by default
        expect(find.text('മലയാളം'), findsWidgets);
        await tester.tap(find.text('തുടരുക'));
        await tester.pumpAndSettle();

        // 2. Welcome Screen with mandatory legal disclaimer
        expect(find.text('ആരംഭിക്കുക'), findsOneWidget);
        await tester.tap(find.text('ആരംഭിക്കുക'));
        await tester.pumpAndSettle();

        // 3. Login Screen: enter 10-digit phone + 6-digit PIN via keypad
        await tester.enterText(find.byType(TextField).first, '9876543210');
        for (final String d in <String>['1', '2', '3', '4', '5', '6']) {
          final Finder digitFinder = find.text(d).first;
          await tester.ensureVisible(digitFinder);
          await tester.tap(digitFinder);
          await tester.pump();
        }
        final Finder signInBtn = find.text('പ്രവേശിക്കുക');
        await tester.ensureVisible(signInBtn);
        await tester.tap(signInBtn);
        await tester.pumpAndSettle();

        // 4. Shop Setup Screen: enter shop name, owner name, pick district
        final Finder textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'ശ്രീ ലക്ഷ്മി ഏജൻസീസ്');
        await tester.enterText(textFields.at(1), 'രമേശ്');
        await tester.ensureVisible(textFields.at(2));
        await tester.tap(textFields.at(2));
        await tester.pumpAndSettle();
        final Finder districtItem = find.text('എറണാകുളം').last;
        await tester.ensureVisible(districtItem);
        await tester.tap(districtItem);
        await tester.pumpAndSettle();

        final Finder startShopBtn = find.text('ഷോപ്പ് തുടങ്ങുക');
        await tester.ensureVisible(startShopBtn);
        await tester.tap(startShopBtn);
        await tester.pumpAndSettle();

        // 5. Empty Home Screen with 5-tab bottom nav
        expect(find.text('ശ്രീ ലക്ഷ്മി ഏജൻസീസ്'), findsOneWidget);
        expect(find.text('ഹോം'), findsOneWidget);
        expect(find.text('സ്റ്റോക്ക്'), findsOneWidget);
        expect(find.text('വില്പനക്കാർ'), findsOneWidget);
        expect(find.text('ഫലം'), findsOneWidget);
        expect(find.text('കൂടുതൽ'), findsOneWidget);
      },
    );

    testWidgets(
      'DesignPreviewScreen renders cleanly in Light, Dark, and 1.15x Large Text',
      (WidgetTester tester) async {
        for (final Brightness brightness in Brightness.values) {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                locale: const Locale('ml'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: AppTheme.build(
                  brightness: brightness,
                  locale: const Locale('ml'),
                  largeText: true,
                ),
                home: const DesignPreviewScreen(),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
