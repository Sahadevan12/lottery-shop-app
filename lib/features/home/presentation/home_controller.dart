import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cached_fetch.dart';
import '../../../core/supabase/supabase_config.dart';
import '../data/home_repository.dart';

final Provider<HomeRepository> homeRepositoryProvider =
    Provider<HomeRepository>((Ref ref) {
  final SupabaseClient? client = SupabaseConfig.clientOrNull;
  if (client == null) {
    throw StateError(
      'SupabaseClient is not initialized. Pass --dart-define=SUPABASE_URL and SUPABASE_ANON_KEY, or override homeRepositoryProvider in tests.',
    );
  }
  return SupabaseHomeRepository(client);
});

class HomeState {
  const HomeState({
    this.dashboard,
    this.isLoading = false,
    this.error,
    this.cachedAt,
    this.isFromCache = false,
  });

  final DashboardTodayData? dashboard;
  final bool isLoading;
  final Object? error;
  final DateTime? cachedAt;
  final bool isFromCache;

  HomeState copyWith({
    DashboardTodayData? dashboard,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    DateTime? cachedAt,
    bool? isFromCache,
  }) {
    return HomeState(
      dashboard: dashboard ?? this.dashboard,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      cachedAt: cachedAt ?? this.cachedAt,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

final NotifierProvider<HomeController, HomeState> homeControllerProvider =
    NotifierProvider<HomeController, HomeState>(HomeController.new);

class HomeController extends Notifier<HomeState> {
  static const String _cacheKey = 'dashboard_today';

  @override
  HomeState build() {
    Future<void>.microtask(refresh);
    return const HomeState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final HomeRepository repo = ref.read(homeRepositoryProvider);
      final CachedFetchResult<DashboardTodayData> result =
          await CachedFetch.run<DashboardTodayData>(
        ref: ref,
        cacheKey: _cacheKey,
        remoteFetch: repo.fetchDashboardToday,
        toJson: (DashboardTodayData d) => d.toJson(),
        fromJson: (Object json) => DashboardTodayData.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      );
      state = state.copyWith(
        dashboard: result.data,
        isLoading: false,
        clearError: true,
        cachedAt: result.cachedAt,
        isFromCache: result.isFromCache,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    }
  }
}
