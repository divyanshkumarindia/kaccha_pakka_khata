import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BalanceCard extends StatefulWidget {
  final bool isDark;
  final String title;
  final String amount;
  final Function(String)? onTitleChanged;
  final Function(String)? onDescriptionChanged;
  final Function(String)? onAmountChanged;

  const BalanceCard({
    Key? key,
    required this.isDark,
    required this.title,
    required this.amount,
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
    descriptionController = TextEditingController(text: 'Previous End Date');
    amountController = TextEditingController(text: widget.amount);
  }

  @override
  void didUpdateWidget(BalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      amountController.text = widget.amount;
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            widget.isDark ? const Color(0xFF1C2A22) : const Color(0xFFF0FFF4),
        border: Border.all(
          color:
              widget.isDark ? const Color(0xFF2D4A3A) : const Color(0xFFD4F3E1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final controller = TextEditingController(text: widget.title);
                  final res = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Title'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Enter title',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text.trim()),
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
                child: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFF374151),
                  ),
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
                        color: widget.isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: descriptionController,
                      onChanged: widget.onDescriptionChanged,
                      decoration: InputDecoration(
                        hintText: 'e.g., Previous balance',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: widget.isDark
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF9CA3AF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        filled: true,
                        fillColor: widget.isDark
                            ? const Color(0xFF374151)
                            : Colors.white,
                        contentPadding: const EdgeInsets.all(8),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? const Color(0xFFF9FAFB)
                            : const Color(0xFF111827),
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
                        color: widget.isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
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
                          fontSize: 12,
                          color: widget.isDark
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF9CA3AF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: widget.isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        filled: true,
                        fillColor: widget.isDark
                            ? const Color(0xFF374151)
                            : Colors.white,
                        contentPadding: const EdgeInsets.all(8),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? const Color(0xFFF9FAFB)
                            : const Color(0xFF111827),
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
