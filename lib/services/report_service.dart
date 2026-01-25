import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Saves a report snapshot to the `public.reports` table.
  ///
  /// [type] - The type of report (e.g., 'Normal', 'Detailed').
  /// [reportData] - The JSON structure containing the report content.
  /// [useCaseType] - The use case type (e.g., 'Personal', 'Business', 'Institute').
  ///
  /// Throws an exception if the save operation fails.
  Future<void> saveReport(
    String type,
    Map<String, dynamic> reportData, {
    String? useCaseType,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      await _supabase.from('reports').insert({
        'user_id': user.id,
        'report_type': type,
        'report_date': DateTime.now().toIso8601String(),
        'report_data': reportData, // Assumes report_data column is JSONB
        'use_case_type': useCaseType, // Add use case type
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Error saving report to Supabase: $e'); // Explicit error logging
      rethrow;
    }
  }

  /// Fetches a stream of reports for the current user.
  ///
  /// [query] - Optional search query for report type or date.
  /// [isDescending] - Sort order for creation date (default: true).
  /// [useCaseType] - Filter by use case type (e.g., 'Personal', 'Business').
  Stream<List<Map<String, dynamic>>> getReportsStream({
    String? query,
    bool isDescending = true,
    String? useCaseType,
  }) {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // specific search query
    if (query != null && query.isNotEmpty) {
      var baseQuery = _supabase.from('reports').select().eq('user_id', user.id);

      // Add use case filter if provided
      if (useCaseType != null) {
        baseQuery = baseQuery.eq('use_case_type', useCaseType);
      }

      return baseQuery
          .or('report_type.ilike.%$query%,report_date.ilike.%$query%')
          .order('created_at', ascending: !isDescending)
          .asStream();
    }

    // default realtime stream
    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: !isDescending)
        .map((data) {
          // Filter by use case if provided
          if (useCaseType != null) {
            return data
                .where((report) => report['use_case_type'] == useCaseType)
                .toList();
          }
          return data;
        });
  }

  /// Simple connection test to verify Supabase access.
  /// Returns "Success" or the error message.
  Future<String> checkConnection() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return '❌ User not logged in';

      // Perform a lightweight fetch (count)
      await _supabase
          .from('reports')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      return '✅ Connection Successful! (Can read from "reports" table)';
    } catch (e) {
      return '❌ Connection Failed: $e';
    }
  }

  /// Deletes a report by its ID.
  ///
  /// [id] - The unique identifier of the report to delete.
  ///
  /// Throws an exception if the user is not logged in or if the delete fails.
  Future<void> deleteReport(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      await _supabase.from('reports').delete().eq('id', id);
    } catch (e) {
      print('❌ Error deleting report: $e');
      rethrow;
    }
  }

  /// Updates a report by its ID.
  ///
  /// [id] - The unique identifier of the report to update.
  /// [reportData] - The updated report data.
  /// [reportType] - The updated report type (optional).
  ///
  /// Throws an exception if the user is not logged in or if the update fails.
  Future<void> updateReport(
    String id, {
    Map<String, dynamic>? reportData,
    String? reportType,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      final updates = <String, dynamic>{};
      if (reportData != null) updates['report_data'] = reportData;
      if (reportType != null) updates['report_type'] = reportType;
      updates['report_date'] =
          DateTime.now().toIso8601String(); // Refresh timestamp

      if (updates.isEmpty) return;

      await _supabase
          .from('reports')
          .update(updates)
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (e) {
      print('❌ Error updating report: $e');
      rethrow;
    }
  }

  /// Deletes all reports for the current user.
  Future<void> deleteAllUserReports() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      await _supabase.from('reports').delete().eq('user_id', user.id);
    } catch (e) {
      print('❌ Error deleting all reports: $e');
      rethrow;
    }
  }
}
