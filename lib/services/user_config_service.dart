import 'package:supabase_flutter/supabase_flutter.dart';

class UserConfigService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches the current user's configuration data from the `public.user_data` table.
  /// Returns a Map<String, dynamic> representing the JSONB data, or an empty map if null/error.
  Future<Map<String, dynamic>> getConfig() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};

    try {
      final response = await _supabase
          .from('user_data')
          .select('data')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null || response['data'] == null) {
        return {};
      }

      return Map<String, dynamic>.from(response['data'] as Map);
    } catch (e) {
      print('Error fetching user config: $e');
      return {};
    }
  }

  /// Updates the user's configuration by merging [newSettings] with existing data.
  /// Uses upsert to create the row if it doesn't exist.
  Future<void> updateConfig(Map<String, dynamic> newSettings) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch existing config to ensure we merge, not overwrite
      final currentConfig = await getConfig();

      // 2. Merge new settings into existing config
      final mergedConfig = {...currentConfig, ...newSettings};

      // 3. Upsert into user_data
      // We explicitly set updated_at to now()
      await _supabase.from('user_data').upsert({
        'user_id': user.id,
        'data': mergedConfig,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id'); // Ensure we update based on user_id
    } catch (e) {
      print('Error updating user config: $e');
      // In a real app, you might want to rethrow or handle this more gracefully
    }
  }
}
