import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _maxUsesController = TextEditingController(text: '10');

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
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
    setState(() => _isLoadingUsers = true);
    try {
      final response = await _supabase
          .from('user_data')
          .select('user_id, data, updated_at')
          .order('updated_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _filteredUsers = List.from(_users);
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      _showErrorSnackBar('Error fetching users: $e');
    }
  }

  Future<void> _fetchPromoCodes() async {
    setState(() {
      _isLoadingCodes = true;
      _isPromoTableMissing = false;
    });
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _promoCodes = List<Map<String, dynamic>>.from(response);
        _isLoadingCodes = false;
      });
    } catch (e) {
      setState(() => _isLoadingCodes = false);
      final errorStr = e.toString().toLowerCase();
      // Check if table missing error (42P01 is Postgres relation does not exist, PGRST205 is PostgREST schema cache missing)
      if (errorStr.contains('42p01') || 
          errorStr.contains('does not exist') || 
          errorStr.contains('relation "promo_codes"') ||
          errorStr.contains('pgrst205') ||
          errorStr.contains('could not find the table') ||
          errorStr.contains('schema cache')) {
        setState(() => _isPromoTableMissing = true);
      } else {
        _showErrorSnackBar('Error fetching promo codes: $e');
      }
    }
  }

  Future<void> _grantUserPlan(String userId, Map<String, dynamic> currentConfig, String plan, int durationDays, bool isAdmin) async {
    try {
      final updatedConfig = Map<String, dynamic>.from(currentConfig);

      if (plan == 'free') {
        updatedConfig.remove('granted_plan');
        updatedConfig.remove('granted_until');
      } else {
        final until = DateTime.now().add(Duration(days: durationDays));
        updatedConfig['granted_plan'] = plan;
        updatedConfig['granted_until'] = until.toIso8601String();
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

      _showSuccessSnackBar('User configuration updated successfully!');
      _fetchUsers();

      // If updating the currently logged-in user, refresh their session
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        if (mounted) {
          Provider.of<SubscriptionService>(context, listen: false).init();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update subscription: $e');
    }
  }

  Future<void> _createPromoCode() async {
    final code = _codeController.text.trim().toUpperCase();
    final maxUses = int.tryParse(_maxUsesController.text) ?? 10;

    if (code.isEmpty) {
      _showErrorSnackBar('Please enter a promo code name.');
      return;
    }

    setState(() => _isLoadingCodes = true);
    try {
      await _supabase.from('promo_codes').insert({
        'code': code,
        'plan': _selectedPlan,
        'duration_days': _selectedDurationDays,
        'max_uses': maxUses,
        'uses_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      _codeController.clear();
      _showSuccessSnackBar('Promo code $code created successfully!');
      _fetchPromoCodes();
    } catch (e) {
      setState(() => _isLoadingCodes = false);
      _showErrorSnackBar('Failed to create promo code: $e');
    }
  }

  Future<void> _deletePromoCode(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Code', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete the promo code $code?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoadingCodes = true);
    try {
      await _supabase.from('promo_codes').delete().eq('code', code);
      _showSuccessSnackBar('Promo code deleted.');
      _fetchPromoCodes();
    } catch (e) {
      setState(() => _isLoadingCodes = false);
      _showErrorSnackBar('Failed to delete promo code: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
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
    bool localIsAdmin = configData['is_admin'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              Text(
                'Grant Subscription Plan',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$displayName ($email)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                'ID: $userId',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const Divider(height: 24),
              
              Text('Target Plan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _planOption(setDialogState, 'Free', 'free', localPlan, (v) => localPlan = v),
                  const SizedBox(width: 8),
                  _planOption(setDialogState, 'Pro', 'pro', localPlan, (v) => localPlan = v),
                  const SizedBox(width: 8),
                  _planOption(setDialogState, 'Premium', 'premium', localPlan, (v) => localPlan = v),
                ],
              ),
              const SizedBox(height: 16),

              if (localPlan != 'free') ...[
                Text('Duration', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: localDuration,
                  dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1F2937) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 Days')),
                    DropdownMenuItem(value: 30, child: Text('30 Days')),
                    DropdownMenuItem(value: 90, child: Text('90 Days')),
                    DropdownMenuItem(value: 365, child: Text('1 Year (365 Days)')),
                    DropdownMenuItem(value: 1825, child: Text('5 Years')),
                    DropdownMenuItem(value: 99999, child: Text('Lifetime')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => localDuration = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Admin Panel Access', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com'
                      ? 'Super Admin (Permanent)'
                      : 'Allow this user to enter the Admin Panel and manage subscriptions.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
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
                activeTrackColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _grantUserPlan(userId, configData, localPlan, localDuration, localIsAdmin);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes'),
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
      child: InkWell(
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search user by ID, name or email...',
                        hintStyle: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.black38),
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoadingUsers
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredUsers.isEmpty
                          ? Center(
                              child: Text(
                                'No users found.',
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredUsers.length,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemBuilder: (context, index) {
                                final row = _filteredUsers[index];
                                final uData = Map<String, dynamic>.from(row['data'] ?? {});
                                final displayName = uData['user_name'] ?? 'Unnamed User';
                                final email = uData['email'] ?? 'No email';
                                final activePlan = uData['granted_plan'] ?? 'free';
                                final untilStr = uData['granted_until'];
                                
                                String subInfo = 'Free tier';
                                if (activePlan != 'free' && untilStr != null) {
                                  final until = DateTime.parse(untilStr);
                                  if (DateTime.now().isBefore(until)) {
                                    final daysLeft = until.difference(DateTime.now()).inDays;
                                    subInfo = '${activePlan.toString().toUpperCase()} - $daysLeft days left';
                                  }
                                }

                                final Color planColor = activePlan == 'premium' 
                                    ? const Color(0xFFDB2777) 
                                    : (activePlan == 'pro' ? const Color(0xFF6366F1) : Colors.grey);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (uData['is_admin'] == true || email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com'
                                                  ? Colors.red.withValues(alpha: 0.15)
                                                  : const Color(0xFF6366F1).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com'
                                                    ? Colors.red.withValues(alpha: 0.3)
                                                    : const Color(0xFF6366F1).withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com' ? 'SUPER ADMIN' : 'ADMIN',
                                              style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: email.toString().toLowerCase() == 'divyanshkumarindia@gmail.com' ? Colors.red : const Color(0xFF6366F1),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(email, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        Text(
                                          subInfo,
                                          style: GoogleFonts.inter(
                                            fontSize: 12, 
                                            color: planColor, 
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.edit_rounded, size: 20),
                                    onTap: () => _showUserGrantDialog(row),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // TAB 2: PROMO CODES MANAGEMENT
          _isPromoTableMissing
              ? _buildSQLSetupView()
              : RefreshIndicator(
                  onRefresh: _fetchPromoCodes,
                  child: Column(
                    children: [
                      // CREATE NEW PROMO CODE
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Promo Code',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'Enter code name (e.g. LIFETIMEPREM)',
                                hintStyle: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.black38),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedPlan,
                                    dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: 'Grant Plan',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                                    dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: 'Duration',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                                    decoration: InputDecoration(
                                      labelText: 'Max Uses Limit',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _createPromoCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Create'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // PROMO CODES LIST
                      Expanded(
                        child: _isLoadingCodes
                            ? const Center(child: CircularProgressIndicator())
                            : _promoCodes.isEmpty
                                ? Center(
                                    child: Text(
                                      'No custom promo codes active.',
                                      style: GoogleFonts.inter(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _promoCodes.length,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemBuilder: (context, index) {
                                      final promo = _promoCodes[index];
                                      final code = promo['code'];
                                      final plan = promo['plan'];
                                      final duration = promo['duration_days'];
                                      final maxUses = promo['max_uses'];
                                      final usesCount = promo['uses_count'];

                                      final isExpired = usesCount >= maxUses;
                                      final durationText = duration >= 99999 ? 'Lifetime' : '$duration Days';

                                      final Color planColor = plan == 'premium' 
                                          ? const Color(0xFFDB2777) 
                                          : const Color(0xFF6366F1);

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          title: Row(
                                            children: [
                                              Text(
                                                code,
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  decoration: isExpired ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: planColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  plan.toString().toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: planColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Text(
                                            'Duration: $durationText • Redeemed: $usesCount / $maxUses',
                                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                            onPressed: () => _deletePromoCode(code),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
