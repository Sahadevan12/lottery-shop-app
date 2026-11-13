import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/report_entities.dart';

abstract class ReportsRepository {
  Future<ReportsSummaryData> fetchReportsSummary({
    required DateTime fromDate,
    required DateTime toDate,
  });
}

class SupabaseReportsRepository implements ReportsRepository {
  SupabaseReportsRepository(this._client);

  final SupabaseClient _client;

  static String _isoDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<ReportsSummaryData> fetchReportsSummary({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final dynamic response = await _client.rpc<dynamic>(
      'get_reports_summary',
      params: <String, dynamic>{
        'p_from_date': _isoDate(fromDate),
        'p_to_date': _isoDate(toDate),
      },
    );
    if (response is Map<String, dynamic>) {
      return ReportsSummaryData.fromJson(response);
    }
    return ReportsSummaryData.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
