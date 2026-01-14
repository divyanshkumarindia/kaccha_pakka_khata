import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';

class SubscriptionPlansDialog extends StatelessWidget {
  final bool open;
  final void Function(bool) onOpenChange;
  const SubscriptionPlansDialog(
      {Key? key, this.open = false, required this.onOpenChange})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();
    final model = Provider.of<AccountingModel>(context);

    return Dialog(
      child: SizedBox(
        width: 700,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(model.t('title_choose_plan'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _PlanCard(
                      name: model.t('plan_free'),
                      price: model.t('price_free'),
                      features: [
                    model.t('feat_10_entries'),
                    model.t('feat_basic_tracking')
                  ])),
              const SizedBox(width: 8),
              Expanded(
                  child: _PlanCard(
                      name: model.t('plan_professional'),
                      price: model.t('price_pro'),
                      popular: true,
                      features: [
                    model.t('feat_unlimited'),
                    model.t('feat_multi_currency')
                  ])),
              const SizedBox(width: 8),
              Expanded(
                  child: _PlanCard(
                      name: model.t('plan_business'),
                      price: model.t('price_business'),
                      features: [
                    model.t('feat_multi_user'),
                    model.t('feat_advanced_analytics')
                  ])),
            ])
          ]),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final List<String> features;
  final bool popular;
  const _PlanCard(
      {Key? key,
      required this.name,
      required this.price,
      this.features = const [],
      this.popular = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: popular ? 8 : 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: popular ? Colors.blue : Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          if (popular)
            Align(
                alignment: Alignment.topCenter,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        Provider.of<AccountingModel>(context)
                            .t('label_most_popular'),
                        style: const TextStyle(color: Colors.white)))),
          const SizedBox(height: 8),
          Text(name,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(price,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...features.map((f) => Row(children: [
                const Icon(Icons.check, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(child: Text(f))
              ])),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: () {},
              child: Text(name == 'Free'
                  ? Provider.of<AccountingModel>(context).t('btn_current_plan')
                  : Provider.of<AccountingModel>(context).t('btn_contact_us')))
        ]),
      ),
    );
  }
}
