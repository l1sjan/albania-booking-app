import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../theme/app_theme.dart';

class BusinessDetailField {
  const BusinessDetailField({
    required this.key,
    required this.label,
    required this.icon,
    this.hint,
    this.isToggle = false,
    this.keyboardType,
  });

  final String key;
  final String label;
  final IconData icon;
  final String? hint;
  final bool isToggle;
  final TextInputType? keyboardType;
}

List<BusinessDetailField> businessDetailFields(ListingCategory category) {
  return switch (category) {
    ListingCategory.barber => const [
      BusinessDetailField(
        key: 'specialties',
        label: 'Specialties',
        hint: 'Fades, beard trims, color, styling',
        icon: Icons.content_cut,
      ),
      BusinessDetailField(
        key: 'opening_hours',
        label: 'Opening hours',
        hint: 'Mon-Sat, 09:00-19:00',
        icon: Icons.schedule_outlined,
      ),
      BusinessDetailField(
        key: 'walk_ins',
        label: 'Accept walk-ins',
        icon: Icons.directions_walk_outlined,
        isToggle: true,
      ),
    ],
    ListingCategory.carRental => const [
      BusinessDetailField(
        key: 'vehicle_type',
        label: 'Vehicle type',
        hint: 'Compact, SUV, van, luxury',
        icon: Icons.directions_car_outlined,
      ),
      BusinessDetailField(
        key: 'transmission',
        label: 'Transmission',
        hint: 'Automatic or manual',
        icon: Icons.settings_outlined,
      ),
      BusinessDetailField(
        key: 'seats',
        label: 'Seats',
        hint: 'e.g. 5',
        icon: Icons.event_seat_outlined,
        keyboardType: TextInputType.number,
      ),
      BusinessDetailField(
        key: 'fuel_policy',
        label: 'Fuel policy',
        hint: 'Full to full',
        icon: Icons.local_gas_station_outlined,
      ),
      BusinessDetailField(
        key: 'airport_delivery',
        label: 'Airport delivery available',
        icon: Icons.flight_takeoff_outlined,
        isToggle: true,
      ),
      BusinessDetailField(
        key: 'driver_available',
        label: 'Driver available',
        icon: Icons.person_outline,
        isToggle: true,
      ),
    ],
    ListingCategory.dentist => const [
      BusinessDetailField(
        key: 'specialties',
        label: 'Treatments offered',
        hint: 'Checkups, hygiene, whitening, implants',
        icon: Icons.medical_services_outlined,
      ),
      BusinessDetailField(
        key: 'languages',
        label: 'Languages spoken',
        hint: 'Albanian, English, Italian',
        icon: Icons.translate_outlined,
      ),
      BusinessDetailField(
        key: 'emergency_visits',
        label: 'Emergency visits',
        icon: Icons.emergency_outlined,
        isToggle: true,
      ),
      BusinessDetailField(
        key: 'new_patients',
        label: 'Accepting new patients',
        icon: Icons.person_add_alt_outlined,
        isToggle: true,
      ),
    ],
    ListingCategory.restaurant => const [
      BusinessDetailField(
        key: 'cuisine',
        label: 'Cuisine',
        hint: 'Traditional Albanian, Italian, seafood',
        icon: Icons.restaurant_outlined,
      ),
      BusinessDetailField(
        key: 'opening_hours',
        label: 'Opening hours',
        hint: 'Daily, 12:00-23:00',
        icon: Icons.schedule_outlined,
      ),
      BusinessDetailField(
        key: 'outdoor_seating',
        label: 'Outdoor seating',
        icon: Icons.deck_outlined,
        isToggle: true,
      ),
      BusinessDetailField(
        key: 'delivery_available',
        label: 'Delivery available',
        icon: Icons.delivery_dining_outlined,
        isToggle: true,
      ),
    ],
    ListingCategory.stay => const [
      BusinessDetailField(
        key: 'property_type',
        label: 'Property type',
        hint: 'Apartment, villa, guesthouse',
        icon: Icons.home_outlined,
      ),
      BusinessDetailField(
        key: 'max_guests',
        label: 'Maximum guests',
        hint: 'e.g. 4',
        icon: Icons.groups_outlined,
        keyboardType: TextInputType.number,
      ),
      BusinessDetailField(
        key: 'check_in',
        label: 'Check-in',
        hint: 'From 15:00',
        icon: Icons.login_outlined,
      ),
      BusinessDetailField(
        key: 'check_out',
        label: 'Check-out',
        hint: 'By 11:00',
        icon: Icons.logout_outlined,
      ),
      BusinessDetailField(
        key: 'breakfast_included',
        label: 'Breakfast included',
        icon: Icons.breakfast_dining_outlined,
        isToggle: true,
      ),
    ],
  };
}

class BusinessDetailsSection extends StatelessWidget {
  const BusinessDetailsSection({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final fields = businessDetailFields(listing.category);
    final visibleFields = fields
        .where((field) {
          final value = listing.businessDetails[field.key];
          return field.isToggle
              ? value == true
              : value?.toString().trim().isNotEmpty == true;
        })
        .toList(growable: false);
    if (visibleFields.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final field in visibleFields)
          _DetailChip(
            icon: field.icon,
            label: field.label,
            value: field.isToggle
                ? 'Available'
                : listing.businessDetails[field.key].toString(),
          ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.warmField,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppPalette.forest),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppPalette.slate),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
