import 'package:flutter/foundation.dart';
import '../models/accounting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/report_service.dart';

import '../utils/translations.dart';

class AccountingModel extends ChangeNotifier {
  UserType userType;
  String firmName;
  String currency;
  DurationType duration;
  String periodDate;
  String periodStartDate;
  String periodEndDate;
  String language = 'en'; // Default to English ('en' or 'hi')

  Map<String, List<TransactionEntry>> receiptAccounts = {};
  Map<String, List<TransactionEntry>> paymentAccounts = {};
  Map<String, String> receiptLabels = {};
  Map<String, String> paymentLabels = {};
  Map<String, String> pageHeaderTitles = {};

  String? pageTitle;

  double openingCash = 0.0;
  double openingBank = 0.0;
  double openingOther = 0.0;

  Map<String, double> customOpeningBalances = {};
  Map<String, String> balanceCardTitles = {};
  Map<String, String> balanceCardDescriptions = {};

  AccountingModel({required this.userType})
      : firmName = userTypeConfigs[userType]!.firmNamePlaceholder,
        currency = 'INR',
        duration = DurationType.Daily,
        periodDate = '',
        periodStartDate = '',
        periodEndDate = '' {
    _initializeAccounts();
    loadSettings();
    _migrateRemoveSavedReports(); // Clean up old saved reports data
    loadFromCloud(); // Try to sync from cloud on startup
  }

