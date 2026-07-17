import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';
import 'listing_image.dart';
import 'press_scale.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    this.imageOnRight = false,
    this.onTap,
  });

  final Listing listing;
  final bool imageOnRight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useWideLayout = constraints.maxWidth >= 620;

        return Semantics(
          button: onTap != null,
          label: listing.title,
          child: MouseRegion(
            cursor: onTap == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            child: PressScale(
              onTap: onTap,
              pressedScale: 0.96,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F5C677D),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: useWideLayout ? _wideLayout() : _compactLayout(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _compactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: _ListingVisual(
            listing: listing,
            categoryLabel: _categoryLabel,
            categoryIcon: _categoryIcon,
          ),
        ),
        _ListingDetails(
          listing: listing,
          priceAmount: _priceAmount,
          priceInterval: _priceInterval,
          compact: true,
        ),
      ],
    );
  }

  Widget _wideLayout() {
    final visual = Expanded(
      flex: imageOnRight ? 5 : 4,
      child: SizedBox.expand(
        child: _ListingVisual(
          listing: listing,
          categoryLabel: _categoryLabel,
          categoryIcon: _categoryIcon,
        ),
      ),
    );
    final details = Expanded(
      flex: imageOnRight ? 4 : 5,
      child: _ListingDetails(
        listing: listing,
        priceAmount: _priceAmount,
        priceInterval: _priceInterval,
        compact: false,
      ),
    );

    return SizedBox(
      height: 292,
      child: Row(
        children: imageOnRight ? [details, visual] : [visual, details],
      ),
    );
  }

  String get _priceAmount => formatCurrency(listing.price, listing.currency);

  String get _priceInterval => switch (listing.category) {
    ListingCategory.carRental => AppStrings.priceIntervalDay,
    ListingCategory.stay => AppStrings.priceIntervalNight,
    _ => AppStrings.priceIntervalService,
  };

  String get _categoryLabel => listingCategoryLabel(listing.category);

  IconData get _categoryIcon => listingCategoryIcon(listing.category);
}

class _ListingDetails extends StatelessWidget {
  const _ListingDetails({
    required this.listing,
    required this.priceAmount,
    required this.priceInterval,
    required this.compact,
  });

  final Listing listing;
  final String priceAmount;
  final String priceInterval;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            listing.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppPalette.charcoal,
              fontWeight: FontWeight.w700,
              height: 1.12,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 17,
                color: AppPalette.forest,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  listing.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppPalette.slate,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          if (listing.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              listing.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.slate,
                height: 1.5,
                letterSpacing: 0,
              ),
            ),
          ],
          if (compact) const SizedBox(height: 18) else const Spacer(),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: priceAmount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppPalette.smartBlue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                TextSpan(
                  text: ' $priceInterval',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.slate,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingVisual extends StatelessWidget {
  const _ListingVisual({
    required this.listing,
    required this.categoryLabel,
    required this.categoryIcon,
  });

  final Listing listing;
  final String categoryLabel;
  final IconData categoryIcon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: 'listing_image_${listing.id}',
          transitionOnUserGestures: true,
          child: ListingImage(listing: listing),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: _CategoryBadge(label: categoryLabel, icon: categoryIcon),
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE60353A4),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
