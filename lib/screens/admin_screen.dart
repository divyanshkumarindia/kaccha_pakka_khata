import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/subscription_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient _supabase = Supabase.instance.client;

  // State flags
  bool _isLoadingUsers = false;
  bool _isLoadingCodes = false;
  bool _isPromoTableMissing = false;

  // Data
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _promoCodes = [];
  List<Map<String, dynamic>> _recentUsers = [];

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _maxUsesController = TextEditingController(text: '10');
  final FocusNode _searchFocusNode = FocusNode();

  // Creation options
  String _selectedPlan = 'premium';
  int _selectedDurationDays = 30;

  final String _setupSql = '''-- Create promo_codes table
CREATE TABLE IF NOT EXISTS public.promo_codes (
    code TEXT PRIMARY KEY,
    plan TEXT NOT NULL, -- 'pro' or 'premium'
    duration_days INTEGER NOT NULL, -- e.g. 30, 365, 99999 (for lifetime)
    max_uses INTEGER NOT NULL DEFAULT 1,
    uses_count INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- If table already exists, run this to add the is_active column
ALTER TABLE public.promo_codes ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Enable Row Level Security (RLS)
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;

-- Allow anonymous or authenticated read access
CREATE POLICY "Allow read access to promo_codes" ON public.promo_codes
    FOR SELECT USING (true);

-- Allow users to update uses_count when redeeming
CREATE POLICY "Allow update access to promo_codes" ON public.promo_codes
    FOR UPDATE USING (true);

-- Allow admins to insert promo codes
CREATE POLICY "Allow admin to insert promo_codes" ON public.promo_codes
    FOR INSERT TO authenticated
    WITH CHECK (
      (auth.jwt() ->> 'email') = 'divyanshkumarindia@gmail.com'
      OR EXISTS (
        SELECT 1 FROM public.user_data
        WHERE user_id = auth.uid()
          AND (data->>'is_admin')::boolean = true
      )
    );

-- Allow admins to delete promo codes
CREATE POLICY "Allow admin to delete promo_codes" ON public.promo_codes
    FOR DELETE TO authenticated
    USING (
      (auth.jwt() ->> 'email') = 'divyanshkumarindia@gmail.com'
      OR EXISTS (
        SELECT 1 FROM public.user_data
        WHERE user_id = auth.uid()
          AND (data->>'is_admin')::boolean = true
      )
    );

-- Create user_promo_redemptions table
CREATE TABLE IF NOT EXISTS public.user_promo_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    code TEXT NOT NULL REFERENCES public.promo_codes(code) ON DELETE CASCADE,
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, code)
);

-- Enable RLS
ALTER TABLE public.user_promo_redemptions ENABLE ROW LEVEL SECURITY;

-- Allow users to read/insert their own redemptions
CREATE POLICY "Allow users to read their own redemptions" ON public.user_promo_redemptions
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Allow users to insert their own redemptions" ON public.user_promo_redemptions
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() {});
    });
    _loadAllData();
    _loadRecentUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _codeController.dispose();
    _maxUsesController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((u) {
          final id = (u['user_id'] ?? '').toString().toLowerCase();
          final dataMap = u['data'] as Map?;
          final name = (dataMap?['user_name'] ?? '').toString().toLowerCase();
          final email = (dataMap?['email'] ?? '').toString().toLowerCase();
          return id.contains(query) || name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchUsers(),
      _fetchPromoCodes(),
    ]);
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);
    try {
      final response = await _supabase
          .from('user_data')
          .select('user_id, data, updated_at')
          .order('updated_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _filteredUsers = List.from(_users);
        _isLoadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingUsers = false);
      _showErrorSnackBar('Error fetching users: $e');
    }
  }

  Future<void> _loadRecentUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentStr = prefs.getString('admin_recent_users');
      if (recentStr != null) {
        final List<dynamic> decoded = jsonDecode(recentStr);
        if (mounted) {
          setState(() {
            _recentUsers = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading recent users: $e");
    }
  }

  Future<void> _saveRecentUser(Map<String, dynamic> userRow) async {
    try {
      final uData = Map<String, dynamic>.from(userRow['data'] ?? {});
      final email = uData['email']?.toString().toLowerCase() ?? '';
      final isAdmin = uData['is_admin'] == true || email == 'divyanshkumarindia@gmail.com';
      if (isAdmin) return; // Admins are already in the main view, no need to add to recent

      final userId = userRow['user_id'] as String;
      // Filter out duplicate
      _recentUsers.removeWhere((item) => item['user_id'] == userId);
      // Keep up to 5 recent users
      _recentUsers.insert(0, userRow);
      if (_recentUsers.length > 5) {
        _recentUsers = _recentUsers.sublist(0, 5);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_recent_users', jsonEncode(_recentUsers));
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error saving recent user: $e");
    }
  }

  Future<void> _removeRecentUser(String userId) async {
    try {
      _recentUsers.removeWhere((item) => item['user_id'] == userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_recent_users', jsonEncode(_recentUsers));
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error removing recent user: $e");
    }
  }

  Widget _buildUserCard(Map<String, dynamic> row, {bool showRemoveRecent = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uData = Map<String, dynamic>.from(row['data'] ?? {});
    final displayName = uData['user_name'] ?? 'Unnamed User';
    final email = uData['email'] ?? 'No email';
    final activePlan = uData['granted_plan'] ?? 'free';
    final untilStr = uData['granted_until'];
    final userId = row['user_id'];
    
    String durationLabel(int days) {
      if (days > 10000) return 'Lifetime';
      if (days == 7) return '7 Days';
      if (days == 30) return '30 Days';
      if (days == 90) return '90 Days';
      if (days == 365) return '1 Year';
      if (days == 730) return '2 Years';
      if (days == 1095) return '3 Years';
      if (days == 1825) return '5 Years';
      return '$days Days';
    }

    String subInfo = 'Free tier';
    if (activePlan != 'free' && untilStr != null) {
      final until = DateTime.parse(untilStr);
      if (DateTime.now().isBefore(until)) {
        final daysLeft = until.difference(DateTime.now()).inDays + 1;
        final durationDays = uData['granted_duration_days'] as int?;
        final planName = activePlan.toString().toUpperCase();

        if (daysLeft > 10000) {
          subInfo = '$planName • Lifetime';
        } else if (durationDays != null) {
          subInfo = '$planName • ${durationLabel(durationDays)} ($daysLeft days left)';
        } else {
          subInfo = '$planName • $daysLeft days left';
        }
      }
    }

    final Color planColor = activePlan == 'premium' 
        ? const Color(0xFFDB2777) 
        : (activePlan == 'pro' ? const Color(0xFF6366F1) : const Color(0xFF64748B));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 2,
      shadowColor: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _saveRecentUser(row);
          _showUserGrantDialog(row);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _userAvatar(displayName, planColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (uData['is_admin'] == true || email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com'
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com'
                                    ? Colors.red.withValues(alpha: 0.2)
                                    : const Color(0xFF6366F1).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com' ? 'SUPER ADMIN' : 'ADMIN',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com' ? Colors.redAccent : const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: planColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        subInfo,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: planColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (showRemoveRecent)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                  onPressed: () => _removeRecentUser(userId),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.05),
                    padding: const EdgeInsets.all(4),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    final query = _searchController.text.trim().toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (query.isNotEmpty) {
      if (_filteredUsers.isEmpty) {
        return Center(
          child: Text(
            'No users found.',
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        );
      }
      return ListView.builder(
        itemCount: _filteredUsers.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          return _buildUserCard(_filteredUsers[index]);
        },
      );
    }

    // Query is empty: build structured sections
    final admins = _users.where((u) {
      final uData = Map<String, dynamic>.from(u['data'] ?? {});
      final email = uData['email']?.toString().toLowerCase() ?? '';
      return uData['is_admin'] == true || email == 'divyanshkumarindia@gmail.com';
    }).toList();

    final List<Widget> listItems = [];

    // 1. Admins section
    if (admins.isNotEmpty) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 18, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                'ADMINS (${admins.length})',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
      for (final admin in admins) {
        listItems.add(_buildUserCard(admin));
      }
    }

    // 2. Recent Inspected section
    if (_recentUsers.isNotEmpty) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, size: 18, color: Color(0xFFDB2777)),
              const SizedBox(width: 8),
              Text(
                'RECENTLY INSPECTED',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
      for (final recent in _recentUsers) {
        // Find if this user exists in the current _users list to get latest data, otherwise use cached
        final match = _users.firstWhere(
          (u) => u['user_id'] == recent['user_id'],
          orElse: () => recent,
        );
        listItems.add(_buildUserCard(match, showRemoveRecent: true));
      }
    }

    if (listItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded, size: 48, color: isDark ? Colors.white30 : Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Search for a user by name or email, or tap the user icon to view all users.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: listItems,
    );
  }

  void _showAllUsersBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.people_rounded, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text(
                        'All Users (${_users.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _users.isEmpty
                      ? Center(
                          child: Text(
                            'No users found.',
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _users.length,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemBuilder: (context, index) {
                            final row = _users[index];
                            return _buildUserCard(row);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchPromoCodes() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCodes = true;
      _isPromoTableMissing = false;
    });
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _promoCodes = List<Map<String, dynamic>>.from(response);
        _isLoadingCodes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCodes = false);
      final errorStr = e.toString().toLowerCase();
      // Check if table missing error (42P01 is Postgres relation does not exist, PGRST205 is PostgREST schema cache missing)
      if (errorStr.contains('42p01') || 
          errorStr.contains('does not exist') || 
          errorStr.contains('relation "promo_codes"') ||
          errorStr.contains('pgrst205') ||
          errorStr.contains('could not find the table') ||
          errorStr.contains('schema cache')) {
        if (!mounted) return;
        setState(() => _isPromoTableMissing = true);
      } else {
        _showErrorSnackBar('Error fetching promo codes: $e');
      }
    }
  }

  Future<void> _grantUserPlan(String userId, Map<String, dynamic> currentConfig, String plan, int durationDays, bool isAdmin, [String mode = 'overwrite']) async {
    try {
      final updatedConfig = Map<String, dynamic>.from(currentConfig);

      if (plan == 'free') {
        updatedConfig.remove('granted_plan');
        updatedConfig.remove('granted_until');
        updatedConfig.remove('granted_duration_days');
      } else {
        DateTime until;
        int finalDurationDays = durationDays;
        
        if (mode == 'add' && currentConfig['granted_until'] != null && currentConfig['granted_plan'] == plan) {
          final currentUntil = DateTime.parse(currentConfig['granted_until'] as String);
          if (currentUntil.isAfter(DateTime.now())) {
            final remainingDays = currentUntil.difference(DateTime.now()).inDays + 1;
            finalDurationDays = remainingDays + durationDays;
            until = currentUntil.add(Duration(days: durationDays));
          } else {
            until = DateTime.now().add(Duration(days: durationDays));
          }
        } else {
          until = DateTime.now().add(Duration(days: durationDays));
        }

        updatedConfig['granted_plan'] = plan;
        updatedConfig['granted_until'] = until.toIso8601String();
        updatedConfig['granted_duration_days'] = finalDurationDays;
      }

      // Update admin privilege
      if (isAdmin) {
        updatedConfig['is_admin'] = true;
      } else {
        updatedConfig.remove('is_admin');
      }

      await _supabase.from('user_data').update({
        'data': updatedConfig,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      if (mounted) {
        _showSuccessSnackBar('User configuration updated successfully!');
        _fetchUsers();
      }

      // If updating the currently logged-in user, refresh their session
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        if (mounted) {
          Provider.of<SubscriptionService>(context, listen: false).init();
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update subscription: $e');
      }
    }
  }

  Future<void> _createPromoCode() async {
    final code = _codeController.text.trim().toUpperCase();
    final maxUses = int.tryParse(_maxUsesController.text) ?? 10;

    if (code.isEmpty) {
      _showErrorSnackBar('Please enter a promo code name.');
      return;
    }

    if (mounted) setState(() => _isLoadingCodes = true);
    try {
      await _supabase.from('promo_codes').insert({
        'code': code,
        'plan': _selectedPlan,
        'duration_days': _selectedDurationDays,
        'max_uses': maxUses,
        'uses_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _codeController.clear();
        _showSuccessSnackBar('Promo code $code created successfully!');
        _fetchPromoCodes();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCodes = false);
        _showErrorSnackBar('Failed to create promo code: $e');
      }
    }
  }

  Future<void> _deletePromoCode(String code) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              'Delete Code',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the promo code $code? This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) setState(() => _isLoadingCodes = true);
    try {
      await _supabase.from('promo_codes').delete().eq('code', code);
      if (mounted) {
        _showSuccessSnackBar('Promo code deleted.');
        _fetchPromoCodes();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCodes = false);
        _showErrorSnackBar('Failed to delete promo code: $e');
      }
    }
  }

  Future<void> _showEditPromoCodeDialog(Map<String, dynamic> promo) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = promo['code'] as String;
    final plan = promo['plan'] as String;
    final currentMaxUses = promo['max_uses'] as int;
    final currentIsActive = promo['is_active'] as bool? ?? true;

    final controller = TextEditingController(text: currentMaxUses.toString());
    bool localIsActive = currentIsActive;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: Color(0xFF6366F1), size: 28),
              const SizedBox(width: 12),
              Text(
                'Edit Promo Code',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Code: $code',
                        style: GoogleFonts.firaCode(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plan: ${plan.toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: plan == 'premium' ? const Color(0xFFDB2777) : const Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Max Uses Limit',
                    labelStyle: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.grey.shade700),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Code Status',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      localIsActive ? 'Active' : 'Disabled (Manually Expired)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: localIsActive ? Colors.green : Colors.redAccent,
                      ),
                    ),
                    value: localIsActive,
                    onChanged: (val) {
                      setDialogState(() {
                        localIsActive = val;
                      });
                    },
                    activeThumbColor: const Color(0xFF6366F1),
                    activeTrackColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final maxUses = int.tryParse(controller.text) ?? currentMaxUses;
                Navigator.pop(ctx);
                _updatePromoCode(code, maxUses, localIsActive);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePromoCode(String code, int maxUses, bool isActive) async {
    if (mounted) setState(() => _isLoadingCodes = true);
    try {
      await _supabase.from('promo_codes').update({
        'max_uses': maxUses,
        'is_active': isActive,
      }).eq('code', code);

      if (mounted) {
        _showSuccessSnackBar('Promo code $code updated successfully!');
        _fetchPromoCodes();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCodes = false);
        _showErrorSnackBar('Failed to update promo code: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showUserGrantDialog(Map<String, dynamic> userRow) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = userRow['user_id'];
    final configData = Map<String, dynamic>.from(userRow['data'] ?? {});
    
    final displayName = configData['user_name'] ?? 'Unnamed User';
    final email = configData['email'] ?? 'No email';

    String localPlan = configData['granted_plan'] ?? 'free';
    int localDuration = 30;
    if (configData['granted_duration_days'] != null) {
      localDuration = configData['granted_duration_days'] as int;
    } else if (configData['granted_until'] != null) {
      final until = DateTime.parse(configData['granted_until'] as String);
      final daysLeft = until.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        if (daysLeft > 10000) {
          localDuration = 99999;
        } else if (daysLeft <= 7) {
          localDuration = 7;
        } else if (daysLeft <= 30) {
          localDuration = 30;
        } else if (daysLeft <= 90) {
          localDuration = 90;
        } else if (daysLeft <= 365) {
          localDuration = 365;
        } else if (daysLeft <= 730) {
          localDuration = 730;
        } else if (daysLeft <= 1095) {
          localDuration = 1095;
        } else if (daysLeft <= 1825) {
          localDuration = 1825;
        } else {
          localDuration = 99999;
        }
      }
    }
    bool localIsAdmin = configData['is_admin'] == true;

    final predefinedDurations = [7, 30, 90, 365, 730, 1095, 1825, 99999];
    bool isCustomDuration = !predefinedDurations.contains(localDuration);
    int dropdownValue = isCustomDuration ? -1 : localDuration;
    final customDurationController = TextEditingController(text: isCustomDuration ? localDuration.toString() : '');
    String durationMode = 'overwrite'; // 'overwrite' or 'add'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit User Access',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // User Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      'User ID: $userId',
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Target Subscription Plan',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _planOption(setDialogState, 'Free', 'free', localPlan, (v) => localPlan = v),
                  const SizedBox(width: 8),
                  _planOption(setDialogState, 'Pro', 'pro', localPlan, (v) => localPlan = v),
                  const SizedBox(width: 8),
                  _planOption(setDialogState, 'Premium', 'premium', localPlan, (v) => localPlan = v),
                ],
              ),
              const SizedBox(height: 20),

              if (localPlan != 'free') ...[
                Text(
                  'Subscription Duration',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: dropdownValue,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 Days')),
                    DropdownMenuItem(value: 30, child: Text('30 Days')),
                    DropdownMenuItem(value: 90, child: Text('90 Days')),
                    DropdownMenuItem(value: 365, child: Text('1 Year (365 Days)')),
                    DropdownMenuItem(value: 730, child: Text('2 Years (730 Days)')),
                    DropdownMenuItem(value: 1095, child: Text('3 Years (1095 Days)')),
                    DropdownMenuItem(value: 1825, child: Text('5 Years')),
                    DropdownMenuItem(value: 99999, child: Text('Lifetime')),
                    DropdownMenuItem(value: -1, child: Text('Custom Days...')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        dropdownValue = val;
                        if (val == -1) {
                          isCustomDuration = true;
                          if (customDurationController.text.isEmpty) {
                            customDurationController.text = '30';
                          }
                        } else {
                          isCustomDuration = false;
                          localDuration = val;
                        }
                      });
                    }
                  },
                ),
                if (isCustomDuration) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customDurationController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Custom Days Count',
                      labelStyle: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey.shade600),
                      hintText: 'e.g. 5, 45, 120',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      setDialogState(() {
                        localDuration = parsed;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            'Overwrite/Set',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: durationMode == 'overwrite' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: durationMode == 'overwrite',
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                durationMode = 'overwrite';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            'Add to Current',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: durationMode == 'add' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: durationMode == 'add',
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                durationMode = 'add';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
              ],

              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    'Admin Panel Access',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com'
                        ? 'Super Admin (Permanent)'
                        : 'Allow this user to enter the Admin Panel and manage subscriptions.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  value: email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com' ? true : localIsAdmin,
                  onChanged: email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com'
                      ? null
                      : (val) {
                          setDialogState(() {
                            localIsAdmin = val;
                          });
                        },
                  activeThumbColor: const Color(0xFF6366F1),
                  activeTrackColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        int finalDuration = localDuration;
                        if (isCustomDuration) {
                          finalDuration = int.tryParse(customDurationController.text) ?? 30;
                        }
                        Navigator.pop(ctx);
                        _grantUserPlan(userId, configData, localPlan, finalDuration, localIsAdmin, durationMode);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planOption(StateSetter setDialogState, String label, String value, String current, Function(String) onChanged) {
    final isSelected = value == current;
    final color = value == 'premium' ? const Color(0xFFDB2777) : (value == 'pro' ? const Color(0xFF6366F1) : Colors.grey);
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setDialogState(() {
              onChanged(value);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSQLSetupView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Database Setup Required',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The required tables for promo codes are missing in your Supabase database.',
                        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'To set up, please execute this SQL query in your Supabase SQL Editor:',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _setupSql,
                  style: GoogleFonts.firaCode(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _setupSql));
                    _showSuccessSnackBar('SQL script copied to clipboard!');
                  },
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Copy SQL Script'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _fetchPromoCodes,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _userAvatar(String name, Color color) {
    final firstChar = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Text(
        firstChar,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Admin Control Panel',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            indicatorColor: const Color(0xFF6366F1),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Manual Grants'),
              Tab(icon: Icon(Icons.local_offer_rounded), text: 'Promo Codes'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: USER MANUAL GRANTS
            RefreshIndicator(
              onRefresh: _fetchUsers,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SizedBox(
                      height: 52,
                      child: Stack(
                        children: [
                          // User Icon Button (positioned behind on the right)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: IconButton(
                                icon: const Icon(Icons.people_rounded, color: Color(0xFF6366F1)),
                                onPressed: _showAllUsersBottomSheet,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                  padding: const EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Search Container (animates right padding to overlay/unoverlay the user icon)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            left: 0,
                            top: 0,
                            bottom: 0,
                            right: _searchFocusNode.hasFocus ? 0 : 60,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search by ID, name or email...',
                                  hintStyle: GoogleFonts.inter(
                                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: isDark ? Colors.white54 : Colors.grey.shade400,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged();
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoadingUsers
                        ? const Center(child: CircularProgressIndicator())
                        : _buildUserList(),
                  ),
                ],
              ),
            ),

          // TAB 2: PROMO CODES MANAGEMENT
          _isPromoTableMissing
              ? _buildSQLSetupView()
              : RefreshIndicator(
                  onRefresh: _fetchPromoCodes,
                  child: ListView(
                    children: [
                      // CREATE NEW PROMO CODE
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6366F1), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Create Promo Code',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'Code Name',
                                hintText: 'e.g. LIFETIMEPREM',
                                hintStyle: GoogleFonts.inter(color: isDark ? Colors.white30 : Colors.grey.shade400, fontSize: 13),
                                labelStyle: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.grey.shade700),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedPlan,
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText: 'Grant Plan',
                                      labelStyle: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.grey.shade700),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'pro', child: Text('Pro')),
                                      DropdownMenuItem(value: 'premium', child: Text('Premium')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedPlan = val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _selectedDurationDays,
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText: 'Duration',
                                      labelStyle: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.grey.shade700),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 7, child: Text('7 Days')),
                                      DropdownMenuItem(value: 30, child: Text('30 Days')),
                                      DropdownMenuItem(value: 365, child: Text('1 Year')),
                                      DropdownMenuItem(value: 99999, child: Text('Lifetime')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedDurationDays = val);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _maxUsesController,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.inter(fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText: 'Max Uses Limit',
                                      labelStyle: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.grey.shade700),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _createPromoCode,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Create'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // PROMO CODES LIST
                      _isLoadingCodes
                          ? const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _promoCodes.isEmpty
                              ? SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Text(
                                      'No custom promo codes active.',
                                      style: GoogleFonts.inter(color: Colors.grey),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _promoCodes.length,
                                  itemBuilder: (context, index) {
                                    final promo = _promoCodes[index];
                                    final code = promo['code'];
                                    final plan = promo['plan'];
                                    final duration = promo['duration_days'];
                                    final maxUses = promo['max_uses'];
                                    final usesCount = promo['uses_count'];
                                    final isActive = promo['is_active'] as bool? ?? true;

                                    final isLimitReached = usesCount >= maxUses;
                                    final isExpired = !isActive || isLimitReached;
                                    final durationText = duration >= 99999 ? 'Lifetime' : '$duration Days';

                                    final Color planColor = plan == 'premium' 
                                        ? const Color(0xFFDB2777) 
                                        : const Color(0xFF6366F1);

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      elevation: 2,
                                      shadowColor: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      code,
                                                      style: GoogleFonts.outfit(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                        decoration: isExpired ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: planColor.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        plan.toString().toUpperCase(),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: planColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF6366F1), size: 20),
                                                      onPressed: () => _showEditPromoCodeDialog(promo),
                                                      style: IconButton.styleFrom(
                                                        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.05),
                                                        padding: const EdgeInsets.all(8),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                                      onPressed: () => _deletePromoCode(code),
                                                      style: IconButton.styleFrom(
                                                        backgroundColor: Colors.red.withValues(alpha: 0.05),
                                                        padding: const EdgeInsets.all(8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Duration: $durationText',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isExpired 
                                                        ? Colors.red.withValues(alpha: 0.1) 
                                                        : Colors.green.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isExpired 
                                                        ? (isLimitReached ? 'EXPIRED' : 'DISABLED') 
                                                        : 'ACTIVE',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: isExpired ? Colors.redAccent : Colors.green,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: maxUses > 0 ? (usesCount / maxUses) : 0,
                                                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        isExpired ? Colors.redAccent : const Color(0xFF6366F1),
                                                      ),
                                                      minHeight: 6,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  '$usesCount / $maxUses uses',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.firaCode(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ],
                  ),
                ),
        ],
      ),
    ),
  );
}
}
