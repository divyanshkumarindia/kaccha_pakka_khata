import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecentPage {
  final String id; // timestamp-based id
  final String templateKey;
  final String displayTitle;
  final int timestamp;
  final Map<String, dynamic> state;

  RecentPage(
      {required this.id,
      required this.templateKey,
      required this.displayTitle,
      required this.timestamp,
      required this.state});

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateKey': templateKey,
        'displayTitle': displayTitle,
        'timestamp': timestamp,
        'state': state,
      };

  static RecentPage fromJson(Map<String, dynamic> j) => RecentPage(
        id: j['id'] as String,
        templateKey: j['templateKey'] as String,
        displayTitle: j['displayTitle'] as String,
        timestamp: (j['timestamp'] as num).toInt(),
        state: Map<String, dynamic>.from(j['state'] as Map),
      );
}

class RecentService {
  static const _baseKey = 'recent_pages';
  static const int maxItems = 20;

  static String _uk() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return _baseKey;
    return 'u_${user.id}_$_baseKey';
  }

  static Future<List<RecentPage>> listRecent() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_uk());
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> arr = json.decode(raw);
      return arr
          .map((e) => RecentPage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveRecent(RecentPage p) async {
    final list = await listRecent();
    // prevent too many duplicates: if top item same template and within 30s, replace
    if (list.isNotEmpty &&
        list.first.templateKey == p.templateKey &&
        (p.timestamp - list.first.timestamp).abs() < 30000) {
      list[0] = p;
    } else {
      list.insert(0, p);
      if (list.length > maxItems) list.removeRange(maxItems, list.length);
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _uk(), json.encode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> deleteRecent(String id) async {
    final list = await listRecent();
    list.removeWhere((e) => e.id == id);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _uk(), json.encode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_uk());
  }
}
