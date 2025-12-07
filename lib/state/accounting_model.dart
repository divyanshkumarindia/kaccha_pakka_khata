import 'package:flutter/foundation.dart';
import '../models/accounting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AccountingModel extends ChangeNotifier {
  UserType userType;
  String firmName;
  String currency;
  DurationType duration;
  String periodDate;
  String periodStartDate;
  String periodEndDate;

  Map<String, List<TransactionEntry>> receiptAccounts = {};
  Map<String, List<TransactionEntry>> paymentAccounts = {};
  Map<String, String> receiptLabels = {};
  Map<String, String> paymentLabels = {};

  String? pageTitle;

  double openingCash = 0.0;
  double openingBank = 0.0;
  double openingOther = 0.0;

  AccountingModel({required this.userType})
      : firmName = userTypeConfigs[userType]!.firmNamePlaceholder,
        currency = 'INR',
        duration = DurationType.Daily,
        periodDate = '',
        periodStartDate = '',
        periodEndDate = '' {
    _initializeAccounts();
  }

  // Persistence: simple JSON save/load using SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'userType': userType.toString(),
      'firmName': firmName,
      'receiptLabels': receiptLabels,
      'paymentLabels': paymentLabels,
      'currency': currency,
      'openingCash': openingCash,
      'openingBank': openingBank,
      'openingOther': openingOther,
      'receiptAccounts': receiptAccounts.map((k, v) => MapEntry(
          k,
          v
              .map((e) => {
                    'id': e.id,
                    'description': e.description,
                    'rows': e.rows
                        .map((r) => {
                              'id': r.id,
                              'cash': r.cash,
                              'bank': r.bank,
                              'particulars': r.particulars
                            })
                        .toList(),
                  })
              .toList())),
      'paymentAccounts': paymentAccounts.map((k, v) => MapEntry(
          k,
          v
              .map((e) => {
                    'id': e.id,
                    'description': e.description,
                    'rows': e.rows
                        .map((r) => {
                              'id': r.id,
                              'cash': r.cash,
                              'bank': r.bank,
                              'particulars': r.particulars
                            })
                        .toList(),
                  })
              .toList())),
    };

    await prefs.setString('accounting_data_v1', jsonEncode(data));
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('accounting_data_v1');
    if (s == null) return;
    try {
      final data = jsonDecode(s) as Map<String, dynamic>;
      // firmName & currency
      // load pageTitle if present inside the JSON blob
      pageTitle = data['pageTitle'] ?? pageTitle;
      firmName = data['firmName'] ?? firmName;
      currency = data['currency'] ?? currency;
      openingCash = (data['openingCash'] ?? openingCash).toDouble();
      openingBank = (data['openingBank'] ?? openingBank).toDouble();
      openingOther = (data['openingOther'] ?? openingOther).toDouble();

      // parse accounts
      final ra = data['receiptAccounts'] as Map<String, dynamic>?;
      if (ra != null) {
        receiptAccounts = ra.map((k, v) {
          final list = (v as List).map((item) {
            final rows = (item['rows'] as List)
                .map((r) => TransactionRow(
                    id: r['id'],
                    cash: (r['cash'] ?? 0).toDouble(),
                    bank: (r['bank'] ?? 0).toDouble(),
                    particulars: r['particulars'] ?? ''))
                .toList();
            return TransactionEntry(
                id: item['id'],
                description: item['description'] ?? '',
                rows: rows);
          }).toList();
          return MapEntry(k, list);
        });
      }

      final pa = data['paymentAccounts'] as Map<String, dynamic>?;
      if (pa != null) {
        paymentAccounts = pa.map((k, v) {
          final list = (v as List).map((item) {
            final rows = (item['rows'] as List)
                .map((r) => TransactionRow(
                    id: r['id'],
                    cash: (r['cash'] ?? 0).toDouble(),
                    bank: (r['bank'] ?? 0).toDouble(),
                    particulars: r['particulars'] ?? ''))
                .toList();
            return TransactionEntry(
                id: item['id'],
                description: item['description'] ?? '',
                rows: rows);
          }).toList();
          return MapEntry(k, list);
        });
      }

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

  // Balance card title and description persistence
  Future<String?> getBalanceCardTitle(String cardType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs
          .getString('balance_${cardType}_title_${userType.toString()}');
    } catch (_) {
      return null;
    }
  }

  Future<String?> getBalanceCardDescription(String cardType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('balance_${cardType}_desc_${userType.toString()}');
    } catch (_) {
      return null;
    }
  }

  Future<void> setBalanceCardTitle(String cardType, String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'balance_${cardType}_title_${userType.toString()}', title);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBalanceCardDescription(
      String cardType, String description) async {
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
    receiptAccounts[key] = [TransactionEntry(id: '${key}_1')];
    receiptLabels[key] = 'New Receipt Account';
    notifyListeners();
    _persist();
  }

  void addPaymentAccount(String key) {
    paymentAccounts[key] = [TransactionEntry(id: '${key}_1')];
    paymentLabels[key] = 'New Payment Account';
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

  void addRowToEntry(String accountKey, String entryId, {bool receipt = true}) {
    final accounts = receipt ? receiptAccounts : paymentAccounts;
    final entries = accounts[accountKey];
    if (entries == null) return;
    for (var e in entries) {
      if (e.id == entryId) {
        e.rows.add(TransactionRow(
            id: '${entryId}_row_${DateTime.now().millisecondsSinceEpoch}'));
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
    entries.add(TransactionEntry(id: id));
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

  // Opening balances
  void setOpeningBalances({double? cash, double? bank, double? other}) {
    if (cash != null) openingCash = cash;
    if (bank != null) openingBank = bank;
    if (other != null) openingOther = other;
    notifyListeners();
    _persist();
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
    receiptAccounts.forEach((k, v) {
      sum += _calculateAccountTotal(v);
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
}
