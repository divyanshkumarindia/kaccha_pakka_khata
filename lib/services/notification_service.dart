import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  /// Invokes the `send-push` Supabase Edge Function to send a push notification.
  ///
  /// [receiverId] should be the `user_id` of the recipient.
  /// [message] is the text body of the push notification.
  Future<bool> sendPushNotification({
    required String receiverId,
    required String message,
  }) async {
    try {
      debugPrint('⏳ Invoking send-push edge function...');

      final response = await _supabase.functions.invoke(
        'send-push',
        body: {
          'userId': receiverId,
          'message': message,
        },
      );

      debugPrint(
          '✅ Push notification sent successfully! Response: ${response.data}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send push notification: $e');
      return false;
    }
  }
}
