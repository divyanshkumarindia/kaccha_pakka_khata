import 'package:flutter/material.dart';
import '../../state/accounting_model.dart';
import '../../models/accounting.dart';

typedef PickDateFor = Future<void> Function(
    BuildContext, TextEditingController, Function(String),
    {DateTime? initial, DateTime? firstDate, DateTime? lastDate});

typedef PickDateRange = Future<void> Function(BuildContext);

typedef PickYear = Future<void> Function(
    BuildContext, TextEditingController, Function(String));

class DurationPeriodPicker extends StatelessWidget {
  final bool isDark;
  final AccountingModel model;
  final TextEditingController periodController;
  final TextEditingController periodStartController;
  final TextEditingController periodEndController;
  final PickDateFor pickDateFor;
  final PickDateRange pickDateRange;
  final PickYear pickYear;

  const DurationPeriodPicker({
    Key? key,
    required this.isDark,
    required this.model,
    required this.periodController,
    required this.periodStartController,
    required this.periodEndController,
    required this.pickDateFor,
    required this.pickDateRange,
    required this.pickYear,
  }) : super(key: key);

  String _weekdayAbbrev(String s) {
    if (s.isEmpty) return '';
    try {
      final parts = s.split('-');
      if (parts.length == 3) {
        final d = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return names[d.weekday - 1];
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Local parser for dd-mm-yyyy strings from controllers
      DateTime? parseDate(String s) {
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
                model.t('label_report_duration'),
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
                      String localizedValue = value;
                      switch (value) {
                        case 'Daily':
                          localizedValue = model.t('duration_daily');
                          break;
                        case 'Weekly':
                          localizedValue = model.t('duration_weekly');
                          break;
                        case 'Monthly':
                          localizedValue = model.t('duration_monthly');
                          break;
                        case 'Yearly':
                          localizedValue = model.t('duration_yearly');
                          break;
                      }
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(localizedValue),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        final newDur = DurationType.values.firstWhere(
                            (d) => d.toString().split('.').last == newValue,
                            orElse: () => DurationType.Daily);
                        model.setDuration(newDur);

                        // Clear controllers/model fields that aren't relevant for the
                        // newly selected duration so values don't leak between modes.
                        // In particular, prevent Weekly<->Monthly carrying over each other's
                        // ranges by clearing them when switching.
                        switch (newDur) {
                          case DurationType.Daily:
                            // Daily uses the single-day picker only; clear ranges and year
                            periodStartController.clear();
                            periodEndController.clear();
                            model.setPeriodRange('', '');
                            periodController.clear();
                            model.setPeriodDate('');
                            break;
                          case DurationType.Weekly:
                            // When switching to Weekly, clear any Monthly or single-date
                            // values so the user picks a fresh range.
                            periodController.clear();
                            model.setPeriodDate('');
                            periodStartController.clear();
                            periodEndController.clear();
                            model.setPeriodRange('', '');
                            break;
                          case DurationType.Monthly:
                            // When switching to Monthly, clear any Weekly or single-date
                            // values so the user picks a fresh range.
                            periodController.clear();
                            model.setPeriodDate('');
                            periodStartController.clear();
                            periodEndController.clear();
                            model.setPeriodRange('', '');
                            break;
                          case DurationType.Yearly:
                            // Yearly now uses range (same as Weekly)
                            periodController.clear();
                            model.setPeriodDate('');
                            periodStartController.clear();
                            periodEndController.clear();
                            model.setPeriodRange('', '');
                            break;
                        }
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
                  model.t('label_select_period'),
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
                  tooltip: model.t('tooltip_clear_dates'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    periodStartController.clear();
                    periodEndController.clear();
                    model.setPeriodRange('', '');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final endDate = parseDate(periodEndController.text);
                      final DateTime? last = endDate != null
                          ? endDate.subtract(const Duration(days: 1))
                          : null;
                      pickDateFor(
                        context,
                        periodStartController,
                        (s) => model.setPeriodRange(s, model.periodEndDate),
                        lastDate: last,
                      );
                    },
                    child: Container(
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              periodStartController.text.isEmpty
                                  ? model.t('hint_start_date')
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
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final startDate = parseDate(periodStartController.text);
                      final DateTime? first = startDate != null
                          ? startDate.add(const Duration(days: 1))
                          : null;
                      pickDateFor(
                        context,
                        periodEndController,
                        (s) => model.setPeriodRange(model.periodStartDate, s),
                        firstDate: first,
                      );
                    },
                    child: Container(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              periodEndController.text.isEmpty
                                  ? model.t('hint_end_date')
                                  : '${_weekdayAbbrev(periodEndController.text)}, ${periodEndController.text}',
                              textAlign: TextAlign.left,
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
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                child: InkWell(
                  onTap: () => pickDateFor(
                      context, periodController, (s) => model.setPeriodDate(s)),
                  child: Container(
                    height: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      periodController.text.isEmpty
                          ? model.t('hint_date_format')
                          : periodController.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: periodController.text.isEmpty
                            ? (isDark
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF))
                            : (isDark
                                ? const Color(0xFFF9FAFB)
                                : const Color(0xFF111827)),
                      ),
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => pickDateFor(
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

      Widget monthlyPeriod() {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  model.t('label_select_period'),
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
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    periodStartController.clear();
                    periodEndController.clear();
                    model.setPeriodRange('', '');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final endDate = parseDate(periodEndController.text);
                      final DateTime? last = endDate != null
                          ? endDate.subtract(const Duration(days: 1))
                          : null;
                      pickDateFor(
                        context,
                        periodStartController,
                        (s) => model.setPeriodRange(s, model.periodEndDate),
                        lastDate: last,
                      );
                    },
                    child: Container(
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              periodStartController.text.isEmpty
                                  ? model.t('hint_start_date')
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
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final startDate = parseDate(periodStartController.text);
                      final DateTime? first = startDate != null
                          ? startDate.add(const Duration(days: 1))
                          : null;
                      pickDateFor(
                        context,
                        periodEndController,
                        (s) => model.setPeriodRange(model.periodStartDate, s),
                        firstDate: first,
                      );
                    },
                    child: Container(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              periodEndController.text.isEmpty
                                  ? model.t('hint_end_date')
                                  : '${_weekdayAbbrev(periodEndController.text)}, ${periodEndController.text}',
                              textAlign: TextAlign.left,
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
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }

      if (model.duration != DurationType.Daily) {
        // For Yearly we want the compact year box on the right side
        // beside the Report Duration dropdown (same as Daily layout).

        // Other non-daily durations stay stacked under the dropdown
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
            model.duration == DurationType.Weekly ||
                    model.duration == DurationType.Yearly
                ? weeklyPeriod()
                : model.duration == DurationType.Monthly
                    ? monthlyPeriod()
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
                  model.t('label_select_period'),
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
}
