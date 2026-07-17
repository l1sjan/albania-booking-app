import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
import '../theme/app_theme.dart';

String listingCategoryLabel(ListingCategory category) {
  return switch (category) {
    ListingCategory.carRental => AppStrings.categoryCarRental,
    ListingCategory.barber => AppStrings.categoryBarber,
    ListingCategory.dentist => AppStrings.categoryDentist,
    ListingCategory.restaurant => AppStrings.categoryRestaurant,
    ListingCategory.stay => AppStrings.categoryStay,
  };
}

IconData listingCategoryIcon(ListingCategory category) {
  return switch (category) {
    ListingCategory.carRental => Icons.directions_car_outlined,
    ListingCategory.barber => Icons.content_cut,
    ListingCategory.dentist => Icons.medical_services_outlined,
    ListingCategory.restaurant => Icons.restaurant_outlined,
    ListingCategory.stay => Icons.cottage_outlined,
  };
}

class ListingImage extends StatelessWidget {
  const ListingImage({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    if (listing.imageUrl == null) {
      return _ImagePlaceholder(icon: listingCategoryIcon(listing.category));
    }

    return Image.network(
      listing.imageUrl!,
      semanticLabel: AppStrings.listingPhoto(listing.title),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _ImagePlaceholder(
          icon: listingCategoryIcon(listing.category),
          isLoading: true,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _ImagePlaceholder(icon: listingCategoryIcon(listing.category));
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon, this.isLoading = false});

  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF979DAC), Color(0xFF5C677D)],
        ),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppPalette.forest,
                ),
              )
            : DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xE6FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(icon, size: 30, color: AppPalette.primaryText),
                ),
              ),
      ),
    );
  }
}
