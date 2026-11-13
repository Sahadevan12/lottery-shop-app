import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  });

  final DashboardTodayData? dashboard;
  final bool isLoading;
  final Object? error;

  HomeState copyWith({
    DashboardTodayData? dashboard,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return HomeState(
      dashboard: dashboard ?? this.dashboard,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final NotifierProvider<HomeController, HomeState> homeControllerProvider =
    NotifierProvider<HomeController, HomeState>(HomeController.new);

class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() {
    Future<void>.microtask(refresh);
    return const HomeState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final HomeRepository repo = ref.read(homeRepositoryProvider);
      final DashboardTodayData data = await repo.fetchDashboardToday();
      state = state.copyWith(
        dashboard: data,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    }
  }
}
