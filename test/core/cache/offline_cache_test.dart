import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_ledger/core/cache/app_cache_db.dart';
import 'package:lucky_ledger/core/network/connectivity_service.dart';
import 'package:lucky_ledger/core/theme/app_theme.dart';
import 'package:lucky_ledger/core/ui/app_button.dart';
import 'package:lucky_ledger/core/ui/offline_banner.dart';
import 'package:lucky_ledger/features/auth/data/auth_repository.dart';
import 'package:lucky_ledger/features/auth/domain/shop_profile.dart';
import 'package:lucky_ledger/features/auth/presentation/auth_controller.dart';
import 'package:lucky_ledger/features/home/data/home_repository.dart';
import 'package:lucky_ledger/features/home/presentation/home_controller.dart';
import 'package:lucky_ledger/features/home/presentation/home_screen.dart';
import 'package:lucky_ledger/features/sellers/presentation/sellers_controller.dart';
import 'package:lucky_ledger/features/settings/presentation/app_preferences_controller.dart';
import 'package:lucky_ledger/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/fake_seller_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.userId = 'user-a', this.shop});

  final String? userId;
  final ShopProfile? shop;
  bool signedOut = false;

  @override
  String? get currentUserId => signedOut ? null : userId;

  @override
  String? get currentPhone => '9876543210';

  @override
  Future<ShopProfile> createShopWithDefaults({
    required String name,
    required String ownerName,
    required String district,
    String? agentCode,
    required String language,
  }) async {
    return shop!;
  }

  @override
  Future<ShopProfile?> fetchCurrentShop() async => shop;

  @override
  Future<void> signInOrSignUp({
    required String phone,
    required String pin,
  }) async {}

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class _ToggleOfflineHomeRepository implements HomeRepository {
  _ToggleOfflineHomeRepository(this._data);

  final DashboardTodayData _data;
  bool throwOffline = false;

  @override
  Future<DashboardTodayData> fetchDashboardToday() async {
    if (throwOffline) {
      throw const SocketException('Network unreachable');
    }
    return _data;
  }
}

