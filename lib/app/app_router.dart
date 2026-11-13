import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/shop_setup_screen.dart';
import '../features/onboarding/presentation/language_picker_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/sellers/presentation/seller_detail_screen.dart';
import '../features/sellers/presentation/sellers_screen.dart';
import '../features/settings/domain/app_preferences.dart';
import '../features/settings/presentation/app_preferences_controller.dart';
import '../features/settings/presentation/design_preview_screen.dart';
import '../features/stock/presentation/lotteries_templates_screen.dart';
import 'main_shell_screen.dart';

CustomTransitionPage<void> _buildTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: AppSpacing.motionFast,
    reverseTransitionDuration: AppSpacing.motionFast,
    child: child,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        return child;
      }
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: AppSpacing.motionCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refreshListenable = ValueNotifier<int>(0);
  ref
    ..listen<AppPreferences>(appPreferencesProvider, (_, __) {
      refreshListenable.value++;
    })
    ..listen<AuthState>(authControllerProvider, (_, __) {
      refreshListenable.value++;
    });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      final String path = state.uri.path;
      if (path == '/design-preview') {
        return null;
      }

      final AppPreferences prefs = ref.read(appPreferencesProvider);
      final AuthState auth = ref.read(authControllerProvider);

      if (!prefs.hasPickedLanguage) {
        return path == '/language' ? null : '/language';
      }
      if (!prefs.hasSeenWelcome) {
        return path == '/welcome' ? null : '/welcome';
      }

      switch (auth.stage) {
        case AuthStage.unauthenticated:
          return path == '/login' ? null : '/login';
        case AuthStage.needsShopSetup:
          return path == '/shop-setup' ? null : '/shop-setup';
        case AuthStage.authenticated:
          if (path == '/language' ||
              path == '/welcome' ||
              path == '/login' ||
              path == '/shop-setup') {
            return '/';
          }
          return null;
      }
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/language',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _buildTransitionPage(
          key: state.pageKey,
          child: LanguagePickerScreen(
            onCompleted: () => context.go('/welcome'),
          ),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _buildTransitionPage(
          key: state.pageKey,
          child: WelcomeScreen(
            onGetStarted: () => context.go('/login'),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _buildTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/shop-setup',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _buildTransitionPage(
          key: state.pageKey,
          child: const ShopSetupScreen(),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _buildTransitionPage(
          key: state.pageKey,
          child: const MainShellScreen(),
        ),
      ),
      GoRoute(
        path: '/design-preview',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _buildTransitionPage(
          key: state.pageKey,
          child: const DesignPreviewScreen(),
        ),
      ),
      GoRoute(
        path: '/lotteries-templates',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _buildTransitionPage(
          key: state.pageKey,
          child: const LotteriesTemplatesScreen(),
        ),
      ),
      GoRoute(
        path: '/sellers',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _buildTransitionPage(
          key: state.pageKey,
          child: const SellersScreen(),
        ),
      ),
      GoRoute(
        path: '/sellers/:sellerId',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String sellerId = state.pathParameters['sellerId'] ?? '';
          return _buildTransitionPage(
            key: state.pageKey,
            child: SellerDetailScreen(sellerId: sellerId),
          );
        },
      ),
    ],
  );
});
