import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/accounting_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BackupSyncScreen extends StatefulWidget {
  const BackupSyncScreen({super.key});

  @override
  State<BackupSyncScreen> createState() => _BackupSyncScreenState();
}

class _BackupSyncScreenState extends State<BackupSyncScreen> {
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final savedTime = prefs.getString('u_${user.id}_last_sync_time');
      if (savedTime != null) {
        setState(() {
          _lastSyncedAt = DateTime.parse(savedTime);
        });
      }
    }
  }

  Future<void> _handleManualSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final model = Provider.of<AccountingModel>(context, listen: false);
      
      // Explicitly trigger a push to cloud (backup)
      await model.backupData();
      
      // Update local timestamp
      final prefs = await SharedPreferences.getInstance();
      final user = Supabase.instance.client.auth.currentUser;
      final now = DateTime.now();
      if (user != null) {
        await prefs.setString('u_${user.id}_last_sync_time', now.toIso8601String());
      }
      
      if (mounted) {
        setState(() {
          _lastSyncedAt = now;
          _isSyncing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync completed successfully!', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed. Please check your connection.', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final model = Provider.of<AccountingModel>(context, listen: false);
      
      // Explicitly trigger a pull from cloud (restore)
      await model.restoreData();
      
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data restored successfully!', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed. Please try again later.', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String lastSyncText = _lastSyncedAt != null 
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(_lastSyncedAt!)
        : 'Never synced';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Backup & Sync',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium Status Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Cloud Sync',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your data is backed up securely',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Last Sync: $lastSyncText',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Manual Operations',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              
              // Sync Now Button
              ElevatedButton(
                onPressed: _isSyncing ? null : _handleManualSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                  foregroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: isDark ? 0 : 2,
                ),
                child: _isSyncing 
                  ? const SizedBox(
                      height: 24, 
                      width: 24, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_rounded),
                        const SizedBox(width: 12),
                        Text(
                          'Sync Now (Backup)',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
              ),
              
              const SizedBox(height: 16),
              
              // Restore Button
              ElevatedButton(
                onPressed: _isSyncing ? null : _handleRestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                  foregroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: isDark ? 0 : 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_download_rounded),
                    const SizedBox(width: 12),
                    Text(
                      'Restore from Cloud',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151).withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: isDark ? Colors.white60 : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Your data is automatically synced to the cloud whenever you make changes. You can use these buttons to manually push or pull data if you are using multiple devices.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
