import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/rental_car.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';

class CustomerCarDetailScreen extends StatelessWidget {
  const CustomerCarDetailScreen({
    super.key,
    required this.car,
    required this.dateRange,
    required this.rentalDays,
    required this.onBook,
  });

  final RentalCar car;
  final DateTimeRange dateRange;
  final int rentalDays;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final total = car.pricePerDay * rentalDays;
    return Scaffold(
      appBar: AppBar(title: Text(car.model)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            _CustomerCarPhoto(car: car),
            const SizedBox(height: 24),
            Text(
              car.model,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              car.engine,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppPalette.slate),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.carDetails,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppPalette.warmOutline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _CustomerCarDetailRow(
                      icon: Icons.directions_car_outlined,
                      label: AppStrings.carModel,
                      value: car.model,
                    ),
                    _CustomerCarDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: AppStrings.productionYear,
                      value:
                          car.productionYear?.toString() ??
                          AppStrings.yearNotSet,
                    ),
                    _CustomerCarDetailRow(
                      icon: Icons.tire_repair_outlined,
                      label: AppStrings.carEngine,
                      value: car.engine,
                    ),
                    _CustomerCarDetailRow(
                      icon: Icons.settings_outlined,
                      label: AppStrings.carTransmission,
                      value: car.transmission == CarTransmission.automatic
                          ? AppStrings.automatic
                          : AppStrings.manual,
                    ),
                    _CustomerCarDetailRow(
                      icon: Icons.event_seat_outlined,
                      label: AppStrings.seatCount,
                      value:
                          car.seatCount?.toString() ?? AppStrings.seatsNotSet,
                    ),
                    _CustomerCarDetailRow(
                      icon: Icons.payments_outlined,
                      label: AppStrings.carPricePerDay,
                      value: formatCurrency(car.pricePerDay, car.currency),
                      isLast: true,
                      valueColor: AppPalette.terracotta,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppPalette.warmOutline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.selectedRentalDates,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppPalette.slate,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatDateRange(dateRange.start, dateRange.end),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.rentalDays(rentalDays),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          '${AppStrings.rentalTotal}: ${formatCurrency(total, car.currency)}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppPalette.terracotta,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBook,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text(AppStrings.bookThisCar),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCarPhoto extends StatelessWidget {
  const _CustomerCarPhoto({required this.car});

  final RentalCar car;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: car.imageUrl == null
            ? const _CustomerCarImageFallback()
            : Image.network(
                car.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _CustomerCarImageFallback(),
              ),
      ),
    );
  }
}

class _CustomerCarImageFallback extends StatelessWidget {
  const _CustomerCarImageFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppPalette.sand, AppPalette.sage]),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_outlined,
          size: 50,
          color: AppPalette.forest,
        ),
      ),
    );
  }
}

class _CustomerCarDetailRow extends StatelessWidget {
  const _CustomerCarDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppPalette.forest),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.slate),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: valueColor ?? AppPalette.charcoal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
