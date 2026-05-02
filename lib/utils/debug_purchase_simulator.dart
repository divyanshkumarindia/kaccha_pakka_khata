import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../models/subscription.dart';

/// A utility to simulate purchases during development when Google Play
/// products are not yet configured.
class DebugPurchaseSimulator {
  static Future<void> simulatePurchase(BuildContext context, int planIndex) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Close loading indicator
    if (context.mounted) Navigator.of(context).pop();

    if (!context.mounted) return;

    // Simulate the purchase via the service
    final subService = Provider.of<SubscriptionService>(context, listen: false);
    
    SubscriptionPlan newPlan;
    if (planIndex == 2) {
      newPlan = SubscriptionPlan.premium;
    } else if (planIndex == 1) {
      newPlan = SubscriptionPlan.pro;
    } else {
      newPlan = SubscriptionPlan.free;
    }

    // Directly mutate the service state (only for debug!)
    // To do this, we need to add a debug method to the service, or just
    // call a generic success callback for now. 
    subService.debugSetPlan(newPlan);

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Debug: Successfully upgraded to ${newPlan.name}!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
