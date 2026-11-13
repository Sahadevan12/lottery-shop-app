import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../data/reports_repository.dart';
import '../domain/report_entities.dart';

final Provider<ReportsRepository> reportsRepositoryProvider =
    Provider<ReportsRepository>((Ref ref) {
  final SupabaseClient? client = SupabaseConfig.clientOrNull;
  if (client == null) {
    throw StateError(
      'SupabaseClient is not initialized. Pass --dart-define=SUPABASE_URL and SUPABASE_ANON_KEY, or override reportsRepositoryProvider in tests.',
    );
  }
  return SupabaseReportsRepository(client);
});

class ReportsState {
  const ReportsState({
    required this.preset,
    required this.fromDate,
    required this.toDate,
    this.summary,
    this.isLoading = false,
    this.error,
  });

  final ReportPeriodPreset preset;
  final DateTime fromDate;
  final DateTime toDate;
  final ReportsSummaryData? summary;
  final bool isLoading;
  final Object? error;

  ReportsState copyWith({
    ReportPeriodPreset? preset,
    DateTime? fromDate,
    DateTime? toDate,
    ReportsSummaryData? summary,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return ReportsState(
      preset: preset ?? this.preset,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final NotifierProvider<ReportsController, ReportsState> reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(ReportsController.new);

class ReportsController extends Notifier<ReportsState> {
  int _requestSeq = 0;

  static (DateTime, DateTime) rangeForPreset(
    ReportPeriodPreset preset, {
    DateTime? now,
  }) {
    final DateTime today = _dateOnly(now ?? DateTime.now());
    switch (preset) {
      case ReportPeriodPreset.today:
        return (today, today);
      case ReportPeriodPreset.week:
        final int daysFromMonday = today.weekday - DateTime.monday;
        return (today.subtract(Duration(days: daysFromMonday)), today);
      case ReportPeriodPreset.month:
        return (DateTime(today.year, today.month, 1), today);
      case ReportPeriodPreset.thirtyDays:
        return (today.subtract(const Duration(days: 29)), today);
      case ReportPeriodPreset.custom:
        return (today, today);
    }
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  ReportsState build() {
    final (DateTime from, DateTime to) =
        rangeForPreset(ReportPeriodPreset.thirtyDays);
    Future<void>.microtask(() {
      if (_requestSeq == 0) {
        loadRange(from, to);
      }
    });
    return ReportsState(
      preset: ReportPeriodPreset.thirtyDays,
      fromDate: from,
      toDate: to,
      isLoading: true,
    );
  }

  Future<void> selectPreset(ReportPeriodPreset preset) async {
    if (preset == ReportPeriodPreset.custom) {
      return;
    }
    final (DateTime from, DateTime to) = rangeForPreset(preset);
    state = state.copyWith(preset: preset, fromDate: from, toDate: to);
    await loadRange(from, to);
  }

  Future<void> selectCustomRange(DateTime fromDate, DateTime toDate) async {
    final DateTime from = _dateOnly(fromDate);
    final DateTime to = _dateOnly(toDate);
    state = state.copyWith(
      preset: ReportPeriodPreset.custom,
      fromDate: from,
      toDate: to,
    );
    await loadRange(from, to);
  }

  Future<void> refresh() => loadRange(state.fromDate, state.toDate);

  Future<void> loadRange(DateTime fromDate, DateTime toDate) async {
    final int seq = ++_requestSeq;
    if (toDate.difference(fromDate).inDays > 366) {
      state = state.copyWith(
        isLoading: false,
        error: Exception('RANGE_TOO_LARGE'),
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ReportsRepository repo = ref.read(reportsRepositoryProvider);
      final ReportsSummaryData summary = await repo.fetchReportsSummary(
        fromDate: fromDate,
        toDate: toDate,
      );
      if (seq != _requestSeq) {
        return;
      }
      state = state.copyWith(
        summary: summary,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (seq != _requestSeq) {
        return;
      }
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}
