import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../theme.dart';
import 'components/balance_card.dart';
import 'components/duration_period_picker.dart';
import 'components/premium_card.dart';

/// Shared accounting form widget extracted from the Family screen.
/// Accepts a `templateKey` so templates can pass different labels/configs later.
class AccountingForm extends StatefulWidget {
  final String templateKey;
  final AccountingModel? providedModel;
  final String? customTitle;
  final String? customPageId;

  const AccountingForm({
    Key? key,
    required this.templateKey,
    this.providedModel,
    this.customTitle,
    this.customPageId,
  }) : super(key: key);

  @override
  State<AccountingForm> createState() => _AccountingFormState();
}

class _AccountingFormState extends State<AccountingForm> {
  late AccountingModel model;

  bool isOpeningBalancesExpanded = true;
  // Map to track expansion state for all categories dynamically
  Map<String, bool> categoryExpansionState = {};
  late TextEditingController periodController;
  late TextEditingController periodStartController;
  late TextEditingController periodEndController;

  // Header Title Controller
  late TextEditingController _headerTitleController;
  bool _headerLoaded = false;

  // Balance card custom titles and descriptions
  Map<String, String> balanceCardTitles = {
    'cash': "Yesterday's Cash (B/F)",
    'bank': "Yesterday's Bank (B/F)",
    'other': "Other Funds (B/F)",
  };
  Map<String, String> balanceCardDescriptions = {
    'cash': '', // Empty by default, will show ghost text
    'bank': '',
    'other': '',
  };

  @override
  void initState() {
    super.initState();
    _headerTitleController = TextEditingController();
    _loadBalanceCardData();
  }

  String _getHeaderHint(String key) {
    switch (key) {
      case 'personal':
      case 'family':
        return 'Enter Family Name';
      case 'business':
        return 'Enter Business Name';
      case 'institute':
        return 'Enter Institute Name';
      default:
        return 'Enter Name as per Use';
    }
  }

  Future<void> _loadBalanceCardData() async {
    // This will be called after model is set in didChangeDependencies
    // We'll load it there instead
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is AccountingModel) {
      model = arg;
    } else if (widget.providedModel != null) {
      model = widget.providedModel!;
    } else {
      model = Provider.of<AccountingModel>(context);
    }

    // If customTitle is provided, set it in the model
    if (widget.customTitle != null && widget.customTitle!.isNotEmpty) {
      model.pageTitle = widget.customTitle;
    }

    periodController = TextEditingController(text: model.periodDate);
    periodStartController = TextEditingController(text: model.periodStartDate);
    periodEndController = TextEditingController(text: model.periodEndDate);

    // Load balance card titles and descriptions
    _loadBalanceCardTitlesAndDescriptions();

