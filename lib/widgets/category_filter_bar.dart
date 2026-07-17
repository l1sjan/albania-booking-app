import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/listing_repository.dart';
import '../theme/app_theme.dart';
import 'press_scale.dart';

String listingFilterLabel(ListingFilter filter) {
  return switch (filter) {
    ListingFilter.all => AppStrings.filterAll,
    ListingFilter.stays => AppStrings.filterStays,
    ListingFilter.transport => AppStrings.filterTransport,
    ListingFilter.beautyWellness => AppStrings.filterBeautyWellness,
    ListingFilter.restaurants => AppStrings.filterRestaurants,
  };
}

String listingFilterEmoji(ListingFilter filter) {
  return switch (filter) {
    ListingFilter.all => AppStrings.filterAllEmoji,
    ListingFilter.stays => AppStrings.filterStaysEmoji,
    ListingFilter.transport => AppStrings.filterTransportEmoji,
    ListingFilter.beautyWellness => AppStrings.filterBeautyWellnessEmoji,
    ListingFilter.restaurants => AppStrings.filterRestaurantsEmoji,
  };
}

IconData listingFilterIcon(ListingFilter filter) {
  return switch (filter) {
    ListingFilter.all => Icons.auto_awesome_outlined,
    ListingFilter.stays => Icons.cottage_outlined,
    ListingFilter.transport => Icons.directions_car_outlined,
    ListingFilter.beautyWellness => Icons.spa_outlined,
    ListingFilter.restaurants => Icons.restaurant_outlined,
  };
}

class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onSelected,
  });

  final ListingFilter selectedFilter;
  final ValueChanged<ListingFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
        itemCount: ListingFilter.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = ListingFilter.values[index];
          final isSelected = filter == selectedFilter;

          return Semantics(
            button: true,
            selected: isSelected,
            label:
                '${listingFilterEmoji(filter)} ${listingFilterLabel(filter)}',
            child: PressScale(
              onTap: () => onSelected(filter),
              child: AnimatedScale(
                scale: isSelected ? 1.02 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppPalette.smartBlue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: isSelected
                          ? AppPalette.smartBlue
                          : AppPalette.slateGrey,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color(0x300466C8),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            listingFilterIcon(filter),
                            size: 17,
                            color: isSelected ? Colors.white : AppPalette.slate,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            listingFilterLabel(filter),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : AppPalette.charcoal,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