void main() {
  group('Read-only offline cache', () {
    test('scopes snapshots by user id so user B cannot read user A data',
        () async {
      final AppCacheDb db = AppCacheDb.inMemory();
      addTearDown(db.close);

      await db.putJson(
        userId: 'user-a',
        key: 'dashboard_today',
        value: <String, dynamic>{'in_stock_count': 42},
        now: DateTime(2026, 11, 14, 15, 30),
      );

      final userAData =
          await db.getJson(userId: 'user-a', key: 'dashboard_today');
      final userBData =
          await db.getJson(userId: 'user-b', key: 'dashboard_today');

      expect(userAData, isNotNull);
      expect((userAData!.data as Map<String, dynamic>)['in_stock_count'], 42);
      expect(userBData, isNull);
    });

    test(
        'signOut clears AppCacheDb and user prefs while keeping device preferences',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pref_last_cost_per_ticket_paise': 3800,
        'pref_locale': 'ta',
        'pref_theme': 'dark',
        'pref_large_text': true,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppCacheDb db = AppCacheDb.inMemory();
      addTearDown(db.close);

      await db.putJson(
        userId: 'user-a',
        key: 'sellers_summaries',
        value: <dynamic>[],
      );

      final _FakeAuthRepository fakeAuthRepo = _FakeAuthRepository(
        userId: 'user-a',
        shop: const ShopProfile(
          id: 'shop-1',
          ownerId: 'user-a',
          name: 'Kaveri Agency',
          ownerName: 'Ravi',
          phone: '9876543210',
          district: 'Ernakulam',
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appCacheDbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(
        await db.getJson(userId: 'user-a', key: 'sellers_summaries'),
        isNull,
      );
      expect(prefs.getInt('pref_last_cost_per_ticket_paise'), isNull);
      expect(prefs.getString('pref_locale'), 'ta');
      expect(prefs.getString('pref_theme'), 'dark');
      expect(prefs.getBool('pref_large_text'), isTrue);
      expect(fakeAuthRepo.signedOut, isTrue);
    });

    testWidgets(
      'caches online home data, shows OfflineBanner on SocketException, and disables write buttons',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppCacheDb db = AppCacheDb.inMemory();
        addTearDown(db.close);

        final _ToggleOfflineHomeRepository homeRepo =
            _ToggleOfflineHomeRepository(
          DashboardTodayData(
            todayDate: DateTime(2026, 11, 14),
            drawsCount: 1,
            inStockCount: 120,
            withSellerCount: 80,
            soldCounterCount: 40,
            soldSellerCount: 60,
            returnedCount: 10,
            totalTickets: 310,
            todayWinsCount: 2,
            todayPrizesTotal: 5000,
            unclaimedWinsCount: 1,
            totalDueFromSellers: 4200,
            toRecoverFromOffice: 3000,
          ),
        );

        final _FakeAuthRepository fakeAuthRepo = _FakeAuthRepository(
          userId: 'user-a',
          shop: const ShopProfile(
            id: 'shop-1',
            ownerId: 'user-a',
            name: 'Kaveri Agency',
            ownerName: 'Ravi',
            phone: '9876543210',
            district: 'Ernakulam',
          ),
        );

        final FakeSellerRepository sellerRepo =
            FakeSellerRepository(FakeStockRepository());
        await sellerRepo.saveSeller(name: 'Raju', phone: '9876543211');

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              appCacheDbProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              homeRepositoryProvider.overrideWithValue(homeRepo),
              sellerRepositoryProvider.overrideWithValue(sellerRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.build(
                brightness: Brightness.light,
                locale: const Locale('en'),
                largeText: false,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: HomeScreen(onGoToStock: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final Element element = tester.element(find.byType(HomeScreen));
        final ProviderContainer container =
            ProviderScope.containerOf(element, listen: false);

        expect(container.read(isOnlineProvider), isTrue);
        expect(find.byType(OfflineBanner), findsNothing);

        // Now go offline and trigger a refresh.
        homeRepo.throwOffline = true;
        await container.read(homeControllerProvider.notifier).refresh();
        await tester.pumpAndSettle();

        expect(container.read(isOnlineProvider), isFalse);
        expect(container.read(homeControllerProvider).isFromCache, isTrue);
        expect(find.byType(OfflineBanner), findsOneWidget);
        expect(
          find.textContaining('Offline — showing data from'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Internet connection required for this action.'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text('Internet connection required for this action.'),
          findsOneWidget,
        );

        final AppButton giveBtn = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Give tickets'),
        );
        final AppButton payBtn = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Record payment'),
        );
        expect(giveBtn.onPressed, isNull);
        expect(payBtn.onPressed, isNull);

        // Now come back online and trigger refresh / Retry:
        // write buttons must re-enable and OfflineBanner must disappear.
        homeRepo.throwOffline = false;
        await container.read(homeControllerProvider.notifier).refresh();
        await tester.pumpAndSettle();

        expect(container.read(isOnlineProvider), isTrue);
        expect(container.read(homeControllerProvider).isFromCache, isFalse);
        expect(find.byType(OfflineBanner), findsNothing);
        expect(
          find.text('Internet connection required for this action.'),
          findsNothing,
        );

        final AppButton giveBtnOnline = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Give tickets'),
        );
        final AppButton payBtnOnline = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Record payment'),
        );
        expect(giveBtnOnline.onPressed, isNotNull);
        expect(payBtnOnline.onPressed, isNotNull);
      },
    );

    testWidgets(
      'periodic 15s reachability check automatically recovers online state',
      (WidgetTester tester) async {
        bool networkReachable = false;
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            enablePeriodicOfflineProbeProvider.overrideWithValue(true),
            reachabilityProbeProvider.overrideWithValue(
              () async => networkReachable,
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(isOnlineProvider.notifier).markOffline();
        expect(container.read(isOnlineProvider), isFalse);

        // After 15s while still unreachable, stays offline.
        await tester.pump(const Duration(seconds: 15));
        expect(container.read(isOnlineProvider), isFalse);

        // Network returns; next 15s tick restores online state and cancels timer.
        networkReachable = true;
        await tester.pump(const Duration(seconds: 15));
        expect(container.read(isOnlineProvider), isTrue);
      },
    );
  });
}
