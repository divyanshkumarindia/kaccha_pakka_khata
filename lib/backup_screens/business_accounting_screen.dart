import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../theme.dart';

class BusinessAccountingScreen extends StatefulWidget {
  const BusinessAccountingScreen({Key? key}) : super(key: key);

  @override
  State<BusinessAccountingScreen> createState() =>
      _BusinessAccountingScreenState();
}

class _BusinessAccountingScreenState extends State<BusinessAccountingScreen> {
  late AccountingModel model;
  late TextEditingController periodController;
  late TextEditingController periodStartController;
  late TextEditingController periodEndController;

  bool isOpeningBalancesExpanded = true;
  bool isSalaryExpanded = true;
  bool isBusinessIncomeExpanded = false;
  bool isGroceriesExpanded = true;
  bool isUtilitiesExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is AccountingModel) {
      model = arg;
    } else {
      model = Provider.of<AccountingModel>(context);
    }
    periodController = TextEditingController(text: model.periodDate);
    periodStartController = TextEditingController(text: model.periodStartDate);
    periodEndController = TextEditingController(text: model.periodEndDate);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

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

  String _weekdayAbbrev(String s) {
    final d = _parseDate(s);
    if (d == null) return '';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
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

    // clamp initial into bounds if provided
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
                    primary: const Color(0xFF6366F1),
                    onPrimary: Colors.white,
                    primaryContainer: const Color(0xFF4F46E5),
                    onPrimaryContainer: Colors.white,
                    secondary: const Color(0xFF818CF8),
                    surface: const Color(0xFF1F2937),
                    onSurface: const Color(0xFFF9FAFB),
                    surfaceVariant: const Color(0xFF374151),
                    onSurfaceVariant: const Color(0xFF9CA3AF),
                    outline: const Color(0xFF4B5563),
                  )
                : ColorScheme.light(
                    primary: const Color(0xFF4F46E5),
                    onPrimary: Colors.white,
                    primaryContainer: const Color(0xFFEEF2FF),
                    onPrimaryContainer: const Color(0xFF312E81),
                    secondary: const Color(0xFF6366F1),
                    surface: Colors.white,
                    onSurface: const Color(0xFF111827),
                    surfaceVariant: const Color(0xFFF3F4F6),
                    onSurfaceVariant: const Color(0xFF6B7280),
                    outline: const Color(0xFFD1D5DB),
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 12,
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
              dayForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected))
                  return Colors.white;
                if (states.contains(MaterialState.disabled))
                  return isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFD1D5DB);
                return isDark
                    ? const Color(0xFFF9FAFB)
                    : const Color(0xFF111827);
              }),
              dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected))
                  return const Color(0xFF4F46E5);
                return Colors.transparent;
              }),
              todayForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected))
                  return Colors.white;
                return const Color(0xFF4F46E5);
              }),
              todayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected))
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
              yearForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected))
                  return Colors.white;
                return isDark
                    ? const Color(0xFFF9FAFB)
                    : const Color(0xFF111827);
              }),
              yearBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected))
                  return const Color(0xFF4F46E5);
                return Colors.transparent;
              }),
              rangePickerBackgroundColor:
                  isDark ? const Color(0xFF1F2937) : Colors.white,
              rangePickerHeaderBackgroundColor: const Color(0xFF4F46E5),
              rangePickerHeaderForegroundColor: Colors.white,
              rangeSelectionBackgroundColor:
                  const Color(0xFF4F46E5).withOpacity(0.15),
              rangeSelectionOverlayColor: MaterialStateProperty.all(
                  const Color(0xFF4F46E5).withOpacity(0.08)),
              dividerColor:
                  isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                  maxHeight: 520,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: child!,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      final startStr = _formatDate(picked.start);
      final endStr = _formatDate(picked.end);
      setState(() {
        periodStartController.text = startStr;
        periodEndController.text = endStr;
      });
      model.setPeriodRange(startStr, endStr);
    }
  }

  Widget _buildDurationAndPeriod(bool isDark, AccountingModel model) {
    return LayoutBuilder(builder: (context, constraints) {
      final full = constraints.maxWidth;
      const gap = 16.0;
      final half = (full - gap) / 2;

      Widget durationDropdown(double width) {
        return SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Duration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : Colors.white,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFD1D5DB),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: model.duration.toString().split('.').last,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFFF9FAFB)
                          : const Color(0xFF111827),
                    ),
                    dropdownColor:
                        isDark ? const Color(0xFF374151) : Colors.white,
                    items: ['Daily', 'Weekly', 'Monthly', 'Yearly']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        final newDur = DurationType.values.firstWhere(
                            (d) => d.toString().split('.').last == newValue,
                            orElse: () => DurationType.Daily);
                        model.setDuration(newDur);
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }

      Widget weeklyPeriod() {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Select Period',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.clear,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280)),
                  tooltip: 'Clear selected dates',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      periodStartController.clear();
                      periodEndController.clear();
                    });
                    model.setPeriodRange('', '');
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _pickDateRange(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : Colors.white,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFD1D5DB),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            periodStartController.text.isEmpty
                                ? 'Start date'
                                : '${_weekdayAbbrev(periodStartController.text)}, ${periodStartController.text}',
                            style: TextStyle(
                              fontSize: 14,
                              color: periodStartController.text.isEmpty
                                  ? (isDark
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF9CA3AF))
                                  : (isDark
                                      ? const Color(0xFFF9FAFB)
                                      : const Color(0xFF111827)),
                            ),
                          ),
                          if (periodStartController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Start date',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            periodEndController.text.isEmpty
                                ? 'End date'
                                : '${_weekdayAbbrev(periodEndController.text)}, ${periodEndController.text}',
                            style: TextStyle(
                              fontSize: 14,
                              color: periodEndController.text.isEmpty
                                  ? (isDark
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF9CA3AF))
                                  : (isDark
                                      ? const Color(0xFFF9FAFB)
                                      : const Color(0xFF111827)),
                            ),
                          ),
                          if (periodEndController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'End date',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      Widget singlePeriod() {
        return Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF374151) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: periodController,
                  readOnly: true,
                  onTap: () => _pickDateFor(
                      context, periodController, (s) => model.setPeriodDate(s)),
                  decoration: InputDecoration(
                    hintText: 'dd-mm-yyyy',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF),
                    ),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFF9FAFB)
                        : const Color(0xFF111827),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _pickDateFor(
                    context, periodController, (s) => model.setPeriodDate(s)),
                child: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isDark
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        );
      }

      if (model.duration != DurationType.Daily) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeInOut,
              width: full,
              child: durationDropdown(full),
            ),
            const SizedBox(height: 12),
            (model.duration == DurationType.Weekly ||
                    model.duration == DurationType.Monthly ||
                    model.duration == DurationType.Yearly)
                ? weeklyPeriod()
                : singlePeriod(),
          ],
        );
      }

      return Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeInOut,
            width: half,
            child: durationDropdown(half),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Period',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 4),
                singlePeriod(),
              ],
            ),
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
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
        // use model duration directly

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

                          // Icon
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFFDCE7FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                size: 32,
                                color: Color(0xFF4F46E5),
                              ),
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
                                        title: const Text('Edit Page Title'),
                                        content: TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                              hintText: 'Enter page title'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
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

                          // Currency Button (show model.currency)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF374151)
                                    : Colors.white,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF4B5563)
                                      : const Color(0xFFD1D5DB),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    model.currency == 'INR'
                                        ? '₹'
                                        : model.currency,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    model.currency == 'INR'
                                        ? '- Indian Rupee'
                                        : '- ${model.currency}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFFE5E7EB)
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Report Duration and Select Period
                          _buildDurationAndPeriod(isDark, model),
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
                          const SizedBox(height: 16),

                          // View Report Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                // show report modal or navigate to report
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 1,
                              ),
                              child: const Text(
                                'View Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
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
        borderRadius: BorderRadius.circular(12),
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
                    color: Color(0xFF059669),
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
            _buildBalanceCard(isDark, 'Balance B/F (Cash Book)',
                model.openingCash.toStringAsFixed(2)),
            const SizedBox(height: 12),
            _buildBalanceCard(isDark, 'Balance B/F (Bank)',
                model.openingBank.toStringAsFixed(2)),
            const SizedBox(height: 12),
            _buildBalanceCard(isDark, 'Balance B/F (Other Funds)',
                model.openingOther.toStringAsFixed(2)),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark, String title, String amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A22) : const Color(0xFFF0FFF4),
        border: Border.all(
          color: isDark ? const Color(0xFF2D4A3A) : const Color(0xFFD4F3E1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 16,
                color: Color(0xFF059669),
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF374151) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF4B5563)
                              : const Color(0xFFD1D5DB),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Previous End Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFF9FAFB)
                              : const Color(0xFF111827),
                        ),
                      ),
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
                      'Amount B/F:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF374151) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF4B5563)
                              : const Color(0xFFD1D5DB),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.centerRight,
                      child: Text(
                        amount,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFF9FAFB)
                              : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeSection(bool isDark, AccountingModel model) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Income',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                model.addEntryToAccount('salary', receipt: true);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add New Entry Box'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF059669),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF15803D)
                      : const Color(0xFF86EFAC),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCategoryCard(
          isDark,
          'salary',
          'Salary / Wages',
          '₹${0.toStringAsFixed(2)}',
          const Color(0xFF059669),
          isSalaryExpanded,
          () {
            setState(() {
              isSalaryExpanded = !isSalaryExpanded;
            });
          },
          showEntry: isSalaryExpanded,
          receipt: true,
        ),
        const SizedBox(height: 12),
        _buildCategoryCard(
          isDark,
          'business_income',
          'Business Income',
          '₹${0.toStringAsFixed(2)}',
          const Color(0xFF059669),
          isBusinessIncomeExpanded,
          () {
            setState(() {
              isBusinessIncomeExpanded = !isBusinessIncomeExpanded;
            });
          },
          receipt: true,
        ),
      ],
    );
  }

  Widget _buildExpensesSection(bool isDark, AccountingModel model) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Expenses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                model.addEntryToAccount('groceries', receipt: false);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add New Entry Box'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF991B1B)
                      : const Color(0xFFFCA5A5),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCategoryCard(
          isDark,
          'groceries',
          'Groceries / Food',
          '₹${0.toStringAsFixed(2)}',
          const Color(0xFFDC2626),
          isGroceriesExpanded,
          () {
            setState(() {
              isGroceriesExpanded = !isGroceriesExpanded;
            });
          },
          showEntry: isGroceriesExpanded,
          isExpense: true,
        ),
        const SizedBox(height: 12),
        _buildCategoryCard(
          isDark,
          'other_expenses',
          'Utilities (Electricity / Water / Gas)',
          '₹${0.toStringAsFixed(2)}',
          const Color(0xFFDC2626),
          isUtilitiesExpanded,
          () {
            setState(() {
              isUtilitiesExpanded = !isUtilitiesExpanded;
            });
          },
          isExpense: true,
        ),
      ],
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
        borderRadius: BorderRadius.circular(12),
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
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFF9FAFB)
                                : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          final m = Provider.of<AccountingModel>(context,
                              listen: false);
                          m.addEntryToAccount(accountKey, receipt: !isExpense);
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
                      Icon(
                        Icons.close,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENTRY #1',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Description/Source',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g., Transaction ID / Payee Name / Date',
              hintStyle: TextStyle(
                fontSize: 14,
                color:
                    isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFD1D5DB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFD1D5DB),
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF374151) : Colors.white,
              contentPadding: const EdgeInsets.all(8),
            ),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
            ),
            controller: TextEditingController(text: '0'),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
                    TextField(
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF374151) : Colors.white,
                        contentPadding: const EdgeInsets.all(8),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFFF9FAFB)
                            : const Color(0xFF111827),
                      ),
                      controller: TextEditingController(text: '0'),
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
                    TextField(
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF374151) : Colors.white,
                        contentPadding: const EdgeInsets.all(8),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFFF9FAFB)
                            : const Color(0xFF111827),
                      ),
                      controller: TextEditingController(text: '0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final m =
                      Provider.of<AccountingModel>(context, listen: false);
                  final accounts =
                      isExpense ? m.paymentAccounts : m.receiptAccounts;
                  final entries = accounts[accountKey];
                  if (entries == null || entries.isEmpty) {
                    m.addEntryToAccount(accountKey, receipt: !isExpense);
                    return;
                  }
                  final lastEntryId = entries.last.id;
                  m.addRowToEntry(accountKey, lastEntryId, receipt: !isExpense);
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isExpense
                      ? const Color(0xFFDC2626)
                      : (isDark
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFF374151)),
                  side: BorderSide(
                    color: isExpense
                        ? (isDark
                            ? const Color(0xFF991B1B)
                            : const Color(0xFFFCA5A5))
                        : (isDark
                            ? const Color(0xFF4B5563)
                            : const Color(0xFFD1D5DB)),
                  ),
                  backgroundColor: isExpense
                      ? (isDark
                          ? Color.fromRGBO(42, 28, 28, 0.5)
                          : Color.fromRGBO(255, 245, 245, 0.5))
                      : (isDark ? const Color(0xFF374151) : Colors.white),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(bool isDark, AccountingModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2135) : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Financial Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C2A22)
                        : const Color(0xFFF0FFF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Income',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTheme.formatCurrency(model.receiptsTotal,
                            currency: model.currency),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A1C1C)
                        : const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Expenses',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTheme.formatCurrency(model.paymentsTotal,
                            currency: model.currency),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2A22) : const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Net Surplus',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTheme.formatCurrency(model.netBalance,
                      currency: model.currency),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
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
