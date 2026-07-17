import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

abstract interface class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();
}

class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _client
        .from('notifications')
        .select('id, booking_id, type, title, body, is_read, created_at')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);
    return rows.map(AppNotification.fromJson).toList(growable: false);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  @override
  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }
}
