import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/app_notification.dart';
import '../services/notification_repository.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.repository});

  final NotificationRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _notificationsFuture;
  bool _isMarkingAllRead = false;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = widget.repository.fetchNotifications();
  }

  Future<void> _refresh() async {
    final request = widget.repository.fetchNotifications();
    setState(() => _notificationsFuture = request);
    try {
      await request;
    } catch (_) {
      // The FutureBuilder displays the fetch failure.
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _isMarkingAllRead = true);
    try {
      await widget.repository.markAllAsRead();
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await widget.repository.markAsRead(notification.id);
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.alabaster,
      appBar: AppBar(
        title: const Text(AppStrings.notifications),
        backgroundColor: AppPalette.alabaster,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: AppStrings.markAllRead,
            onPressed: _isMarkingAllRead ? null : _markAllRead,
            icon: _isMarkingAllRead
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _NotificationMessage(
              icon: Icons.cloud_off_outlined,
              title: AppStrings.notificationsErrorTitle,
              message: snapshot.error.toString(),
              actionLabel: AppStrings.tryAgain,
              onAction: _refresh,
            );
          }

          final notifications = snapshot.data ?? const <AppNotification>[];
          if (notifications.isEmpty) {
            return const _NotificationMessage(
              icon: Icons.notifications_none_outlined,
              title: AppStrings.noNotificationsTitle,
              message: AppStrings.noNotificationsMessage,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _NotificationTile(
                notification: notifications[index],
                onTap: () => _openNotification(notifications[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (notification.type) {
      AppNotificationType.bookingRequested => (
        Icons.mark_email_unread_outlined,
        AppPalette.terracotta,
      ),
      AppNotificationType.bookingConfirmed => (
        Icons.check_circle_outline,
        AppPalette.forest,
      ),
      AppNotificationType.bookingDeclined => (
        Icons.event_busy_outlined,
        Theme.of(context).colorScheme.error,
      ),
      AppNotificationType.bookingCanceled => (
        Icons.cancel_outlined,
        AppPalette.slate,
      ),
    };

    return Card(
      color: notification.isRead ? Colors.white : AppPalette.warmField,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.warmOutline),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(
          notification.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${notification.body}\n${formatDate(notification.createdAt)} at ${formatTime(notification.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.slate,
              height: 1.4,
            ),
          ),
        ),
        trailing: notification.isRead
            ? null
            : const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.forest,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 8),
              ),
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppPalette.forest),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.slate,
                  height: 1.5,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
