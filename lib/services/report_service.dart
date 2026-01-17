import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Saves a report snapshot to the `public.reports` table.
  ///
  /// [type] - The type of report (e.g., 'Normal', 'Detailed').
  /// [reportData] - The JSON structure containing the report content.
  ///
  /// Throws an exception if the save operation fails.
  Future<void> saveReport(String type, Map<String, dynamic> reportData) async {
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
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving report: $e');
      rethrow;
    }
  }

  /// Fetches a stream of reports for the current user, ordered by creation date descending.
  Stream<List<Map<String, dynamic>>> getReportsStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }
}
