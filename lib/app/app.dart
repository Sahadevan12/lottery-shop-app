import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_constants.dart';
import '../features/settings/domain/app_preferences.dart';
import '../features/settings/presentation/app_preferences_controller.dart';
import '../l10n/app_localizations.dart';
import 'app_router.dart';

/// Root Application Widget (§3, §4).
class LuckyLedgerApp extends ConsumerWidget {
  const LuckyLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPreferences prefs = ref.watch(appPreferencesProvider);
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      locale: prefs.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      themeMode: prefs.themeMode,
      theme: AppTheme.build(
        brightness: Brightness.light,
        locale: prefs.locale,
        largeText: prefs.largeText,
      ),
      darkTheme: AppTheme.build(
        brightness: Brightness.dark,
        locale: prefs.locale,
        largeText: prefs.largeText,
      ),
      routerConfig: router,
    );
  }
}
