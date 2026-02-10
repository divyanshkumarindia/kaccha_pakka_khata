import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/accounting.dart';

/// Global app state to track the active use case across screens
/// This ensures that reports and transactions are properly filtered
class AppState extends ChangeNotifier {
  static const String _activeUseCaseKey = 'active_use_case';

  UserType? _activeUseCase;

  UserType? get activeUseCase => _activeUseCase;

  /// Get the string representation of the active use case
  String? get activeUseCaseString {
    if (_activeUseCase == null) return null;
    switch (_activeUseCase!) {
      case UserType.personal:
        return 'Personal';
      case UserType.business:
        return 'Business';
      case UserType.institute:
        return 'Institute';
      case UserType.other:
        return 'Other';
    }
  }

  /// Get user-keyed storage key
  String _uk(String key) {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null ? 'u_${user.id}_$key' : key;
  }

  /// Set the active use case and persist it
  Future<void> setActiveUseCase(UserType? useCase) async {
    _activeUseCase = useCase;
    notifyListeners();
    await _saveToPrefs();
  }

  /// Load the active use case from SharedPreferences
  Future<void> loadActiveUseCase() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_uk(_activeUseCaseKey));

    if (saved != null) {
      switch (saved) {
        case 'Personal':
          _activeUseCase = UserType.personal;
          break;
        case 'Business':
          _activeUseCase = UserType.business;
          break;
        case 'Institute':
          _activeUseCase = UserType.institute;
          break;
        case 'Other':
          _activeUseCase = UserType.other;
          break;
        default:
          _activeUseCase = null;
      }
      notifyListeners();
    }
  }

  /// Clear the active use case
  Future<void> clearActiveUseCase() async {
    _activeUseCase = null;
    notifyListeners();
    await _saveToPrefs();
  }

  /// Save to SharedPreferences
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _uk(_activeUseCaseKey);
    if (_activeUseCase == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, activeUseCaseString!);
    }
  }

  /// Get color for the active use case
  int? get activeUseCaseColor {
    if (_activeUseCase == null) return null;
    switch (_activeUseCase!) {
      case UserType.personal:
        return 0xFF00C853; // Green
      case UserType.business:
        return 0xFF2563EB; // Blue
      case UserType.institute:
        return 0xFF7C3AED; // Purple
      case UserType.other:
        return 0xFFF59E0B; // Amber
    }
  }
}
