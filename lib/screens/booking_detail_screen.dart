import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../services/booking_repository.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';
import '../widgets/booking_card.dart';
import '../widgets/booking_reason_dialog.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    super.key,
    required this.booking,
    required this.repository,
    required this.ownerMode,
    required this.onBookingChanged,
  });

  final Booking booking;
  final BookingRepository repository;
  final bool ownerMode;
  final VoidCallback onBookingChanged;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _isUpdating = false;

  Future<void> _cancelBooking() async {
    final reason = await showBookingReasonDialog(
      context: context,
      title: AppStrings.cancelBookingTitle,
      message: AppStrings.cancelBookingMessage,
      confirmLabel: AppStrings.confirmCancellation,
    );
    if (reason == null || !mounted) return;
    await _updateStatus(
      BookingStatus.canceled,
      AppStrings.bookingCanceled,
      cancellationReason: reason,
    );
  }

  Future<void> _declineBooking() async {
    final reason = await showBookingReasonDialog(
      context: context,
      title: AppStrings.declineBookingTitle,
      message: AppStrings.declineBookingMessage,
      confirmLabel: AppStrings.confirmDecline,
    );
    if (reason == null || !mounted) return;
    await _updateStatus(
      BookingStatus.canceled,
      AppStrings.bookingUpdated,
      cancellationReason: reason,
    );
  }

  Future<void> _updateStatus(
    BookingStatus status,
    String message, {
    String? cancellationReason,
  }) async {
    setState(() => _isUpdating = true);
    try {
      if (status == BookingStatus.canceled && !widget.ownerMode) {
        await widget.repository.cancelBooking(
          widget.booking.id,
          reason: cancellationReason ?? '',
        );
      } else {
        await widget.repository.updateBookingStatus(
          widget.booking.id,
          status,
          cancellationReason: cancellationReason,
        );
      }
      if (!mounted) return;
      widget.onBookingChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context);
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
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return Scaffold(
      backgroundColor: AppPalette.alabaster,
      appBar: AppBar(
        title: const Text(AppStrings.reservationDetails),
        backgroundColor: AppPalette.alabaster,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BookingCard(booking: booking),
                  const SizedBox(height: 28),
                  Text(
                    AppStrings.reservationDetails,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (booking.rentalCarModel != null)
                    _DetailRow(
                      icon: Icons.directions_car_outlined,
                      label: AppStrings.selectedCar,
                      value: booking.rentalCarModel!,
                    ),
                  _DetailRow(
                    icon: Icons.schedule_outlined,
                    label: AppStrings.selectDate,
                    value:
                        '${formatDate(booking.startsAt)} at '
                        '${formatTime(booking.startsAt)}',
                  ),
                  _DetailRow(
                    icon: Icons.event_available_outlined,
                    label: AppStrings.availability,
                    value:
                        '${formatDate(booking.endsAt)} at '
                        '${formatTime(booking.endsAt)}',
                  ),
                  if (booking.priceAmount != null)
                    _DetailRow(
                      icon: Icons.payments_outlined,
                      label: AppStrings.total,
                      value: formatCurrency(
                        booking.priceAmount!,
                        booking.currency,
                      ),
                    ),
                  if (booking.customerNotes != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.customerNotes,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.customerNotes!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.slate,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (booking.listingNotes != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.bookingDetails,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.listingNotes!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.slate,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (booking.cancellationReason != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.cancellationReason,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.cancellationReason!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.slate,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  Widget? _actionBar() {
    if (widget.booking.status != BookingStatus.pending) return null;

    final action = widget.ownerMode
        ? Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isUpdating ? null : _declineBooking,
                  child: const Text(AppStrings.declineRequest),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isUpdating
                      ? null
                      : () => _updateStatus(
                          BookingStatus.confirmed,
                          AppStrings.bookingUpdated,
                        ),
                  child: _isUpdating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(AppStrings.confirmRequest),
                ),
              ),
            ],
          )
        : FilledButton.icon(
            onPressed: _isUpdating ? null : _cancelBooking,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text(AppStrings.cancelBooking),
          );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: action,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppPalette.forest),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppPalette.slate),
                ),
                const SizedBox(height: 3),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
