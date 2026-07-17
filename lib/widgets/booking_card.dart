import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';
import 'press_scale.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, this.onTap});

  final Booking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title =
        booking.rentalCarModel ?? booking.listingTitle ?? booking.serviceName;
    final isCarRental = booking.rentalCarId != null;
    return Semantics(
      button: onTap != null,
      label: title,
      child: PressScale(
        onTap: onTap,
        pressedScale: 0.96,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppPalette.warmOutline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookingThumbnail(booking: booking),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          BookingStatusBadge(status: booking.status),
                        ],
                      ),
                      if (isCarRental && booking.listingTitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          booking.listingTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.slate),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        isCarRental
                            ? formatDateRange(booking.startsAt, booking.endsAt)
                            : '${formatDate(booking.startsAt)} at '
                                  '${formatTime(booking.startsAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.slate,
                        ),
                      ),
                      if (booking.listingLocation != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: AppPalette.forest,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                booking.listingLocation!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppPalette.slate),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (booking.priceAmount != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          formatCurrency(
                            booking.priceAmount!,
                            booking.currency,
                          ),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppPalette.terracotta,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BookingStatus.pending => (
        AppStrings.statusPending,
        AppPalette.terracotta,
      ),
      BookingStatus.confirmed => (
        AppStrings.statusConfirmed,
        AppPalette.forest,
      ),
      BookingStatus.completed => (AppStrings.statusCompleted, AppPalette.slate),
      BookingStatus.canceled => (
        AppStrings.statusCanceled,
        Theme.of(context).colorScheme.error,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BookingThumbnail extends StatelessWidget {
  const _BookingThumbnail({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: 76,
        child:
            booking.listingImageUrl == null && booking.rentalCarImageUrl == null
            ? const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppPalette.sand, AppPalette.sage],
                  ),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: AppPalette.forest,
                ),
              )
            : Image.network(
                booking.rentalCarImageUrl ?? booking.listingImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(
                    color: AppPalette.warmField,
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: AppPalette.forest,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
