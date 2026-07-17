import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../services/booking_repository.dart';
import '../services/notification_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/booking_card.dart';
import 'booking_detail_screen.dart';
import 'notifications_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    required this.repository,
    required this.onAccountChanged,
    this.notificationRepository,
  });

  final BookingRepository repository;
  final VoidCallback onAccountChanged;
  final NotificationRepository? notificationRepository;

  @override
  State<BookingsScreen> createState() => BookingsScreenState();
}

class BookingsScreenState extends State<BookingsScreen> {
  late Future<List<Booking>> _bookingsFuture;
  bool _showActive = true;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = widget.repository.fetchBookings();
  }

  @override
  void didUpdateWidget(covariant BookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) refresh();
  }

  void refresh() {
    if (!mounted) return;
    setState(() {
      _bookingsFuture = widget.repository.fetchBookings();
    });
  }

  Future<void> _refresh() async {
    final request = widget.repository.fetchBookings();
    setState(() {
      _bookingsFuture = request;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder renders the error from this request.
    }
  }

  Future<void> _signIn() async {
    final authenticated = await showAuthenticationSheet(
      context,
      widget.repository,
    );
    if (authenticated && mounted) {
      widget.onAccountChanged();
      refresh();
    }
  }

  Future<void> _openBooking(Booking booking) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingDetailScreen(
          booking: booking,
          repository: widget.repository,
          ownerMode: false,
          onBookingChanged: refresh,
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
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.bookingsTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
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
          if (widget.repository.isAuthenticated)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.upcoming_outlined),
                        label: Text(AppStrings.activeBookings),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.history),
                        label: Text(AppStrings.pastBookings),
                      ),
                    ],
                    selected: {_showActive},
                    onSelectionChanged: (selection) {
                      setState(() => _showActive = selection.first);
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.repository.isAuthenticated
                ? FutureBuilder<List<Booking>>(
                    future: _bookingsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _BookingsMessage(
                          icon: Icons.cloud_off_outlined,
                          title: AppStrings.bookingsErrorTitle,
                          message: snapshot.error.toString(),
                          actionLabel: AppStrings.tryAgain,
                          onAction: refresh,
                        );
                      }

                      final bookings = (snapshot.data ?? const <Booking>[])
                          .where((booking) => booking.isActive == _showActive)
                          .toList(growable: false);
                      if (bookings.isEmpty) {
                        return _BookingsMessage(
                          icon: _showActive
                              ? Icons.calendar_today_outlined
                              : Icons.history,
                          title: _showActive
                              ? AppStrings.noActiveBookingsTitle
                              : AppStrings.noPastBookingsTitle,
                          message: _showActive
                              ? AppStrings.noActiveBookingsMessage
                              : AppStrings.noPastBookingsMessage,
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 124),
                          itemCount: bookings.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 720,
                                ),
                                child: BookingCard(
                                  booking: bookings[index],
                                  onTap: () => _openBooking(bookings[index]),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  )
                : _BookingsMessage(
                    icon: Icons.lock_outline,
                    title: AppStrings.signInRequiredTitle,
                    message: AppStrings.signInRequiredMessage,
                    actionLabel: AppStrings.signIn,
                    onAction: _signIn,
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingsMessage extends StatelessWidget {
  const _BookingsMessage({
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 120),
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
              const SizedBox(height: 9),
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
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.login),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