  // One-time migration to remove legacy saved_reports
  Future<void> _migrateRemoveSavedReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_reports');
    } catch (e) {
      // Ignore errors
    }
  }

  /// Helper to get translated string
  String t(String key) {
    return appTranslations[language]?[key] ??
        appTranslations['en']![key] ??
        key;
  }

  void setLanguage(String lang) {
    language = lang;
    notifyListeners();
    saveToPrefs();
  }

  // Persistence: simple JSON save/load using SharedPreferences + Supabase Cloud Sync
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'userType': userType.toString(),
      'firmName': firmName,
      'receiptLabels': receiptLabels,
      'paymentLabels': paymentLabels,
      'currency': currency,
      'language': language,
      'pageHeaderTitles': pageHeaderTitles,
      // Don't save opening balances or entry data - they should reset each time
    };

    final jsonData = jsonEncode(data);
    await prefs.setString('accounting_data_v1', jsonData);

    // Also save specific header titles to a dedicated key for robustness
    await prefs.setString('page_header_titles', jsonEncode(pageHeaderTitles));

    // CLOUD SYNC: Push to Supabase if logged in
    await _syncToCloud(data);
  }

  Future<void> _syncToCloud(Map<String, dynamic> data) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('user_data').upsert({
        'user_id': user.id,
        'data': data,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      if (kDebugMode) print('Cloud Sync Error: $e');
    }
  }

  Future<void> loadFromCloud() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1. Try to fetch Name from Auth Metadata (set during signup)
    // Only if we don't have a local name saved yet
    if (_userName == null) {
      final meta = user.userMetadata;
      if (meta != null && meta.containsKey('full_name')) {
        final String fullName = meta['full_name'] ?? '';
        if (fullName.isNotEmpty) {
          // Extract first name
          final firstName = fullName.trim().split(' ').first;
          // Set as username (this will save to prefs too via setUserName)
          setUserName(firstName);
        }
      }
    }

    try {
      final response = await supabase
          .from('user_data')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        // Save to local prefs to trigger the normal load flow
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accounting_data_v1', jsonEncode(data));

        // Load into memory
        await loadFromPrefs();
      }
    } catch (e) {
      if (kDebugMode) print('Cloud Load Error: $e');
    }
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Load header titles first
    try {
      final headers = prefs.getString('page_header_titles');
      if (headers != null) {
        final decoded = jsonDecode(headers) as Map<String, dynamic>;
        pageHeaderTitles = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}

    final s = prefs.getString('accounting_data_v1');
    if (s == null) return;
    try {
      final data = jsonDecode(s) as Map<String, dynamic>;
      // firmName & currency
      // load pageTitle if present inside the JSON blob
      pageTitle = data['pageTitle'] ?? pageTitle;
      firmName = data['firmName'] ?? firmName;
      currency = data['currency'] ?? currency;
      language = data['language'] ?? 'en';

      // Load header titles from main blob if valid there (fallback)
      if (data['pageHeaderTitles'] != null) {
        final ph = data['pageHeaderTitles'] as Map<String, dynamic>;
        // Merge, preferring the dedicated key load if it exists
        if (pageHeaderTitles.isEmpty) {
          pageHeaderTitles = ph.map((k, v) => MapEntry(k, v.toString()));
        }
      }

      // Opening balances always start at 0 - don't load from prefs
      openingCash = 0.0;
      openingBank = 0.0;
      openingOther = 0.0;

      // Entry data (receiptAccounts & paymentAccounts) also resets - don't load from prefs
      // They will be initialized by setUserType when needed

      // load labels if present
      final rl = data['receiptLabels'] as Map<String, dynamic>?;
      if (rl != null) {
        receiptLabels = rl.map((k, v) => MapEntry(k, v.toString()));
      }

      final pl = data['paymentLabels'] as Map<String, dynamic>?;
      if (pl != null) {
        paymentLabels = pl.map((k, v) => MapEntry(k, v.toString()));
      }
      // Notify listeners about the basic loaded data
      notifyListeners();

      // Try to load per-userType label overrides (so each template/userType can have its own titles)
      try {
        final rKey = 'receipt_labels_${userType.toString()}';
        final savedReceipts = prefs.getString(rKey);
        if (savedReceipts != null && savedReceipts.isNotEmpty) {
          final map = jsonDecode(savedReceipts) as Map<String, dynamic>;
          receiptLabels = map.map((k, v) => MapEntry(k, v.toString()));
        }
      } catch (_) {}

      try {
        final pKey = 'payment_labels_${userType.toString()}';
        final savedPayments = prefs.getString(pKey);
        if (savedPayments != null && savedPayments.isNotEmpty) {
          final map = jsonDecode(savedPayments) as Map<String, dynamic>;
          paymentLabels = map.map((k, v) => MapEntry(k, v.toString()));
        }
      } catch (_) {}

      // Also try to read a per-userType quick key (IndexScreen uses this)
      try {
        final key = 'page_title_${userType.toString()}';
        final pt = prefs.getString(key);
        if (pt != null && pt.isNotEmpty) pageTitle = pt;
      } catch (_) {}
    } catch (e) {
      // ignore parse errors
    }
  }

  /// Static helper to read a saved page title for a given user type.
  static Future<String?> loadSavedPageTitle(UserType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('page_title_${type.toString()}');
    } catch (_) {
      return null;
    }
  }

  // Setters for labels so UI can update names for accounts
  void setReceiptLabel(String key, String label) {
    receiptLabels[key] = label;
    notifyListeners();
    _persist();
    // persist per-userType receipt labels so edits are isolated per template/userType
    SharedPreferences.getInstance().then((p) => p.setString(
        'receipt_labels_${userType.toString()}', jsonEncode(receiptLabels)));
  }

  void setPaymentLabel(String key, String label) {
    paymentLabels[key] = label;
    notifyListeners();
    _persist();
    // persist per-userType payment labels so edits are isolated per template/userType
    SharedPreferences.getInstance().then((p) => p.setString(
        'payment_labels_${userType.toString()}', jsonEncode(paymentLabels)));
  }

  void setPageHeaderTitle(String key, String title) {
    pageHeaderTitles[key] = title;
    notifyListeners();
    saveToPrefs();
  }

  // Balance card title and description persistence
  String getBalanceCardTitle(String cardType, {String? defaultValue}) {
    return balanceCardTitles[cardType] ?? defaultValue ?? cardType;
  }

  String getBalanceCardDescription(String cardType, {String? defaultValue}) {
    return balanceCardDescriptions[cardType] ?? defaultValue ?? '';
  }

  Future<void> setBalanceCardTitle(String cardType, String title) async {
    balanceCardTitles[cardType] = title;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'balance_${cardType}_title_${userType.toString()}', title);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBalanceCardDescription(
      String cardType, String description) async {
    balanceCardDescriptions[cardType] = description;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'balance_${cardType}_desc_${userType.toString()}', description);
      notifyListeners();
    } catch (_) {}
  }

  // helper to call save without awaiting
  void _persist() {
    saveToPrefs();
  }

  void _initializeAccounts() {
    final config = userTypeConfigs[userType]!;
    receiptAccounts = {
      for (var e in config.receiptAccounts.keys)
        e: [TransactionEntry(id: '${e}_1')]
    };
    paymentAccounts = {
      for (var e in config.paymentAccounts.keys)
        e: [TransactionEntry(id: '${e}_1')]
    };
    receiptLabels = Map<String, String>.from(config.receiptAccounts);
    paymentLabels = Map<String, String>.from(config.paymentAccounts);
    notifyListeners();
  }

  void addReceiptAccount(String key) {
    // Insert at the beginning (rebuild map)
    final newReceiptAccounts = <String, List<TransactionEntry>>{};
    final newReceiptLabels = <String, String>{};

    // Add new one first
    newReceiptAccounts[key] = [TransactionEntry(id: '${key}_1')];
    newReceiptLabels[key] = 'New Income Category';

    // Then add all existing ones
    receiptAccounts.forEach((k, v) {
      newReceiptAccounts[k] = v;
    });
    receiptLabels.forEach((k, v) {
      newReceiptLabels[k] = v;
    });

    receiptAccounts = newReceiptAccounts;
    receiptLabels = newReceiptLabels;

    notifyListeners();
    _persist();
  }

  void addPaymentAccount(String key) {
    // Insert at the beginning (rebuild map)
    final newPaymentAccounts = <String, List<TransactionEntry>>{};
    final newPaymentLabels = <String, String>{};

    // Add new one first
    newPaymentAccounts[key] = [TransactionEntry(id: '${key}_1')];
    newPaymentLabels[key] = 'New Expense Category';

    // Then add all existing ones
    paymentAccounts.forEach((k, v) {
      newPaymentAccounts[k] = v;
    });
    paymentLabels.forEach((k, v) {
      newPaymentLabels[k] = v;
    });

    paymentAccounts = newPaymentAccounts;
    paymentLabels = newPaymentLabels;

    notifyListeners();
    _persist();
  }

  void removeReceiptAccount(String key) {
    receiptAccounts.remove(key);
    receiptLabels.remove(key);
    notifyListeners();
    _persist();
  }

  void removePaymentAccount(String key) {
    paymentAccounts.remove(key);
    paymentLabels.remove(key);
    notifyListeners();
    _persist();
  }

  // Helper method to generate smart copy names with incremental numbering
  String _generateCopyName(
      String originalName, Map<String, String> existingLabels) {
    // Remove any existing copy suffix to get the base name
    String baseName = originalName;

    // Check if the name already has a (copy N) pattern
    final copyPattern = RegExp(r'\s*\(copy\s*\d*\)\s*$', caseSensitive: false);
    if (copyPattern.hasMatch(originalName)) {
      baseName = originalName.replaceAll(copyPattern, '').trim();
    }

    // Find all existing copies of this base name
    int maxCopyNumber = 0;
    final copyNumberPattern = RegExp(r'\(copy\s*(\d+)\)', caseSensitive: false);

    for (var label in existingLabels.values) {
      // Check if this label is a copy of our base name
      if (label.toLowerCase().startsWith(baseName.toLowerCase())) {
        final match = copyNumberPattern.firstMatch(label);
        if (match != null && match.group(1) != null) {
          final number = int.tryParse(match.group(1)!) ?? 0;
          if (number > maxCopyNumber) {
            maxCopyNumber = number;
          }
        }
      }
    }

    // Generate the new copy name with incremented number
    return '$baseName (copy ${maxCopyNumber + 1})';
  }

  void duplicateReceiptAccount(String originalKey) {
    if (!receiptAccounts.containsKey(originalKey)) return;

    // Generate new unique key
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newKey = 'custom_receipt_$timestamp';

    // Deep copy the entries
    final originalEntries = receiptAccounts[originalKey]!;
    final copiedEntries = originalEntries.map((entry) {
      final newEntryId =
          '${newKey}_entry_${DateTime.now().millisecondsSinceEpoch}';
      final copiedRows = entry.rows.map((row) {
        return TransactionRow(
          id: '${newEntryId}_row_${DateTime.now().millisecondsSinceEpoch}',
          cash: row.cash,
          bank: row.bank,
        );
      }).toList();

      return TransactionEntry(
        id: newEntryId,
        description: entry.description,
        rows: copiedRows,
      );
    }).toList();

    // Insert right after the original key (rebuild map to maintain order)
    final newReceiptAccounts = <String, List<TransactionEntry>>{};
    final newReceiptLabels = <String, String>{};

    for (var key in receiptAccounts.keys) {
      newReceiptAccounts[key] = receiptAccounts[key]!;
      newReceiptLabels[key] = receiptLabels[key] ?? '';

      // Insert copy right after the original
      if (key == originalKey) {
        newReceiptAccounts[newKey] = copiedEntries;
        newReceiptLabels[newKey] = _generateCopyName(
            receiptLabels[originalKey] ?? "Category", receiptLabels);
      }
    }

    receiptAccounts = newReceiptAccounts;
    receiptLabels = newReceiptLabels;

    notifyListeners();
    _persist();
  }

  void duplicatePaymentAccount(String originalKey) {
    if (!paymentAccounts.containsKey(originalKey)) return;

    // Generate new unique key
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newKey = 'custom_payment_$timestamp';

    // Deep copy the entries
    final originalEntries = paymentAccounts[originalKey]!;
    final copiedEntries = originalEntries.map((entry) {
      final newEntryId =
          '${newKey}_entry_${DateTime.now().millisecondsSinceEpoch}';
      final copiedRows = entry.rows.map((row) {
        return TransactionRow(
          id: '${newEntryId}_row_${DateTime.now().millisecondsSinceEpoch}',
          cash: row.cash,
          bank: row.bank,
        );
      }).toList();

      return TransactionEntry(
        id: newEntryId,
        description: entry.description,
        rows: copiedRows,
      );
    }).toList();

    // Insert right after the original key (rebuild map to maintain order)
    final newPaymentAccounts = <String, List<TransactionEntry>>{};
    final newPaymentLabels = <String, String>{};

    for (var key in paymentAccounts.keys) {
      newPaymentAccounts[key] = paymentAccounts[key]!;
      newPaymentLabels[key] = paymentLabels[key] ?? '';

      // Insert copy right after the original
      if (key == originalKey) {
        newPaymentAccounts[newKey] = copiedEntries;
        newPaymentLabels[newKey] = _generateCopyName(
            paymentLabels[originalKey] ?? "Category", paymentLabels);
      }
    }

    paymentAccounts = newPaymentAccounts;
    paymentLabels = newPaymentLabels;

    notifyListeners();
    _persist();
  }

  double _calculateAccountTotal(List<TransactionEntry> entries) {
    double total = 0.0;
    for (var e in entries) {
      for (var r in e.rows) {
        total += r.cash + r.bank;
      }
    }
    return total;
  }

  // Public alias so UI code can access totals without using private methods
  double calculateEntriesTotal(List<TransactionEntry> entries) =>
      _calculateAccountTotal(entries);

  double calculateAccountTotalByKey(String key, {bool receipt = true}) {
    final accounts = receipt ? receiptAccounts : paymentAccounts;
    final entries = accounts[key];
    if (entries == null) return 0.0;
    return _calculateAccountTotal(entries);
  }

  // Mutations for rows/entries
  void updateRowValue(String accountKey, String entryId, String rowId,
      {double? cash, double? bank, bool receipt = true}) {
    final accounts = receipt ? receiptAccounts : paymentAccounts;
    final entries = accounts[accountKey];
    if (entries == null) return;
    for (var e in entries) {
      if (e.id == entryId) {
        for (var r in e.rows) {
          if (r.id == rowId) {
            if (cash != null) r.cash = cash;
            if (bank != null) r.bank = bank;
            notifyListeners();
            _persist();
            return;
          }
        }
      }
    }
  }

  void updateEntryDescription(
      String accountKey, String entryId, String description,
      {bool receipt = true}) {
    final accounts = receipt ? receiptAccounts : paymentAccounts;
    final entries = accounts[accountKey];
    if (entries == null) return;
    for (var e in entries) {
      if (e.id == entryId) {
        e.description = description;
        notifyListeners();
        _persist();
        return;
      }
    }
  }

  void addRowToEntry(String accountKey, String entryId,
      {bool receipt = true,
      double? cash,
      double? bank,
      String? insertAfterRowId}) {
    final accounts = receipt ? receiptAccounts : paymentAccounts;
    final entries = accounts[accountKey];
    if (entries == null) return;
    for (var e in entries) {
      if (e.id == entryId) {
        final newRow = TransactionRow(
          id: '${entryId}_row_${DateTime.now().millisecondsSinceEpoch}',
          cash: cash ?? 0,
          bank: bank ?? 0,
        );

        if (insertAfterRowId != null) {
          final index = e.rows.indexWhere((r) => r.id == insertAfterRowId);
          if (index != -1) {
            e.rows.insert(index + 1, newRow);
          } else {
            e.rows.add(newRow);
          }
        } else {
          e.rows.add(newRow);
        }

        notifyListeners();
        _persist();
        return;
      }
    }
  }

  void removeRowFromEntry(String accountKey, String entryId, String rowId,
      {bool receipt = true}) {
    final accounts = receipt ? receiptAccounts : paymentAccounts;
    final entries = accounts[accountKey];
    if (entries == null) return;
    for (var e in entries) {
      if (e.id == entryId) {
        e.rows.removeWhere((r) => r.id == rowId);
        notifyListeners();
        _persist();
        return;
      }
    }
  }

  // Add a new entry (a group of rows) to an account
  void addEntryToAccount(String accountKey, {bool receipt = true}) {
    final accounts = receipt ? receiptAccounts : paymentAccounts;
    final entries = accounts[accountKey];
    if (entries == null) return;
    final id = '${accountKey}_entry_${DateTime.now().millisecondsSinceEpoch}';

    final defaultDescription = '';

    entries.add(TransactionEntry(id: id, description: defaultDescription));
    notifyListeners();
    _persist();
  }

  // Remove an entire entry from an account
  void removeEntryFromAccount(String accountKey, String entryId,
      {bool receipt = true}) {
    final accounts = receipt ? receiptAccounts : paymentAccounts;
    final entries = accounts[accountKey];
    if (entries == null) return;
    entries.removeWhere((e) => e.id == entryId);
    notifyListeners();
    _persist();
  }

  // Opening balances (temporary, not persisted)
  void setOpeningBalances({double? cash, double? bank, double? other}) {
    if (cash != null) openingCash = cash;
    if (bank != null) openingBank = bank;
    if (other != null) openingOther = other;
    notifyListeners();
    // Don't persist - opening balances should reset on each page load
  }

  // Custom opening balance management
  void addCustomOpeningBalance(String key) {
    customOpeningBalances[key] = 0.0;
    notifyListeners();
  }

  void setCustomOpeningBalance(String key, double value) {
    customOpeningBalances[key] = value;
    notifyListeners();
  }

  void removeCustomOpeningBalance(String key) {
    customOpeningBalances.remove(key);
    notifyListeners();
  }

  // Replace entries for an account
  void setReceiptEntries(String key, List<TransactionEntry> entries) {
    receiptAccounts[key] = entries;
    notifyListeners();
    _persist();
  }

  void setPaymentEntries(String key, List<TransactionEntry> entries) {
    paymentAccounts[key] = entries;
    notifyListeners();
    _persist();
  }

  // Simple setters for basic fields
  void setCurrency(String c) {
    currency = c;
    notifyListeners();
    _persist();
  }

  void setFirmName(String name) {
    firmName = name;
    notifyListeners();
    _persist();
  }

  /// Set and persist a custom page title for this user type.
  void setPageTitle(String title) {
    pageTitle = title;
    notifyListeners();
    // persist both in the main JSON and a quick key
    _persist();
    SharedPreferences.getInstance()
        .then((p) => p.setString('page_title_${userType.toString()}', title));
  }

  void setDuration(DurationType d) {
    duration = d;
    notifyListeners();
    _persist();
  }

  void setPeriodDate(String d) {
    periodDate = d;
    notifyListeners();
    _persist();
  }

  void setPeriodRange(String start, String end) {
    periodStartDate = start;
    periodEndDate = end;
    notifyListeners();
    _persist();
  }

  double get receiptsTotal {
    double sum = openingCash + openingBank + openingOther;
    customOpeningBalances.forEach((k, v) {
      sum += v;
    });
    receiptAccounts.forEach((k, v) {
      sum += _calculateAccountTotal(v);
    });
    return sum;
  }

  double get totalOpeningBalance {
    double sum = openingCash + openingBank + openingOther;
    customOpeningBalances.forEach((k, v) {
      sum += v;
    });
    return sum;
  }

  double get paymentsTotal {
    double sum = 0.0;
    paymentAccounts.forEach((k, v) {
      sum += _calculateAccountTotal(v);
    });
    return sum;
  }

  double get netBalance => receiptsTotal - paymentsTotal;

  // ====== SERIALIZATION FOR SAVED REPORTS ======
  Map<String, dynamic> exportState() {
    return {
      'userType': userType.index, // Save as index for enum
      'firmName': firmName,
      'currency': currency,
      'duration': duration.index,
      'periodDate': periodDate,
      'periodStartDate': periodStartDate,
      'periodEndDate': periodEndDate,
      'receiptLabels': receiptLabels,
      'paymentLabels': paymentLabels,
      'openingCash': openingCash,
      'openingBank': openingBank,
      'openingOther': openingOther,
      'customOpeningBalances': customOpeningBalances,
      'balanceCardTitles': balanceCardTitles,
      'balanceCardDescriptions': balanceCardDescriptions,
      'pageTitle': pageTitle,
      'receiptAccounts': receiptAccounts.map(
          (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList())),
      'paymentAccounts': paymentAccounts.map(
          (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList())),
    };
  }

  void importState(Map<String, dynamic> data) {
    try {
      // 1. Restore basic fields
      if (data['userType'] != null) {
        userType = UserType.values[data['userType']];
      }
      firmName = data['firmName'] ?? firmName;
      currency = data['currency'] ?? currency;
      if (data['duration'] != null) {
        duration = DurationType.values[data['duration']];
      }
      periodDate = data['periodDate'] ?? '';
      periodStartDate = data['periodStartDate'] ?? '';
      periodEndDate = data['periodEndDate'] ?? '';
      pageTitle = data['pageTitle'];

      // 2. Restore Labels
      if (data['receiptLabels'] != null) {
        receiptLabels = Map<String, String>.from(data['receiptLabels']);
      }
      if (data['paymentLabels'] != null) {
        paymentLabels = Map<String, String>.from(data['paymentLabels']);
      }

      // 3. Restore Opening Balances
      openingCash = (data['openingCash'] as num?)?.toDouble() ?? 0.0;
      openingBank = (data['openingBank'] as num?)?.toDouble() ?? 0.0;
      openingOther = (data['openingOther'] as num?)?.toDouble() ?? 0.0;

      if (data['customOpeningBalances'] != null) {
        customOpeningBalances = (data['customOpeningBalances'] as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }

      if (data['balanceCardTitles'] != null) {
        balanceCardTitles = Map<String, String>.from(data['balanceCardTitles']);
      }
      if (data['balanceCardDescriptions'] != null) {
        balanceCardDescriptions =
            Map<String, String>.from(data['balanceCardDescriptions']);
      }

      // 4. Restore Accounts (Deep copy)
      if (data['receiptAccounts'] != null) {
        final Map<String, dynamic> rawReceipts = data['receiptAccounts'];
        receiptAccounts = rawReceipts.map((key, value) {
          final list =
              (value as List).map((e) => TransactionEntry.fromJson(e)).toList();
          return MapEntry(key, list);
        });
      }

      if (data['paymentAccounts'] != null) {
        final Map<String, dynamic> rawPayments = data['paymentAccounts'];
        paymentAccounts = rawPayments.map((key, value) {
          final list =
              (value as List).map((e) => TransactionEntry.fromJson(e)).toList();
          return MapEntry(key, list);
        });
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error importing state: $e');
      rethrow; // Allow UI to handle error
    }
  }

  // ====== SETTINGS FUNCTIONALITY ======
  String _selectedCurrency = 'INR';
  String get selectedCurrency => _selectedCurrency;

  String _themeMode = 'light'; // 'light', 'dark', 'system'
  String get themeMode => _themeMode;

  String _themeColor =
      'blue'; // 'blue', 'green', 'purple', 'orange', 'red', 'teal'
  String get themeColor => _themeColor;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  bool _autoSaveReports = false;
  bool get autoSaveReports => _autoSaveReports;

  String? _businessName;
  String? get businessName => _businessName;

  String? _defaultPageType;
  String? get defaultPageType => _defaultPageType;

  String? _defaultReportFormat;
  String? get defaultReportFormat => _defaultReportFormat;

  String? _userName;
  String? get userName => _userName;

  bool _hasSkippedNameSetup = false;
  bool get hasSkippedNameSetup => _hasSkippedNameSetup;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedCurrency = prefs.getString('selected_currency') ?? 'INR';
      _themeMode = prefs.getString('theme_mode') ?? 'light';
      _themeColor = prefs.getString('theme_color') ?? 'blue';
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _autoSaveReports = prefs.getBool('auto_save_reports') ?? false;
      _businessName = prefs.getString('business_name');
      _defaultPageType =
          prefs.getString('default_page_type'); // Default to null (None)
      _defaultReportFormat =
          prefs.getString('default_report_format') ?? 'Basic';
      _userName = prefs.getString('user_name');
      _hasSkippedNameSetup = prefs.getBool('skipped_name_setup') ?? false;

      // Load opening balance titles and descriptions
      for (String type in ['cash', 'bank', 'other']) {
        final title =
            prefs.getString('balance_${type}_title_${userType.toString()}');
        final desc =
            prefs.getString('balance_${type}_desc_${userType.toString()}');
        if (title != null) balanceCardTitles[type] = title;
        if (desc != null) balanceCardDescriptions[type] = desc;
      }

      notifyListeners();
    } catch (e) {
      // ignore errors
    }
  }

  void setSelectedCurrency(String currency) {
    _selectedCurrency = currency;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString('selected_currency', currency));
  }

  void setThemeMode(String mode) {
    _themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString('theme_mode', mode));
  }

  void setThemeColor(String color) {
    _themeColor = color;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString('theme_color', color));
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setBool('dark_mode', _isDarkMode));
  }

  void toggleAutoSaveReports() {
    _autoSaveReports = !_autoSaveReports;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setBool('auto_save_reports', _autoSaveReports));
  }

  void setBusinessName(String name) {
    _businessName = name;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString('business_name', name));
  }

  void setDefaultPageType(String type) {
    _defaultPageType = type;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString('default_page_type', type));
  }

  void setDefaultReportFormat(String format) {
    _defaultReportFormat = format;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString('default_report_format', format));
  }

  void setUserName(String name) {
    if (name.trim().isEmpty) {
      _userName = null;
      notifyListeners();
      SharedPreferences.getInstance().then((p) => p.remove('user_name'));
    } else {
      _userName = name;
      notifyListeners();
      SharedPreferences.getInstance()
          .then((p) => p.setString('user_name', name));
    }
  }

  void setSkippedNameSetup(bool skipped) {
    _hasSkippedNameSetup = skipped;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setBool('skipped_name_setup', skipped));
  }

  Future<void> backupData() async {
    // Placeholder for backup functionality
    // In a real app, this would export data to a file
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> restoreData() async {
    // Placeholder for restore functionality
    // In a real app, this would import data from a file
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> clearAllData() async {
    try {
      // 1. Clear Cloud Reports
      final reportService = ReportService();
      await reportService.deleteAllUserReports();

      // 2. Clear Local Preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Reset all data

      _selectedCurrency = 'INR';
      _isDarkMode = false;
      _autoSaveReports = false;
      _businessName = null;
      _defaultPageType = 'Personal';
      _defaultReportFormat = 'Basic';
      _userName = null;
      _hasSkippedNameSetup = false;

      // Reset accounting data
      openingCash = 0.0;
      openingBank = 0.0;
      openingOther = 0.0;
      _initializeAccounts();

      notifyListeners();
    } catch (e) {
      // ignore errors
    }
  }
}
