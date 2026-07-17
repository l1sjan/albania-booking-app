import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../services/booking_repository.dart';
import '../services/notification_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/booking_card.dart';
import 'booking_detail_screen.dart';
import 'notifications_screen.dart';

class BusinessRequestsScreen extends StatefulWidget {
  const BusinessRequestsScreen({
    super.key,
    required this.repository,
    this.embedded = false,
    this.notificationRepository,
  });

  final BookingRepository repository;
  final bool embedded;
  final NotificationRepository? notificationRepository;

  @override
  State<BusinessRequestsScreen> createState() => _BusinessRequestsScreenState();
}

class _BusinessRequestsScreenState extends State<BusinessRequestsScreen> {
  late Future<List<Booking>> _requestsFuture;
  bool _pendingOnly = true;

  @override
  void initState() {
    super.initState();
    _requestsFuture = widget.repository.fetchOwnerBookings();
  }

  void _refresh() {
    setState(() {
      _requestsFuture = widget.repository.fetchOwnerBookings();
    });
  }

  Future<void> _openRequest(Booking booking) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingDetailScreen(
          booking: booking,
          repository: widget.repository,
          ownerMode: true,
          onBookingChanged: _refresh,
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    final repository = widget.notificationRepository;
    if (repository == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(repository: repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.businessRequests,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (widget.notificationRepository != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: AppStrings.notifications,
                          onPressed: _openNotifications,
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppPalette.alabaster,
      appBar: AppBar(
        title: const Text(AppStrings.businessRequests),
        backgroundColor: AppPalette.alabaster,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (widget.notificationRepository != null)
            IconButton(
              tooltip: AppStrings.notifications,
              onPressed: _openNotifications,
              icon: const Icon(Icons.notifications_outlined),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<Booking>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _RequestMessage(
            icon: Icons.cloud_off_outlined,
            title: AppStrings.bookingsErrorTitle,
            message: snapshot.error.toString(),
            actionLabel: AppStrings.tryAgain,
            onAction: _refresh,
          );
        }

        final requests = (snapshot.data ?? const <Booking>[])
            .where(
              (booking) =>
                  !_pendingOnly || booking.status == BookingStatus.pending,
            )
            .toList(growable: false);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.businessRequestsMessage,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppPalette.slate),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.pending_actions_outlined),
                        label: Text(AppStrings.pendingRequests),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.list_alt_outlined),
                        label: Text(AppStrings.allRequests),
                      ),
                    ],
                    selected: {_pendingOnly},
                    onSelectionChanged: (selection) {
                      setState(() => _pendingOnly = selection.first);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: requests.isEmpty
                  ? const _RequestMessage(
                      icon: Icons.inbox_outlined,
                      title: AppStrings.noBusinessRequestsTitle,
                      message: AppStrings.noBusinessRequestsMessage,
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: requests.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) => Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: BookingCard(
                              booking: requests[index],
                              onTap: () => _openRequest(requests[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RequestMessage extends StatelessWidget {
  const _RequestMessage({
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
          constraints: const BoxConstraints(maxWidth: 400),
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
