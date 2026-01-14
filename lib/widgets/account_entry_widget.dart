import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/accounting.dart';
import '../state/accounting_model.dart';
import '../theme.dart';

class AccountEntryWidget extends StatefulWidget {
  final String keyId;
  final String label;
  final List<TransactionEntry> entries;
  final void Function(List<TransactionEntry>) onChanged;
  final bool isReceipt;

  const AccountEntryWidget(
      {Key? key,
      required this.keyId,
      required this.label,
      required this.entries,
      required this.onChanged,
      this.isReceipt = true})
      : super(key: key);

  @override
  State<AccountEntryWidget> createState() => _AccountEntryWidgetState();
}

class _AccountEntryWidgetState extends State<AccountEntryWidget>
    with TickerProviderStateMixin {
  bool isOpen = true;

  double _subtotal() {
    double sum = 0.0;
    for (var e in widget.entries) {
      for (var r in e.rows) {
        sum += r.cash + r.bank;
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.isReceipt ? AppTheme.receiptColor : AppTheme.paymentColor;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(children: [
        // Header with left accent
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(left: BorderSide(color: accent, width: 6))),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            dense: true,
            title: Text(widget.label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                AppTheme.formatCurrency(_subtotal()),
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              // Edit label
              IconButton(
                  icon: Icon(Icons.edit, color: accent),
                  tooltip: Provider.of<AccountingModel>(context)
                      .t('tooltip_edit_label'),
                  onPressed: () async {
                    final controller =
                        TextEditingController(text: widget.label);
                    final newLabel = await showDialog<String?>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              title: Text(Provider.of<AccountingModel>(context,
                                      listen: false)
                                  .t('dialog_edit_account_label')),
                              content: TextField(
                                  controller: controller,
                                  decoration: const InputDecoration()),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(null),
                                    child: Text(Provider.of<AccountingModel>(
                                            context,
                                            listen: false)
                                        .t('btn_cancel'))),
                                ElevatedButton(
                                    onPressed: () => Navigator.of(ctx)
                                        .pop(controller.text.trim()),
                                    child: Text(Provider.of<AccountingModel>(
                                            context,
                                            listen: false)
                                        .t('btn_save')))
                              ],
                            ));
                    if (newLabel != null && newLabel.isNotEmpty) {
                      final model =
                          Provider.of<AccountingModel>(context, listen: false);
                      if (widget.isReceipt)
                        model.setReceiptLabel(widget.keyId, newLabel);
                      else
                        model.setPaymentLabel(widget.keyId, newLabel);
                    }
                  }),
              // Remove account
              IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: Provider.of<AccountingModel>(context)
                      .t('tooltip_remove_account'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              title: Text(Provider.of<AccountingModel>(context,
                                      listen: false)
                                  .t('dialog_remove_account')),
                              content: Text(Provider.of<AccountingModel>(
                                      context,
                                      listen: false)
                                  .t('msg_remove_account')),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(Provider.of<AccountingModel>(
                                            context,
                                            listen: false)
                                        .t('btn_cancel'))),
                                ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(Provider.of<AccountingModel>(
                                            context,
                                            listen: false)
                                        .t('btn_remove')))
                              ],
                            ));
                    if (confirm == true) {
                      final model =
                          Provider.of<AccountingModel>(context, listen: false);
                      if (widget.isReceipt)
                        model.removeReceiptAccount(widget.keyId);
                      else
                        model.removePaymentAccount(widget.keyId);
                    }
                  }),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => isOpen = !isOpen),
                child: AnimatedRotation(
                  turns: isOpen ? 0.0 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(Icons.expand_more, color: accent),
                ),
              ),
            ]),
            onTap: () => setState(() => isOpen = !isOpen),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: isOpen
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Entries
                      ...widget.entries.map((e) => Column(
                            children: [
                              Row(children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: e.description,
                                    decoration: InputDecoration(
                                        labelText: Provider.of<AccountingModel>(
                                                context)
                                            .t('label_description'),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8))),
                                    onChanged: (val) {
                                      final model =
                                          Provider.of<AccountingModel>(context,
                                              listen: false);
                                      model.updateEntryDescription(
                                          widget.keyId, e.id, val,
                                          receipt: widget.isReceipt);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.grey,
                                  tooltip: Provider.of<AccountingModel>(context)
                                      .t('tooltip_remove_entry'),
                                  onPressed: () {
                                    final model = Provider.of<AccountingModel>(
                                        context,
                                        listen: false);
                                    model.removeEntryFromAccount(
                                        widget.keyId, e.id,
                                        receipt: widget.isReceipt);
                                  },
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Column(
                                  children: e.rows
                                      .map((r) => Row(children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue:
                                                    r.cash.toStringAsFixed(2),
                                                textAlign: TextAlign.right,
                                                decoration: InputDecoration(
                                                    labelText: Provider.of<
                                                                AccountingModel>(
                                                            context)
                                                        .t('label_cash'),
                                                    filled: true,
                                                    fillColor:
                                                        Colors.grey.shade50,
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8))),
                                                keyboardType:
                                                    TextInputType.number,
                                                onChanged: (val) {
                                                  final parsed =
                                                      double.tryParse(val) ??
                                                          0.0;
                                                  final model = Provider.of<
                                                          AccountingModel>(
                                                      context,
                                                      listen: false);
                                                  model.updateRowValue(
                                                      widget.keyId, e.id, r.id,
                                                      cash: parsed,
                                                      receipt:
                                                          widget.isReceipt);
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextFormField(
                                                initialValue:
                                                    r.bank.toStringAsFixed(2),
                                                textAlign: TextAlign.right,
                                                decoration: InputDecoration(
                                                    labelText: Provider.of<
                                                                AccountingModel>(
                                                            context)
                                                        .t('label_bank_online'),
                                                    filled: true,
                                                    fillColor:
                                                        Colors.grey.shade50,
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8))),
                                                keyboardType:
                                                    TextInputType.number,
                                                onChanged: (val) {
                                                  final parsed =
                                                      double.tryParse(val) ??
                                                          0.0;
                                                  final model = Provider.of<
                                                          AccountingModel>(
                                                      context,
                                                      listen: false);
                                                  model.updateRowValue(
                                                      widget.keyId, e.id, r.id,
                                                      bank: parsed,
                                                      receipt:
                                                          widget.isReceipt);
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle_outline),
                                              color: Colors.redAccent,
                                              tooltip: 'Remove row',
                                              onPressed: () {
                                                final model = Provider.of<
                                                        AccountingModel>(
                                                    context,
                                                    listen: false);
                                                model.removeRowFromEntry(
                                                    widget.keyId, e.id, r.id,
                                                    receipt: widget.isReceipt);
                                              },
                                            ),
                                          ]))
                                      .toList()),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    final model = Provider.of<AccountingModel>(
                                        context,
                                        listen: false);
                                    model.addRowToEntry(widget.keyId, e.id,
                                        receipt: widget.isReceipt);
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: Text(
                                      Provider.of<AccountingModel>(context)
                                          .t('btn_add_row')),
                                ),
                              ),
                              const Divider(),
                            ],
                          )),

                      // account-level add entry button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            final model = Provider.of<AccountingModel>(context,
                                listen: false);
                            model.addEntryToAccount(widget.keyId,
                                receipt: widget.isReceipt);
                          },
                          icon: const Icon(Icons.add),
                          label: Text(Provider.of<AccountingModel>(context)
                              .t('btn_add_new_entry')),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}