    // Initialize Header Title if not loaded
    if (!_headerLoaded) {
      final key = widget.customPageId ?? widget.templateKey;
      final savedTitle = model.pageHeaderTitles[key];
      if (savedTitle != null) {
        _headerTitleController.text = savedTitle;
      }
      _headerLoaded = true;
    }
  }

  Future<void> _loadBalanceCardTitlesAndDescriptions() async {
    for (String cardType in ['cash', 'bank', 'other']) {
      final title = await model.getBalanceCardTitle(cardType);
      final desc = await model.getBalanceCardDescription(cardType);
      if (mounted) {
        setState(() {
          if (title != null) balanceCardTitles[cardType] = title;
          if (desc != null) balanceCardDescriptions[cardType] = desc;
        });
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  // Currency helper methods
  String _getCurrencySymbol(String currencyCode) {
    const currencySymbols = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'AUD': 'A\$',
      'CAD': 'C\$',
      'CHF': 'CHF',
      'CNY': '¥',
      'SEK': 'kr',
      'NZD': 'NZ\$',
      'SGD': 'S\$',
      'HKD': 'HK\$',
      'NOK': 'kr',
      'KRW': '₩',
      'TRY': '₺',
      'RUB': '₽',
      'BRL': 'R\$',
      'ZAR': 'R',
      'MXN': 'Mex\$',
      'AED': 'AED',
      'SAR': 'SAR',
      'THB': '฿',
      'MYR': 'RM',
      'IDR': 'Rp',
      'PHP': '₱',
      'PKR': 'Rs',
      'BDT': '৳',
      'LKR': 'Rs',
      'NPR': 'Rs',
    };
    return currencySymbols[currencyCode] ?? currencyCode;
  }

  String _getCurrencyName(String currencyCode) {
    const currencyNames = {
      'INR': 'Indian Rupee',
      'USD': 'US Dollar',
      'EUR': 'Euro',
      'GBP': 'British Pound',
      'JPY': 'Japanese Yen',
      'AUD': 'Australian Dollar',
      'CAD': 'Canadian Dollar',
      'CHF': 'Swiss Franc',
      'CNY': 'Chinese Yuan',
      'SEK': 'Swedish Krona',
      'NZD': 'New Zealand Dollar',
      'SGD': 'Singapore Dollar',
      'HKD': 'Hong Kong Dollar',
      'NOK': 'Norwegian Krone',
      'KRW': 'South Korean Won',
      'TRY': 'Turkish Lira',
      'RUB': 'Russian Ruble',
      'BRL': 'Brazilian Real',
      'ZAR': 'South African Rand',
      'MXN': 'Mexican Peso',
      'AED': 'UAE Dirham',
      'SAR': 'Saudi Riyal',
      'THB': 'Thai Baht',
      'MYR': 'Malaysian Ringgit',
      'IDR': 'Indonesian Rupiah',
      'PHP': 'Philippine Peso',
      'PKR': 'Pakistani Rupee',
      'BDT': 'Bangladeshi Taka',
      'LKR': 'Sri Lankan Rupee',
      'NPR': 'Nepalese Rupee',
    };
    return currencyNames[currencyCode] ?? currencyCode;
  }

  List<String> _getAvailableCurrencies() {
    return [
      'INR',
      'USD',
      'EUR',
      'GBP',
      'JPY',
      'AUD',
      'CAD',
      'CHF',
      'CNY',
      'SEK',
      'NZD',
      'SGD',
      'HKD',
      'NOK',
      'KRW',
      'TRY',
      'RUB',
      'BRL',
      'ZAR',
      'MXN',
      'AED',
      'SAR',
      'THB',
      'MYR',
      'IDR',
      'PHP',
      'PKR',
      'BDT',
      'LKR',
      'NPR',
    ];
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      final parts = s.split('-');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _pickDateFor(BuildContext ctx, TextEditingController controller,
      Function(String) onSet,
      {DateTime? initial, DateTime? firstDate, DateTime? lastDate}) async {
    final now = DateTime.now();
    DateTime init = initial ?? now;
    if (controller.text.isNotEmpty) {
      try {
        final parts = controller.text.split('-');
        if (parts.length == 3) {
          init = DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
    }

    if (firstDate != null && init.isBefore(firstDate)) init = firstDate;
    if (lastDate != null && init.isAfter(lastDate)) init = lastDate;

    final picked = await showDatePicker(
      context: ctx,
      initialDate: init,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (picked != null) {
      final s = _formatDate(picked);
      setState(() {
        controller.text = s;
      });
      onSet(s);
    }
  }

  Future<void> _pickDateRange(BuildContext ctx) async {
    final startDate = _parseDate(model.periodStartDate);
    final endDate = _parseDate(model.periodEndDate);

    final picked = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: (startDate != null && endDate != null)
          ? DateTimeRange(start: startDate, end: endDate)
          : null,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    primaryContainer: const Color(0xFF4F46E5),
                    onPrimaryContainer: Colors.white,
                    secondary: const Color(0xFF818CF8),
                    surface: const Color(0xFF1F2937),
                    onSurface: const Color(0xFFF9FAFB),
                    surfaceContainerHighest: const Color(0xFF374151),
                    onSurfaceVariant: const Color(0xFF9CA3AF),
                    outline: const Color(0xFF4B5563),
                  )
                : ColorScheme.light(
                    primary: const Color(0xFF4F46E5),
                    onPrimary: Colors.white,
                    primaryContainer: const Color(0xFFEEF2FF),
                    onPrimaryContainer: const Color(0xFF312E81),
                    secondary: AppTheme.primaryColor,
                    surface: Colors.white,
                    onSurface: const Color(0xFF111827),
                    surfaceContainerHighest: const Color(0xFFF3F4F6),
                    onSurfaceVariant: const Color(0xFF6B7280),
                    outline: const Color(0xFFD1D5DB),
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              headerBackgroundColor: const Color(0xFF4F46E5),
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              headerHelpStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              weekdayStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
              dayStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                if (states.contains(WidgetState.disabled))
                  return isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFD1D5DB);
                return isDark
                    ? const Color(0xFFF9FAFB)
                    : const Color(0xFF111827);
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected))
                  return const Color(0xFF4F46E5);
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return const Color(0xFF4F46E5);
              }),
              todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected))
                  return const Color(0xFF4F46E5);
                return Colors.transparent;
              }),
              todayBorder: const BorderSide(color: Color(0xFF4F46E5), width: 2),
              yearStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
              ),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return isDark
                    ? const Color(0xFFF9FAFB)
                    : const Color(0xFF111827);
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected))
                  return const Color(0xFF4F46E5);
                return Colors.transparent;
              }),
              rangePickerBackgroundColor:
                  isDark ? const Color(0xFF1F2937) : Colors.white,
              rangePickerHeaderBackgroundColor: const Color(0xFF4F46E5),
              rangePickerHeaderForegroundColor: Colors.white,
              rangeSelectionBackgroundColor: const Color(0x264F46E5),
              rangeSelectionOverlayColor:
                  WidgetStateProperty.all(const Color(0x144F46E5)),
              dividerColor:
                  isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final s1 = _formatDate(picked.start);
      final s2 = _formatDate(picked.end);
      setState(() {
        periodStartController.text = s1;
        periodEndController.text = s2;
      });
      model.setPeriodRange(s1, s2);
    }
  }

  Future<void> _pickYear(BuildContext ctx, TextEditingController controller,
      Function(String) onSet) async {
    final now = DateTime.now();
    int initialYear = now.year;
    if (controller.text.isNotEmpty) {
      try {
        initialYear = int.parse(controller.text);
      } catch (_) {}
    }

    final pickedYear = await showDialog<int>(
      context: ctx,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 320,
            height: 360,
            child: YearPicker(
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              selectedDate: DateTime(initialYear),
              onChanged: (date) {
                Navigator.pop(context, date.year);
              },
            ),
          ),
        );
      },
    );

    if (pickedYear != null) {
      final s = pickedYear.toString();
      setState(() {
        controller.text = s;
      });
      onSet(s);
    }
  }

  Widget _buildDurationAndPeriod(bool isDark, AccountingModel model) {
    return DurationPeriodPicker(
      isDark: isDark,
      model: model,
      periodController: periodController,
      periodStartController: periodStartController,
      periodEndController: periodEndController,
      pickDateFor: _pickDateFor,
      pickDateRange: _pickDateRange,
      pickYear: _pickYear,
    );
  }

  // Show Delete Page Dialog for custom pages
  void _showDeletePageDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400),
            SizedBox(width: 12),
            Text('Delete Page?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this custom page? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.customPageId != null) {
      try {
        // Delete from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedPages = prefs.getString('custom_pages');
        if (savedPages != null) {
          final decoded = jsonDecode(savedPages) as Map<String, dynamic>;
          decoded.remove(widget.customPageId);
          await prefs.setString('custom_pages', jsonEncode(decoded));
        }

        // Navigate back and signal deletion occurred
        if (mounted) {
          Navigator.pop(
              context, true); // Return true to indicate page was deleted
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete page: $e'),
              backgroundColor: Colors.red.shade600,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _showHeadingEditDialog(BuildContext context, bool isDark) async {
    final controller = TextEditingController(text: _headerTitleController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Heading',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: _getHeaderHint(widget.templateKey),
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            ),
            filled: true,
            fillColor:
                isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          _headerTitleController.text = result;
        });
        final key = widget.customPageId ?? widget.templateKey;
        model.setPageHeaderTitle(key, result);
      }
    }
  }

  // Show Basic Report Dialog
  void _showBasicReport(BuildContext context, AccountingModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = _getCurrencySymbol(model.currency);

    // Calculate closing balance
    final closingBalance = model.netBalance;
    final netReceipts = model.receiptsTotal;
    final netPayments = model.paymentsTotal;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850, maxHeight: 750),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and period
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          model.firmName.isNotEmpty
                              ? model.firmName
                              : 'Financial Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 24),
                          iconSize: 24,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          tooltip: 'Close',
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getReportPeriodText(model),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF9FAFB),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPremiumActionButton(
                      'Save Report',
                      Icons.save,
                      AppTheme.primaryColor,
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Save feature coming soon!')),
                        );
                      },
                    ),
                    _buildPremiumActionButton(
                      'Download Excel',
                      Icons.file_download,
                      const Color(0xFF10B981),
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Excel export coming soon!')),
                        );
                      },
                    ),
                    _buildPremiumActionButton(
                      'Download PDF',
                      Icons.picture_as_pdf,
                      AppTheme.paymentColor,
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('PDF export coming soon!')),
                        );
                      },
                    ),
                    _buildActionButton(
                      'Print',
                      Icons.print,
                      isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF374151),
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Print feature coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Firm Name and Period Header
                      Text(
                        model.firmName.isNotEmpty
                            ? model.firmName
                            : 'Financial Report',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getReportPeriodText(model),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(All amounts in ${_getCurrencyName(model.currency)})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Row-wise Layout - Receipts Section
                      Column(
                        children: [
                          // Receipts Section
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFF0FDF4),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF374151)
                                    : AppTheme.receiptColor,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Receipts Header
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(7),
                                      topRight: Radius.circular(7),
                                    ),
                                  ),
                                  child: Text(
                                    'Receipts ($currencySymbol)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // Receipts Content
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Opening Balance
                                      _buildReportItemRow(
                                        'Opening Balances B/F',
                                        '',
                                        isDark,
                                        isBold: true,
                                      ),
                                      const SizedBox(height: 4),
                                      _buildReportItemRow(
                                        '  Balance B/F:',
                                        '$currencySymbol${_formatAmount(model.openingCash + model.openingBank + model.openingOther + model.customOpeningBalances.values.fold(0.0, (sum, val) => sum + val))}',
                                        isDark,
                                      ),
                                      const Divider(height: 16),
                                      // Income Categories
                                      ...model.receiptAccounts.entries
                                          .map((entry) {
                                        final categoryTotal =
                                            entry.value.fold<double>(
                                          0.0,
                                          (sum, e) =>
                                              sum +
                                              e.rows.fold<double>(
                                                  0.0,
                                                  (s, row) =>
                                                      s + row.cash + row.bank),
                                        );
                                        if (categoryTotal > 0) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: _buildReportItemRow(
                                              model.receiptLabels[entry.key] ??
                                                  entry.key,
                                              '$currencySymbol${_formatAmount(categoryTotal)}',
                                              isDark,
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      }).toList(),
                                      const Divider(height: 16, thickness: 2),
                                      // Total Receipts
                                      _buildReportItemRow(
                                        'Total Receipts:',
                                        '$currencySymbol${_formatAmount(netReceipts)}',
                                        isDark,
                                        isBold: true,
                                        color: AppTheme.receiptColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Payments Section
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFFEF2F2),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF374151)
                                    : AppTheme.paymentColor,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Payments Header
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.paymentColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(7),
                                      topRight: Radius.circular(7),
                                    ),
                                  ),
                                  child: Text(
                                    'Payments ($currencySymbol)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // Payments Content
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Expense Categories
                                      ...model.paymentAccounts.entries
                                          .map((entry) {
                                        final categoryTotal =
                                            entry.value.fold<double>(
                                          0.0,
                                          (sum, e) =>
                                              sum +
                                              e.rows.fold<double>(
                                                  0.0,
                                                  (s, row) =>
                                                      s + row.cash + row.bank),
                                        );
                                        if (categoryTotal > 0) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: _buildReportItemRow(
                                              model.paymentLabels[entry.key] ??
                                                  entry.key,
                                              '$currencySymbol${_formatAmount(categoryTotal)}',
                                              isDark,
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      }).toList(),
                                      const Divider(height: 16),
                                      // Closing Balance C/F
                                      _buildReportItemRow(
                                        'Closing Balance C/F',
                                        '',
                                        isDark,
                                        isBold: true,
                                      ),
                                      const SizedBox(height: 4),
                                      _buildReportItemRow(
                                        '  Balance:',
                                        '$currencySymbol${_formatAmount(closingBalance)}',
                                        isDark,
                                      ),
                                      const Divider(height: 16, thickness: 2),
                                      // Total Payments
                                      _buildReportItemRow(
                                        'Total Payments:',
                                        '$currencySymbol${_formatAmount(netPayments)}',
                                        isDark,
                                        isBold: true,
                                        color: AppTheme.paymentColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Net Receipts and Net Payments Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.receiptColor, width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Net Receipts',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.receiptColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$currencySymbol${_formatAmount(netReceipts)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.receiptColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.paymentColor, width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Net Payments',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.paymentColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$currencySymbol${_formatAmount(netPayments)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.paymentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Closing Balance (Prominent)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Closing Balance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                            Text(
                              '$currencySymbol${_formatAmount(closingBalance)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Format number for reports (removes .00, keeps decimals when needed)
  String _formatAmount(double amount) {
    if (amount == 0.0) {
      return '0.00';
    }
    // Check if the number has decimals
    if (amount == amount.roundToDouble()) {
      // No decimals, show as integer
      return amount.toInt().toString();
    } else {
      // Has decimals, show with decimals (remove trailing zeros)
      String formatted = amount.toStringAsFixed(2);
      // Remove trailing zeros after decimal point
      if (formatted.contains('.')) {
        formatted = formatted.replaceAll(RegExp(r'0+$'), '');
        formatted = formatted.replaceAll(RegExp(r'\.$'), '');
      }
      return formatted;
    }
  }

  // Helper: Build action button for report dialogs
  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Helper: Build report item row for basic report
  Widget _buildReportItemRow(String label, String value, bool isDark,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: color ?? (isDark ? Colors.grey[300] : Colors.black87),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? (isDark ? Colors.white : Colors.black87),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // Show Detailed Report Dialog
  void _showDetailedReport(BuildContext context, AccountingModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = _getCurrencySymbol(model.currency);

    // Calculate totals
    double totalReceiptsCash = model.openingCash;
    double totalReceiptsBank = model.openingBank + model.openingOther;
    double totalPaymentsCash = 0.0;
    double totalPaymentsBank = 0.0;

    // Calculate receipts
    model.receiptAccounts.forEach((key, entries) {
      entries.forEach((entry) {
        entry.rows.forEach((row) {
          totalReceiptsCash += row.cash;
          totalReceiptsBank += row.bank;
        });
      });
    });

    // Calculate payments
    model.paymentAccounts.forEach((key, entries) {
      entries.forEach((entry) {
        entry.rows.forEach((row) {
          totalPaymentsCash += row.cash;
          totalPaymentsBank += row.bank;
        });
      });
    });

    final closingCash = totalReceiptsCash - totalPaymentsCash;
    final closingBank = totalReceiptsBank - totalPaymentsBank;
    final totalClosing = closingCash + closingBank;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and period
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          model.firmName.isNotEmpty
                              ? model.firmName
                              : 'Financial Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 24),
                          iconSize: 24,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          tooltip: 'Close',
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getReportPeriodText(model),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF9FAFB),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPremiumActionButton(
                      'Save Report',
                      Icons.save,
                      AppTheme.primaryColor,
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Save feature coming soon!')),
                        );
                      },
                    ),
                    _buildPremiumActionButton(
                      'Download Excel',
                      Icons.file_download,
                      AppTheme.receiptColor,
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Excel export coming soon!')),
                        );
                      },
                    ),
                    _buildPremiumActionButton(
                      'Download PDF',
                      Icons.picture_as_pdf,
                      AppTheme.paymentColor,
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('PDF export coming soon!')),
                        );
                      },
                    ),
                    _buildActionButton(
                      'Print',
                      Icons.print,
                      isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF374151),
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Print feature coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Firm Name and Period Header
                      Text(
                        model.firmName.isNotEmpty
                            ? model.firmName
                            : 'Financial Report',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getReportPeriodText(model),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(All amounts in ${_getCurrencyName(model.currency)})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Receipts Table
                      _buildDetailedTable(
                        'Receipts ($currencySymbol)',
                        AppTheme.receiptColor,
                        isDark
                            ? const Color(0xFF111827)
                            : const Color(0xFFF0FDF4),
                        [
                          // Table Header
                          _buildTableRow(
                            [
                              'Particulars',
                              'Cash ($currencySymbol)',
                              'Bank ($currencySymbol)',
                              'Total ($currencySymbol)'
                            ],
                            isDark,
                            isHeader: true,
                          ),
                          // Opening Balance
                          _buildTableRow(
                            ['Opening Balances B/F', '', '', ''],
                            isDark,
                            isBold: true,
                          ),
                          // Cash Balance B/F (show only if > 0)
                          if (model.openingCash > 0)
                            _buildTableRow(
                              [
                                '   Cash Balance B/F',
                                _formatAmount(model.openingCash),
                                '0.00',
                                _formatAmount(model.openingCash)
                              ],
                              isDark,
                            ),
                          // Bank Balance B/F (show only if > 0)
                          if (model.openingBank > 0)
                            _buildTableRow(
                              [
                                '   Bank Balance B/F',
                                '0.00',
                                _formatAmount(model.openingBank),
                                _formatAmount(model.openingBank)
                              ],
                              isDark,
                            ),
                          // Other Balance B/F (show only if > 0)
                          if (model.openingOther > 0)
                            _buildTableRow(
                              [
                                '   Other Balance B/F',
                                '0.00',
                                _formatAmount(model.openingOther),
                                _formatAmount(model.openingOther)
                              ],
                              isDark,
                            ),
                          // Custom Balance Boxes (show only if > 0)
                          ...model.customOpeningBalances.entries
                              .where((e) => e.value > 0)
                              .map((entry) {
                            final title = balanceCardTitles[entry.key] ??
                                'Custom Balance';
                            return _buildTableRow(
                              [
                                '   $title',
                                '0.00',
                                _formatAmount(entry.value),
                                _formatAmount(entry.value)
                              ],
                              isDark,
                            );
                          }),
                          // Income Categories
                          ...model.receiptAccounts.entries.expand((entry) {
                            double cash = 0, bank = 0;
                            entry.value.forEach((e) {
                              e.rows.forEach((row) {
                                cash += row.cash;
                                bank += row.bank;
                              });
                            });
                            if (cash + bank > 0) {
                              return [
                                _buildTableRow(
                                  [
                                    model.receiptLabels[entry.key] ?? entry.key,
                                    _formatAmount(cash),
                                    _formatAmount(bank),
                                    _formatAmount(cash + bank)
                                  ],
                                  isDark,
                                )
                              ];
                            }
                            return <Widget>[];
                          }).toList(),
                          // Divider
                          Divider(
                              height: 1,
                              thickness: 2,
                              color: isDark
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFF10B981)),
                          // Total Receipts
                          _buildTableRow(
                            [
                              'Total Receipts',
                              _formatAmount(totalReceiptsCash),
                              _formatAmount(totalReceiptsBank),
                              _formatAmount(
                                  totalReceiptsCash + totalReceiptsBank)
                            ],
                            isDark,
                            isBold: true,
                            color: AppTheme.receiptColor,
                          ),
                        ],
                        isDark,
                      ),

                      const SizedBox(height: 24),

                      // Payments Table
                      _buildDetailedTable(
                        'Payments ($currencySymbol)',
                        AppTheme.paymentColor,
                        isDark
                            ? const Color(0xFF111827)
                            : const Color(0xFFFEF2F2),
                        [
                          // Table Header
                          _buildTableRow(
                            [
                              'Particulars',
                              'Cash ($currencySymbol)',
                              'Bank ($currencySymbol)',
                              'Total ($currencySymbol)'
                            ],
                            isDark,
                            isHeader: true,
                          ),
                          // Expense Categories
                          ...model.paymentAccounts.entries.expand((entry) {
                            double cash = 0, bank = 0;
                            entry.value.forEach((e) {
                              e.rows.forEach((row) {
                                cash += row.cash;
                                bank += row.bank;
                              });
                            });
                            if (cash + bank > 0) {
                              return [
                                _buildTableRow(
                                  [
                                    model.paymentLabels[entry.key] ?? entry.key,
                                    _formatAmount(cash),
                                    _formatAmount(bank),
                                    _formatAmount(cash + bank)
                                  ],
                                  isDark,
                                )
                              ];
                            }
                            return <Widget>[];
                          }).toList(),
                          // Closing Balance C/F
                          _buildTableRow(
                            [
                              'Closing Balance C/F',
                              _formatAmount(closingCash),
                              _formatAmount(closingBank),
                              _formatAmount(totalClosing)
                            ],
                            isDark,
                            isBold: true,
                          ),
                          // Divider
                          Divider(
                              height: 1,
                              thickness: 2,
                              color: isDark
                                  ? const Color(0xFF4B5563)
                                  : AppTheme.paymentColor),
                          // Total Payments
                          _buildTableRow(
                            [
                              'Total Payments',
                              _formatAmount(totalPaymentsCash + closingCash),
                              _formatAmount(totalPaymentsBank + closingBank),
                              _formatAmount(totalPaymentsCash +
                                  totalPaymentsBank +
                                  totalClosing)
                            ],
                            isDark,
                            isBold: true,
                            color: AppTheme.paymentColor,
                          ),
                        ],
                        isDark,
                      ),

                      const SizedBox(height: 24),

                      // Closing Balance Summary
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF111827) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Closing Balance Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Closing Cash',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$currencySymbol${_formatAmount(closingCash)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: closingCash >= 0
                                              ? AppTheme.receiptColor
                                              : AppTheme.paymentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFE5E7EB),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Closing Bank',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$currencySymbol${_formatAmount(closingBank)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: closingBank >= 0
                                              ? AppTheme.receiptColor
                                              : AppTheme.paymentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFE5E7EB),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Total Closing',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$currencySymbol${_formatAmount(totalClosing)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Build detailed table
  Widget _buildDetailedTable(String title, Color headerColor, Color bgColor,
      List<Widget> rows, bool isDark) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: headerColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Table Content
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(
              color: isDark
                  ? const Color(0xFF374151)
                  : headerColor.withValues(alpha: 0.3),
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Column(
            children: rows,
          ),
        ),
      ],
    );
  }

  // Helper: Build table row for detailed report
  Widget _buildTableRow(List<String> cells, bool isDark,
      {bool isHeader = false, bool isBold = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Particulars (40%)
          Expanded(
            flex: 40,
            child: Text(
              cells[0],
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight:
                    isHeader || isBold ? FontWeight.bold : FontWeight.normal,
                color: color ??
                    (isDark
                        ? (isHeader ? Colors.grey[300] : Colors.grey[300])
                        : (isHeader ? Colors.black87 : Colors.black87)),
              ),
            ),
          ),
          // Cash (20%)
          Expanded(
            flex: 20,
            child: Text(
              cells[1],
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight:
                    isHeader || isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Bank (20%)
          Expanded(
            flex: 20,
            child: Text(
              cells[2],
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight:
                    isHeader || isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Total (20%)
          Expanded(
            flex: 20,
            child: Text(
              cells[3],
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight:
                    isHeader || isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Get report period text
  String _getReportPeriodText(AccountingModel model) {
    switch (model.duration) {
      case DurationType.Daily:
        return 'Daily Report - ${model.periodDate.isEmpty ? "No date selected" : model.periodDate}';
      case DurationType.Weekly:
        if (model.periodStartDate.isEmpty || model.periodEndDate.isEmpty) {
          return 'Weekly Report - No period selected';
        }
        return 'Weekly Report - ${model.periodStartDate} to ${model.periodEndDate}';
      case DurationType.Monthly:
        return 'Monthly Report - ${model.periodDate.isEmpty ? "No month selected" : model.periodDate}';
      case DurationType.Yearly:
        return 'Yearly Report - ${model.periodDate.isEmpty ? "No year selected" : model.periodDate}';
      default:
        return 'Report';
    }
  }

  // Helper: Calculate receipts without opening balances
  @override
  void dispose() {
    _headerTitleController.dispose();
    periodController.dispose();
    periodStartController.dispose();
    periodEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: model,
      child: Consumer<AccountingModel>(builder: (context, model, _) {
        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 448),
              margin: const EdgeInsets.symmetric(horizontal: 0),
              child: Container(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back Button
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 14,
                                  color: isDark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Back to Dashboard',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Customizable Header Title (Replaces Logo)
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _headerTitleController.text.isNotEmpty
                                        ? _headerTitleController.text
                                        : _getHeaderHint(widget.templateKey),
                                    style: TextStyle(
                                      fontSize: 28, // Bigger font size
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _headerTitleController.text.isNotEmpty
                                              ? const Color(0xFF4F46E5)
                                              : (isDark
                                                  ? Colors.white24
                                                  : Colors.black12),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () =>
                                      _showHeadingEditDialog(context, isDark),
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 24), // Bigger icon
                                  color: const Color(0xFF4F46E5),
                                  tooltip: 'Edit Heading',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title (editable page title or fallback)
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  model.pageTitle != null &&
                                          model.pageTitle!.isNotEmpty
                                      ? model.pageTitle!
                                      : useCasePageTitle(model.userType),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final current = model.pageTitle != null &&
                                            model.pageTitle!.isNotEmpty
                                        ? model.pageTitle!
                                        : useCasePageTitle(model.userType);
                                    final controller =
                                        TextEditingController(text: current);
                                    final res = await showDialog<String>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: isDark
                                            ? const Color(0xFF1F2937)
                                            : Colors.white,
                                        title: Text(
                                          'Edit Page Title',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        content: TextField(
                                          controller: controller,
                                          autofocus: true,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter page title',
                                            hintStyle: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFF6B7280)
                                                  : const Color(0xFF9CA3AF),
                                            ),
                                            filled: true,
                                            fillColor: isDark
                                                ? const Color(0xFF374151)
                                                : const Color(0xFFF9FAFB),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isDark
                                                    ? const Color(0xFF4B5563)
                                                    : const Color(0xFFD1D5DB),
                                                width: 1.5,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isDark
                                                    ? const Color(0xFF4B5563)
                                                    : const Color(0xFFD1D5DB),
                                                width: 1.5,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: AppTheme.primaryColor,
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: isDark
                                                    ? const Color(0xFF9CA3AF)
                                                    : const Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => Navigator.pop(
                                                context,
                                                controller.text.trim()),
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (res != null && res.isNotEmpty) {
                                      model.setPageTitle(res);
                                    }
                                  },
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                // Show delete button for custom pages
                                if (widget.customPageId != null) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _showDeletePageDialog(context),
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Subtitle
                          Center(
                            child: Text(
                              'Track all Income and Expenses',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Currency Dropdown
                          Center(
                            child: InkWell(
                              onTap: () async {
                                final selected = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: isDark
                                        ? const Color(0xFF1F2937)
                                        : Colors.white,
                                    title: Text(
                                      'Select Currency',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    content: SizedBox(
                                      width: double.maxFinite,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount:
                                            _getAvailableCurrencies().length,
                                        itemBuilder: (context, index) {
                                          final currency =
                                              _getAvailableCurrencies()[index];
                                          final isSelected =
                                              currency == model.currency;
                                          return ListTile(
                                            selected: isSelected,
                                            selectedTileColor: isDark
                                                ? const Color(0xFF374151)
                                                : const Color(0xFFEEF2FF),
                                            leading: Text(
                                              _getCurrencySymbol(currency),
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? const Color(0xFF4F46E5)
                                                    : (isDark
                                                        ? Colors.grey[400]
                                                        : Colors.grey[700]),
                                              ),
                                            ),
                                            title: Text(
                                              currency,
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? const Color(0xFF4F46E5)
                                                    : (isDark
                                                        ? Colors.white
                                                        : Colors.black87),
                                              ),
                                            ),
                                            subtitle: Text(
                                              _getCurrencyName(currency),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                            trailing: isSelected
                                                ? const Icon(
                                                    Icons.check_circle,
                                                    color: Color(0xFF4F46E5),
                                                  )
                                                : null,
                                            onTap: () => Navigator.pop(
                                                context, currency),
                                          );
                                        },
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (selected != null &&
                                    selected != model.currency) {
                                  model.setCurrency(selected);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : Colors.white,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF4B5563)
                                        : const Color(0xFFD1D5DB),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getCurrencySymbol(model.currency),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${model.currency} - ${_getCurrencyName(model.currency)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? const Color(0xFFE5E7EB)
                                            : const Color(0xFF374151),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: isDark
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Report Duration and Select Period
                          _buildDurationAndPeriod(isDark, model),
                          const SizedBox(height: 16),

                          // Report Buttons
                          Row(
                            children: [
                              // View Report Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showBasicReport(context, model);
                                  },
                                  icon: const Icon(Icons.description, size: 20),
                                  label: const Text(
                                    'View Report',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Detailed View Report Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showDetailedReport(context, model);
                                  },
                                  icon: const Icon(Icons.article, size: 20),
                                  label: const Text(
                                    'Detail Report',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.receiptColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Opening Balances Section
                          _buildOpeningBalancesSection(isDark, model),
                          const SizedBox(height: 24),

                          // Income Section
                          _buildIncomeSection(isDark, model),
                          const SizedBox(height: 24),

                          // Expenses Section
                          _buildExpensesSection(isDark, model),
                          const SizedBox(height: 24),

                          // Financial Summary
                          _buildFinancialSummary(isDark, model),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOpeningBalancesSection(bool isDark, AccountingModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? Color.fromRGBO(17, 24, 39, 0.5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                isOpeningBalancesExpanded = !isOpeningBalancesExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Opening Balances B/F',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.receiptColor,
                  ),
                ),
                Icon(
                  isOpeningBalancesExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: isDark
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
          if (isOpeningBalancesExpanded) ...[
            const SizedBox(height: 12),
            // Default balance cards (non-deletable)
            _buildBalanceCard(
                isDark,
                'cash',
                balanceCardTitles['cash']!,
                balanceCardDescriptions['cash']!,
                false,
                Icons.account_balance_wallet_outlined,
                const Color(0xFF10B981), // Green
                "PREVIOUS DAY'S CLOSING"),
            const SizedBox(height: 12),
            _buildBalanceCard(
                isDark,
                'bank',
                balanceCardTitles['bank']!,
                balanceCardDescriptions['bank']!,
                false,
                Icons.account_balance_outlined,
                const Color(0xFF3B82F6), // Blue
                "PREVIOUS DAY'S CLOSING"),
            const SizedBox(height: 12),
            _buildBalanceCard(
                isDark,
                'other',
                balanceCardTitles['other']!,
                balanceCardDescriptions['other']!,
                false,
                Icons.savings_outlined,
                const Color(0xFFF59E0B), // Amber
                "PREVIOUS DAY'S CLOSING"),

            // Custom balance cards (deletable)
            ...model.customOpeningBalances.keys.map((key) {
              return Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _buildCustomBalanceCard(isDark, key),
              );
            }).toList(),

            // Add Balance Box button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addNewBalanceBox(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Balance Box'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.receiptColor,
                  side: const BorderSide(color: AppTheme.receiptColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
      bool isDark,
      String cardType,
      String title,
      String description,
      bool isDeletable,
      IconData icon,
      Color iconColor,
      String subtitle) {
    return BalanceCard(
      isDark: isDark,
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      initialDescription: description,
      onTitleChanged: (newTitle) {
        model.setBalanceCardTitle(cardType, newTitle);
        setState(() {
          balanceCardTitles[cardType] = newTitle;
        });
      },
      onDescriptionChanged: (newDescription) {
        model.setBalanceCardDescription(cardType, newDescription);
        setState(() {
          balanceCardDescriptions[cardType] = newDescription;
        });
      },
      onAmountChanged: (newAmount) {
        final value = double.tryParse(newAmount) ?? 0.0;
        // Determine which balance to update based on cardType
        if (cardType == 'cash') {
          model.setOpeningBalances(
            cash: value,
            bank: model.openingBank,
            other: model.openingOther,
          );
        } else if (cardType == 'bank') {
          model.setOpeningBalances(
            cash: model.openingCash,
            bank: value,
            other: model.openingOther,
          );
        } else if (cardType == 'other') {
          model.setOpeningBalances(
            cash: model.openingCash,
            bank: model.openingBank,
            other: value,
          );
        }
      },
    );
  }

  Widget _buildCustomBalanceCard(bool isDark, String key) {
    // Get or initialize title and description for custom balance
    if (!balanceCardTitles.containsKey(key)) {
      balanceCardTitles[key] = 'Custom Balance';
    }
    if (!balanceCardDescriptions.containsKey(key)) {
      balanceCardDescriptions[key] = '';
    }

    return Stack(
      children: [
        BalanceCard(
          isDark: isDark,
          title: balanceCardTitles[key]!,
          subtitle: 'CUSTOM OPENING BALANCE',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: const Color(0xFF8B5CF6), // Purple
          initialDescription: balanceCardDescriptions[key]!,
          onTitleChanged: (newTitle) {
            model.setBalanceCardTitle(key, newTitle);
            setState(() {
              balanceCardTitles[key] = newTitle;
            });
          },
          onDescriptionChanged: (newDescription) {
            model.setBalanceCardDescription(key, newDescription);
            setState(() {
              balanceCardDescriptions[key] = newDescription;
            });
          },
          onAmountChanged: (newAmount) {
            final value = double.tryParse(newAmount) ?? 0.0;
            model.setCustomOpeningBalance(key, value);
          },
        ),
        // Delete button
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade400,
              size: 20,
            ),
            onPressed: () => _deleteBalanceBox(key),
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(),
          ),
        ),
      ],
    );
  }

  void _addNewBalanceBox() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final key = 'custom_balance_$timestamp';

    setState(() {
      model.addCustomOpeningBalance(key);
      balanceCardTitles[key] = 'Custom Balance';
      balanceCardDescriptions[key] = '';
    });
  }

  void _deleteBalanceBox(String key) {
    setState(() {
      model.removeCustomOpeningBalance(key);
      balanceCardTitles.remove(key);
      balanceCardDescriptions.remove(key);
    });
  }

  // Helper methods for live calculations
  String _formatCategoryTotal(String accountKey, bool isExpense) {
    final total =
        model.calculateAccountTotalByKey(accountKey, receipt: !isExpense);
    return '${_getCurrencySymbol(model.currency)}${total.toStringAsFixed(2)}';
  }

  void _addNewCategoryBox(bool isReceipt) {
    // Generate unique key with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final key = 'custom_${isReceipt ? 'receipt' : 'payment'}_$timestamp';

    if (isReceipt) {
      model.addReceiptAccount(key);
    } else {
      model.addPaymentAccount(key);
    }

    // Initialize expansion state for new box
    setState(() {
      categoryExpansionState[key] = true;
    });
  }

  Widget _buildIncomeSection(bool isDark, AccountingModel model) {
    // Switch based on user type to call the appropriate builder
    switch (model.userType) {
      case UserType.personal:
        return _buildPersonalIncome(isDark, model);
      case UserType.business:
        return _buildBusinessIncome(isDark, model);
      case UserType.institute:
        return _buildInstituteIncome(isDark, model);
      case UserType.other:
        return _buildOtherIncome(isDark, model);
    }
  }

  // OTHER INCOME CATEGORIES
  Widget _buildOtherIncome(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.receiptColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: AppTheme.receiptColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Receipts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.receiptColor,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _addNewCategoryBox(true); // true = receipt/income
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.receiptColor,
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.receiptColor : AppTheme.receiptColor,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamically render any custom receipt accounts (new boxes added by user) - AT TOP
          ...model.receiptAccounts.keys
              .where((key) => key.startsWith('custom_receipt_'))
              .map((key) {
            return Column(
              children: [
                _buildCategoryCard(
                  isDark,
                  key,
                  model.receiptLabels[key] ?? 'New Income Category',
                  _formatCategoryTotal(key, false),
                  AppTheme.receiptColor,
                  categoryExpansionState[key] ?? true,
                  () {
                    setState(() {
                      categoryExpansionState[key] =
                          !(categoryExpansionState[key] ?? true);
                    });
                  },
                  showEntry: categoryExpansionState[key] ?? true,
                  receipt: true,
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          _buildCategoryCard(
            isDark,
            'other_income',
            'Other Income',
            _formatCategoryTotal('other_income', false),
            AppTheme.receiptColor,
            categoryExpansionState['other_income'] ?? true,
            () {
              setState(() {
                categoryExpansionState['other_income'] =
                    !(categoryExpansionState['other_income'] ?? true);
              });
            },
            showEntry: categoryExpansionState['other_income'] ?? true,
            receipt: true,
          ),
        ],
      ),
    );
  }

  // PERSONAL INCOME CATEGORIES
  // PERSONAL INCOME CATEGORIES
  Widget _buildPersonalIncome(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.receiptColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: AppTheme.receiptColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Income',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.receiptColor,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _addNewCategoryBox(true); // true = receipt/income
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.receiptColor,
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.receiptColor : AppTheme.receiptColor,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamically render any custom receipt accounts (new boxes added by user) - AT TOP
          ...model.receiptAccounts.keys
              .where((key) => key.startsWith('custom_receipt_'))
              .map((key) {
            return Column(
              children: [
                _buildCategoryCard(
                  isDark,
                  key,
                  model.receiptLabels[key] ?? 'New Income Category',
                  _formatCategoryTotal(key, false),
                  AppTheme.receiptColor,
                  categoryExpansionState[key] ?? true,
                  () {
                    setState(() {
                      categoryExpansionState[key] =
                          !(categoryExpansionState[key] ?? true);
                    });
                  },
                  showEntry: categoryExpansionState[key] ?? true,
                  receipt: true,
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          _buildCategoryCard(
            isDark,
            'salary',
            'Salary / Wages',
            _formatCategoryTotal('salary', false),
            AppTheme.receiptColor,
            categoryExpansionState['salary'] ?? true,
            () {
              setState(() {
                categoryExpansionState['salary'] =
                    !(categoryExpansionState['salary'] ?? true);
              });
            },
            showEntry: categoryExpansionState['salary'] ?? true,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'business_income',
            'Business Income',
            _formatCategoryTotal('business_income', false),
            AppTheme.receiptColor,
            categoryExpansionState['business_income'] ?? false,
            () {
              setState(() {
                categoryExpansionState['business_income'] =
                    !(categoryExpansionState['business_income'] ?? false);
              });
            },
            showEntry: categoryExpansionState['business_income'] ?? false,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'rental_income',
            'Rental Income',
            _formatCategoryTotal('rental_income', false),
            AppTheme.receiptColor,
            categoryExpansionState['rental_income'] ?? false,
            () {
              setState(() {
                categoryExpansionState['rental_income'] =
                    !(categoryExpansionState['rental_income'] ?? false);
              });
            },
            showEntry: categoryExpansionState['rental_income'] ?? false,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'investment_returns',
            'Investment Returns / Interest',
            _formatCategoryTotal('investment_returns', false),
            AppTheme.receiptColor,
            categoryExpansionState['investment_returns'] ?? false,
            () {
              setState(() {
                categoryExpansionState['investment_returns'] =
                    !(categoryExpansionState['investment_returns'] ?? false);
              });
            },
            showEntry: categoryExpansionState['investment_returns'] ?? false,
            receipt: true,
          ),
        ],
      ),
    );
  }

  // BUSINESS INCOME CATEGORIES
  // BUSINESS INCOME CATEGORIES
  Widget _buildBusinessIncome(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.receiptColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store_rounded,
                      color: AppTheme.receiptColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sales (Receipts)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.receiptColor,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _addNewCategoryBox(true); // true = receipt/income
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.receiptColor,
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.receiptColor : AppTheme.receiptColor,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamically render any custom receipt accounts (new boxes added by user) - AT TOP
          ...model.receiptAccounts.keys
              .where((key) => key.startsWith('custom_receipt_'))
              .map((key) {
            return Column(
              children: [
                _buildCategoryCard(
                  isDark,
                  key,
                  model.receiptLabels[key] ?? 'New Income Category',
                  _formatCategoryTotal(key, false),
                  AppTheme.receiptColor,
                  categoryExpansionState[key] ?? true,
                  () {
                    setState(() {
                      categoryExpansionState[key] =
                          !(categoryExpansionState[key] ?? true);
                    });
                  },
                  showEntry: categoryExpansionState[key] ?? true,
                  receipt: true,
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          _buildCategoryCard(
            isDark,
            'sales',
            'Sales Revenue',
            _formatCategoryTotal('sales', false),
            AppTheme.receiptColor,
            categoryExpansionState['sales'] ?? true,
            () {
              setState(() {
                categoryExpansionState['sales'] =
                    !(categoryExpansionState['sales'] ?? true);
              });
            },
            showEntry: categoryExpansionState['sales'] ?? true,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'service_income',
            'Service Income',
            _formatCategoryTotal('service_income', false),
            AppTheme.receiptColor,
            categoryExpansionState['service_income'] ?? false,
            () {
              setState(() {
                categoryExpansionState['service_income'] =
                    !(categoryExpansionState['service_income'] ?? false);
              });
            },
            showEntry: categoryExpansionState['service_income'] ?? false,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'interest_received',
            'Interest Received',
            _formatCategoryTotal('interest_received', false),
            AppTheme.receiptColor,
            categoryExpansionState['interest_received'] ?? false,
            () {
              setState(() {
                categoryExpansionState['interest_received'] =
                    !(categoryExpansionState['interest_received'] ?? false);
              });
            },
            showEntry: categoryExpansionState['interest_received'] ?? false,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'commission_received',
            'Commission Received',
            _formatCategoryTotal('commission_received', false),
            AppTheme.receiptColor,
            categoryExpansionState['commission_received'] ?? false,
            () {
              setState(() {
                categoryExpansionState['commission_received'] =
                    !(categoryExpansionState['commission_received'] ?? false);
              });
            },
            showEntry: categoryExpansionState['commission_received'] ?? false,
            receipt: true,
          ),
        ],
      ),
    );
  }

  // INSTITUTE/ORGANIZATION INCOME CATEGORIES
  // INSTITUTE/ORGANIZATION INCOME CATEGORIES
  Widget _buildInstituteIncome(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.receiptColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: AppTheme.receiptColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Receipts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.receiptColor,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _addNewCategoryBox(true); // true = receipt/income
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.receiptColor,
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.receiptColor : AppTheme.receiptColor,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamically render any custom receipt accounts (new boxes added by user) - AT TOP
          ...model.receiptAccounts.keys
              .where((key) => key.startsWith('custom_receipt_'))
              .map((key) {
            return Column(
              children: [
                _buildCategoryCard(
                  isDark,
                  key,
                  model.receiptLabels[key] ?? 'New Income Category',
                  _formatCategoryTotal(key, false),
                  AppTheme.receiptColor,
                  categoryExpansionState[key] ?? true,
                  () {
                    setState(() {
                      categoryExpansionState[key] =
                          !(categoryExpansionState[key] ?? true);
                    });
                  },
                  showEntry: categoryExpansionState[key] ?? true,
                  receipt: true,
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          _buildCategoryCard(
            isDark,
            'fees_collected',
            'Fees Collected (Tuition / Admission)',
            _formatCategoryTotal('fees_collected', false),
            AppTheme.receiptColor,
            categoryExpansionState['fees_collected'] ?? true,
            () {
              setState(() {
                categoryExpansionState['fees_collected'] =
                    !(categoryExpansionState['fees_collected'] ?? true);
              });
            },
            showEntry: categoryExpansionState['fees_collected'] ?? true,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'exam_fees',
            'Exam Fees',
            _formatCategoryTotal('exam_fees', false),
            AppTheme.receiptColor,
            categoryExpansionState['exam_fees'] ?? false,
            () {
              setState(() {
                categoryExpansionState['exam_fees'] =
                    !(categoryExpansionState['exam_fees'] ?? false);
              });
            },
            showEntry: categoryExpansionState['exam_fees'] ?? false,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'donations',
            'Donations Received',
            _formatCategoryTotal('donations', false),
            AppTheme.receiptColor,
            categoryExpansionState['donations'] ?? false,
            () {
              setState(() {
                categoryExpansionState['donations'] =
                    !(categoryExpansionState['donations'] ?? false);
              });
            },
            showEntry: categoryExpansionState['donations'] ?? false,
            receipt: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'grants',
            'Grants / Subsidies',
            _formatCategoryTotal('grants', false),
            AppTheme.receiptColor,
            categoryExpansionState['grants'] ?? false,
            () {
              setState(() {
                categoryExpansionState['grants'] =
                    !(categoryExpansionState['grants'] ?? false);
              });
            },
            showEntry: categoryExpansionState['grants'] ?? false,
            receipt: true,
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesSection(bool isDark, AccountingModel model) {
    // Switch based on user type to call the appropriate builder
    switch (model.userType) {
      case UserType.personal:
        return _buildPersonalExpenses(isDark, model);
      case UserType.business:
        return _buildBusinessExpenses(isDark, model);
      case UserType.institute:
        return _buildInstituteExpenses(isDark, model);
      case UserType.other:
        return _buildOtherExpenses(isDark, model);
    }
  }

  // PERSONAL EXPENSES CATEGORIES
  // PERSONAL EXPENSES CATEGORIES
  Widget _buildPersonalExpenses(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.paymentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: AppTheme.paymentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Expenses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.paymentColor,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _addNewCategoryBox(false); // false = payment/expense
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.paymentColor,
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.paymentColor : AppTheme.paymentColor,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamically render any custom payment accounts at the top
          ...model.paymentAccounts.keys
              .where((key) => key.startsWith('custom_payment_'))
              .map((key) {
            return Column(
              children: [
                _buildCategoryCard(
                  isDark,
                  key,
                  model.paymentLabels[key] ?? 'New Expense Category',
                  _formatCategoryTotal(key, true),
                  AppTheme.paymentColor,
                  categoryExpansionState[key] ?? true,
                  () {
                    setState(() {
                      categoryExpansionState[key] =
                          !(categoryExpansionState[key] ?? true);
                    });
                  },
                  showEntry: categoryExpansionState[key] ?? true,
                  isExpense: true,
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          _buildCategoryCard(
            isDark,
            'groceries',
            'Groceries / Food',
            _formatCategoryTotal('groceries', true),
            AppTheme.paymentColor,
            categoryExpansionState['groceries'] ?? true,
            () {
              setState(() {
                categoryExpansionState['groceries'] =
                    !(categoryExpansionState['groceries'] ?? true);
              });
            },
            showEntry: categoryExpansionState['groceries'] ?? true,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'rent_payment',
            'Rent / EMI Payment',
            _formatCategoryTotal('rent_payment', true),
            AppTheme.paymentColor,
            categoryExpansionState['rent_payment'] ?? false,
            () {
              setState(() {
                categoryExpansionState['rent_payment'] =
                    !(categoryExpansionState['rent_payment'] ?? false);
              });
            },
            showEntry: categoryExpansionState['rent_payment'] ?? false,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'education',
            'Education Expenses',
            _formatCategoryTotal('education', true),
            AppTheme.paymentColor,
            categoryExpansionState['education'] ?? false,
            () {
              setState(() {
                categoryExpansionState['education'] =
                    !(categoryExpansionState['education'] ?? false);
              });
            },
            showEntry: categoryExpansionState['education'] ?? false,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'transport',
            'Transport / Fuel',
            _formatCategoryTotal('transport', true),
            AppTheme.paymentColor,
            categoryExpansionState['transport'] ?? false,
            () {
              setState(() {
                categoryExpansionState['transport'] =
                    !(categoryExpansionState['transport'] ?? false);
              });
            },
            showEntry: categoryExpansionState['transport'] ?? false,
            isExpense: true,
          ),
        ],
      ),
    );
  }

  // BUSINESS EXPENSES CATEGORIES
  // BUSINESS EXPENSES CATEGORIES
  Widget _buildBusinessExpenses(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.paymentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: AppTheme.paymentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Purchases (Payments)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.paymentColor,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _addNewCategoryBox(false); // false = payment/expense
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.paymentColor,
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.paymentColor : AppTheme.paymentColor,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamically render any custom payment accounts at the top
          ...model.paymentAccounts.keys
              .where((key) => key.startsWith('custom_payment_'))
              .map((key) {
            return Column(
              children: [
                _buildCategoryCard(
                  isDark,
                  key,
                  model.paymentLabels[key] ?? 'New Expense Category',
                  _formatCategoryTotal(key, true),
                  AppTheme.paymentColor,
                  categoryExpansionState[key] ?? true,
                  () {
                    setState(() {
                      categoryExpansionState[key] =
                          !(categoryExpansionState[key] ?? true);
                    });
                  },
                  showEntry: categoryExpansionState[key] ?? true,
                  isExpense: true,
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          _buildCategoryCard(
            isDark,
            'purchases',
            'Raw Material / Goods Purchase',
            _formatCategoryTotal('purchases', true),
            AppTheme.paymentColor,
            categoryExpansionState['purchases'] ?? true,
            () {
              setState(() {
                categoryExpansionState['purchases'] =
                    !(categoryExpansionState['purchases'] ?? true);
              });
            },
            showEntry: categoryExpansionState['purchases'] ?? true,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'salaries',
            'Salaries / Wages',
            _formatCategoryTotal('salaries', true),
            AppTheme.paymentColor,
            categoryExpansionState['salaries'] ?? false,
            () {
              setState(() {
                categoryExpansionState['salaries'] =
                    !(categoryExpansionState['salaries'] ?? false);
              });
            },
            showEntry: categoryExpansionState['salaries'] ?? false,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'rent_commercial',
            'Rent / Lease',
            _formatCategoryTotal('rent_commercial', true),
            AppTheme.paymentColor,
            categoryExpansionState['rent_commercial'] ?? false,
            () {
              setState(() {
                categoryExpansionState['rent_commercial'] =
                    !(categoryExpansionState['rent_commercial'] ?? false);
              });
            },
            showEntry: categoryExpansionState['rent_commercial'] ?? false,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'utilities_business',
            'Utilities (Power / Water / Internet)',
            _formatCategoryTotal('utilities_business', true),
            AppTheme.paymentColor,
            categoryExpansionState['utilities_business'] ?? false,
            () {
              setState(() {
                categoryExpansionState['utilities_business'] =
                    !(categoryExpansionState['utilities_business'] ?? false);
              });
            },
            showEntry: categoryExpansionState['utilities_business'] ?? false,
            isExpense: true,
          ),
        ],
      ),
    );
  }

  // INSTITUTE/ORGANIZATION EXPENSES CATEGORIES
  // INSTITUTE/ORGANIZATION EXPENSES CATEGORIES
  Widget _buildInstituteExpenses(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.paymentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: AppTheme.paymentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Payments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.paymentColor,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _addNewCategoryBox(false); // false = payment/expense
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.paymentColor,
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.paymentColor : AppTheme.paymentColor,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamically render any custom payment accounts at the top
          ...model.paymentAccounts.keys
              .where((key) => key.startsWith('custom_payment_'))
              .map((key) {
            return Column(
              children: [
                _buildCategoryCard(
                  isDark,
                  key,
                  model.paymentLabels[key] ?? 'New Expense Category',
                  _formatCategoryTotal(key, true),
                  AppTheme.paymentColor,
                  categoryExpansionState[key] ?? true,
                  () {
                    setState(() {
                      categoryExpansionState[key] =
                          !(categoryExpansionState[key] ?? true);
                    });
                  },
                  showEntry: categoryExpansionState[key] ?? true,
                  isExpense: true,
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          _buildCategoryCard(
            isDark,
            'staff_salaries',
            'Staff Salaries (Teaching)',
            _formatCategoryTotal('staff_salaries', true),
            AppTheme.paymentColor,
            categoryExpansionState['staff_salaries'] ?? true,
            () {
              setState(() {
                categoryExpansionState['staff_salaries'] =
                    !(categoryExpansionState['staff_salaries'] ?? true);
              });
            },
            showEntry: categoryExpansionState['staff_salaries'] ?? true,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'non_teaching_salaries',
            'Non-Teaching Staff Salaries',
            _formatCategoryTotal('non_teaching_salaries', true),
            AppTheme.paymentColor,
            categoryExpansionState['non_teaching_salaries'] ?? false,
            () {
              setState(() {
                categoryExpansionState['non_teaching_salaries'] =
                    !(categoryExpansionState['non_teaching_salaries'] ?? false);
              });
            },
            showEntry: categoryExpansionState['non_teaching_salaries'] ?? false,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'utilities_inst',
            'Utilities (Electricity / Water / Internet)',
            _formatCategoryTotal('utilities_inst', true),
            AppTheme.paymentColor,
            categoryExpansionState['utilities_inst'] ?? false,
            () {
              setState(() {
                categoryExpansionState['utilities_inst'] =
                    !(categoryExpansionState['utilities_inst'] ?? false);
              });
            },
            showEntry: categoryExpansionState['utilities_inst'] ?? false,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'library_supplies',
            'Library / Books / Supplies',
            _formatCategoryTotal('library_supplies', true),
            AppTheme.paymentColor,
            categoryExpansionState['library_supplies'] ?? false,
            () {
              setState(() {
                categoryExpansionState['library_supplies'] =
                    !(categoryExpansionState['library_supplies'] ?? false);
              });
            },
            showEntry: categoryExpansionState['library_supplies'] ?? false,
            isExpense: true,
          ),
        ],
      ),
    );
  }

  // OTHER EXPENSES CATEGORIES
  // OTHER EXPENSES CATEGORIES
  Widget _buildOtherExpenses(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.paymentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: AppTheme.paymentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Payments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.paymentColor,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _addNewCategoryBox(false); // false = payment/expense
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.paymentColor,
                  side: BorderSide(
                    color:
                        isDark ? AppTheme.paymentColor : AppTheme.paymentColor,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dynamically render any custom payment accounts at the top
          ...model.paymentAccounts.keys
              .where((key) => key.startsWith('custom_payment_'))
              .map((key) {
            return Column(
              children: [
                _buildCategoryCard(
                  isDark,
                  key,
                  model.paymentLabels[key] ?? 'New Expense Category',
                  _formatCategoryTotal(key, true),
                  AppTheme.paymentColor,
                  categoryExpansionState[key] ?? true,
                  () {
                    setState(() {
                      categoryExpansionState[key] =
                          !(categoryExpansionState[key] ?? true);
                    });
                  },
                  showEntry: categoryExpansionState[key] ?? true,
                  isExpense: true,
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          _buildCategoryCard(
            isDark,
            'expense_1',
            'Expense 1',
            _formatCategoryTotal('expense_1', true),
            AppTheme.paymentColor,
            categoryExpansionState['expense_1'] ?? true,
            () {
              setState(() {
                categoryExpansionState['expense_1'] =
                    !(categoryExpansionState['expense_1'] ?? true);
              });
            },
            showEntry: categoryExpansionState['expense_1'] ?? true,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'expense_2',
            'Expense 2',
            _formatCategoryTotal('expense_2', true),
            AppTheme.paymentColor,
            categoryExpansionState['expense_2'] ?? false,
            () {
              setState(() {
                categoryExpansionState['expense_2'] =
                    !(categoryExpansionState['expense_2'] ?? false);
              });
            },
            showEntry: categoryExpansionState['expense_2'] ?? false,
            isExpense: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            isDark,
            'expense_3',
            'Expense 3',
            _formatCategoryTotal('expense_3', true),
            AppTheme.paymentColor,
            categoryExpansionState['expense_3'] ?? false,
            () {
              setState(() {
                categoryExpansionState['expense_3'] =
                    !(categoryExpansionState['expense_3'] ?? false);
              });
            },
            showEntry: categoryExpansionState['expense_3'] ?? false,
            isExpense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    bool isDark,
    String accountKey,
    String title,
    String amount,
    Color color,
    bool isExpanded,
    VoidCallback onToggle, {
    bool showEntry = false,
    bool isExpense = false,
    bool receipt = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? Color.fromRGBO(17, 24, 39, 0.5) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          // Read current title from model
                          final current = isExpense
                              ? (model.paymentLabels[accountKey] ?? title)
                              : (model.receiptLabels[accountKey] ?? title);
                          final controller =
                              TextEditingController(text: current);
                          final res = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: isDark
                                  ? const Color(0xFF1F2937)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text(
                                'Edit Title',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: TextField(
                                controller: controller,
                                autofocus: true,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter title',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF6B7280)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () => Navigator.pop(
                                      context, controller.text.trim()),
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                          if (res != null && res.isNotEmpty) {
                            if (isExpense) {
                              model.setPaymentLabel(accountKey, res);
                            } else {
                              model.setReceiptLabel(accountKey, res);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF6366F1).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Consumer<AccountingModel>(
                          builder: (context, model, child) {
                            final displayTitle = isExpense
                                ? (model.paymentLabels[accountKey] ?? title)
                                : (model.receiptLabels[accountKey] ?? title);

                            return Text(
                              displayTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFF9FAFB)
                                    : const Color(0xFF1F2937),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          model.addEntryToAccount(accountKey,
                              receipt: !isExpense);
                        },
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          // Show confirmation dialog
                          final categoryName = isExpense
                              ? (model.paymentLabels[accountKey] ??
                                  'this category')
                              : (model.receiptLabels[accountKey] ??
                                  'this category');

                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Duplicate Category'),
                              content: Text(
                                  'Create a copy of "$categoryName" with all its entries and data?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                  ),
                                  child: const Text('Duplicate'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            if (isExpense) {
                              model.duplicatePaymentAccount(accountKey);
                            } else {
                              model.duplicateReceiptAccount(accountKey);
                            }
                          }
                        },
                        child: Icon(
                          Icons.content_copy,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          // Show confirmation dialog
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Category'),
                              content: Text(
                                  'Are you sure you want to delete this category? All entries will be lost.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            if (isExpense) {
                              model.removePaymentAccount(accountKey);
                            } else {
                              model.removeReceiptAccount(accountKey);
                            }
                          }
                        },
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Consumer<AccountingModel>(
                      builder: (context, model, child) {
                        final total = model.calculateAccountTotalByKey(
                            accountKey,
                            receipt: !isExpense);
                        return Text(
                          '${_getCurrencySymbol(model.currency)}${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: color,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showEntry) ...[
            const SizedBox(height: 12),
            _buildEntryBox(isDark, isExpense, accountKey),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryBox(bool isDark, bool isExpense, String accountKey) {
    return Consumer<AccountingModel>(
      builder: (context, m, child) {
        final accounts = isExpense ? m.paymentAccounts : m.receiptAccounts;
        final entries = accounts[accountKey] ?? [];

        if (entries.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              border: Border.all(
                color:
                    isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'No entries yet. Click "+ Add New Entry Box" above to get started.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }

        return Column(
          children: entries.asMap().entries.map((entryMap) {
            final entryIndex = entryMap.key;
            final entry = entryMap.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ENTRY #${entryIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      if (entries.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.redAccent,
                          tooltip: 'Remove entry',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            m.removeEntryFromAccount(accountKey, entry.id,
                                receipt: !isExpense);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Description/Source',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    key: ValueKey('desc_${entry.id}'),
                    initialValue: entry.description,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g., Transaction ID / Payee Name / Date',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF9CA3AF),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF374151)
                          : const Color(
                              0xFFF9FAFB), // Very light gray for light mode
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFFF9FAFB)
                          : const Color(0xFF111827),
                    ),
                    onChanged: (value) {
                      m.updateEntryDescription(accountKey, entry.id, value,
                          receipt: !isExpense);
                    },
                  ),
                  const SizedBox(height: 12),
                  ...entry.rows.asMap().entries.map((rowMap) {
                    final row = rowMap.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        key: ValueKey(
                            '${entry.id}_${row.id}'), // Force rebuild when data changes
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cash:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  key: ValueKey('cash_${entry.id}_${row.id}'),
                                  initialValue:
                                      row.cash == 0 ? '' : row.cash.toString(),
                                  textAlign: TextAlign.right,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? const Color(0xFF6B7280)
                                          : const Color(0xFF9CA3AF),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF4B5563)
                                            : const Color(0xFFD1D5DB),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF4B5563)
                                            : const Color(0xFFD1D5DB),
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF374151)
                                        : Colors.white,
                                    contentPadding: const EdgeInsets.all(8),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? const Color(0xFFF9FAFB)
                                        : const Color(0xFF111827),
                                  ),
                                  onChanged: (value) {
                                    final parsed =
                                        double.tryParse(value) ?? 0.0;
                                    m.updateRowValue(
                                        accountKey, entry.id, row.id,
                                        cash: parsed, receipt: !isExpense);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bank/Online:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  key: ValueKey('bank_${entry.id}_${row.id}'),
                                  initialValue:
                                      row.bank == 0 ? '' : row.bank.toString(),
                                  textAlign: TextAlign.right,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? const Color(0xFF6B7280)
                                          : const Color(0xFF9CA3AF),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF4B5563)
                                            : const Color(0xFFD1D5DB),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF4B5563)
                                            : const Color(0xFFD1D5DB),
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF374151)
                                        : Colors.white,
                                    contentPadding: const EdgeInsets.all(8),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? const Color(0xFFF9FAFB)
                                        : const Color(0xFF111827),
                                  ),
                                  onChanged: (value) {
                                    final parsed =
                                        double.tryParse(value) ?? 0.0;
                                    m.updateRowValue(
                                        accountKey, entry.id, row.id,
                                        bank: parsed, receipt: !isExpense);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                color: Colors.blueAccent,
                                tooltip: 'Duplicate Row',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  m.addRowToEntry(
                                    accountKey,
                                    entry.id,
                                    receipt: !isExpense,
                                    cash: row.cash, // Pass current values
                                    bank: row.bank,
                                    insertAfterRowId:
                                        row.id, // Insert directly after
                                  );
                                },
                              ),
                              if (entry.rows.length > 1)
                                const SizedBox(height: 8),
                              if (entry.rows.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      size: 18),
                                  color: Colors.redAccent,
                                  tooltip: 'Remove row',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    m.removeRowFromEntry(
                                        accountKey, entry.id, row.id,
                                        receipt: !isExpense);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        m.addRowToEntry(accountKey, entry.id,
                            receipt: !isExpense);
                      },
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add Row'),
                      style: TextButton.styleFrom(
                        foregroundColor: isExpense
                            ? AppTheme.paymentColor
                            : AppTheme.receiptColor,
                        backgroundColor: (isExpense
                                ? AppTheme.paymentColor
                                : AppTheme.receiptColor)
                            .withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFinancialSummary(bool isDark, AccountingModel model) {
    return PremiumCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${model.duration.toString().split('.').last.toUpperCase()} SUMMARY',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LIVE FINANCIAL ASSESSMENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  _showSaveReportDialog(context, model);
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('SAVE REPORT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.receiptColor.withValues(alpha: 0.1)
                        : AppTheme.receiptColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.receiptColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Income',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppTheme.formatCurrency(model.receiptsTotal,
                            currency: model.currency),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.receiptColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.paymentColor.withValues(alpha: 0.1)
                        : AppTheme.paymentColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.paymentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Expenses',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppTheme.formatCurrency(model.paymentsTotal,
                            currency: model.currency),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.paymentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Consumer<AccountingModel>(
            builder: (context, model, child) {
              final netSurplus = model.receiptsTotal - model.paymentsTotal;
              final isNegative = netSurplus < 0;
              final color =
                  isNegative ? AppTheme.paymentColor : AppTheme.receiptColor;

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          isNegative ? 'Net Deficit' : 'Net Surplus',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppTheme.formatCurrency(netSurplus,
                              currency: model.currency),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Total Opening (B/F) Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF6366F1)
                                    .withValues(alpha: 0.1) // Indigo
                                : const Color(0xFF6366F1)
                                    .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Total Opening (B/F)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFD1D5DB)
                                      : const Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppTheme.formatCurrency(
                                    model.openingCash +
                                        model.openingBank +
                                        model.openingOther,
                                    currency: model.currency),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1), // Indigo
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Closing Balance (C/F) Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0EA5E9)
                                    .withValues(alpha: 0.1) // Sky Blue
                                : const Color(0xFF0EA5E9)
                                    .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Closing Balance (C/F)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFD1D5DB)
                                      : const Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppTheme.formatCurrency(netSurplus,
                                    currency: model.currency),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0EA5E9), // Sky Blue
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaveReportDialog(BuildContext context, AccountingModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(
      text: 'Report - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Save Report',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Save the current report state to access or edit it later.',
              style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Report Name',
                labelStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final data = jsonEncode(model.exportState());
                model.saveReport(
                  nameController.text,
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  data,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report saved successfully!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
