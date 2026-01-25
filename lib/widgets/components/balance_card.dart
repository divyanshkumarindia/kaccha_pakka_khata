import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BalanceCard extends StatefulWidget {
  final bool isDark;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final String? initialDescription;
  final double? initialAmount;
  final Function(String)? onTitleChanged;
  final Function(String)? onDescriptionChanged;
  final Function(String)? onAmountChanged;

  const BalanceCard({
    Key? key,
    required this.isDark,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.initialDescription,
    this.initialAmount,
    this.onTitleChanged,
    this.onDescriptionChanged,
    this.onAmountChanged,
  }) : super(key: key);

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  late TextEditingController descriptionController;
  late TextEditingController amountController;

  @override
  void initState() {
    super.initState();
    // Use saved description or empty string (will show as ghost text)
    descriptionController = TextEditingController(
        text: (widget.initialDescription != null &&
                widget.initialDescription!.isNotEmpty)
            ? widget.initialDescription
            : '');
    // Initialize amount if provided
    String initialAmountText = '';
    if (widget.initialAmount != null && widget.initialAmount! != 0.0) {
      if (widget.initialAmount == widget.initialAmount!.roundToDouble()) {
        initialAmountText = widget.initialAmount!.toInt().toString();
      } else {
        initialAmountText = widget.initialAmount!.toString();
      }
    }
    amountController = TextEditingController(text: initialAmountText);
  }

  @override
  void didUpdateWidget(covariant BalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDescription != oldWidget.initialDescription) {
      if (descriptionController.text != (widget.initialDescription ?? '')) {
        descriptionController.text = widget.initialDescription ?? '';
      }
    }
    if (widget.initialAmount != oldWidget.initialAmount) {
      String newText = '';
      if (widget.initialAmount != null && widget.initialAmount! != 0.0) {
        if (widget.initialAmount == widget.initialAmount!.roundToDouble()) {
          newText = widget.initialAmount!.toInt().toString();
        } else {
          newText = widget.initialAmount!.toString();
        }
      }
      if (amountController.text != newText) {
        amountController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1F2937) : Colors.white,
        border: Border.all(
          color:
              widget.isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: widget.isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF64748B).withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon Container
              if (widget.icon != null) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (widget.iconColor ?? Colors.blue)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor ?? Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final controller =
                                TextEditingController(text: widget.title);
                            final res = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: widget.isDark
                                    ? const Color(0xFF1F2937)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: Text(
                                  'Edit Title',
                                  style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: widget.isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter title',
                                    hintStyle: TextStyle(
                                      color: widget.isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: widget.isDark
                                        ? const Color(0xFF374151)
                                        : const Color(0xFFF1F5F9),
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
                                        color: widget.isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(
                                        context, controller.text.trim()),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            if (res != null &&
                                res.isNotEmpty &&
                                widget.onTitleChanged != null) {
                              widget.onTitleChanged!(res);
                            }
                          },
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: widget.isDark
                                ? Colors.grey[500]
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description/Source',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descriptionController,
                      onChanged: widget.onDescriptionChanged,
                      decoration: InputDecoration(
                        hintText: 'e.g. Previous Balance',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: widget.isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: widget.isDark
                            ? const Color(0xFF111827)
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      onChanged: widget.onAmountChanged,
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: widget.isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: widget.isDark
                            ? const Color(0xFF111827)
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
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
}
