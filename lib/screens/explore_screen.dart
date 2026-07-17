import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
import '../services/booking_repository.dart';
import '../services/listing_repository.dart';
import '../services/rental_car_repository.dart';
import 'car_rental_booking_screen.dart';
import 'listing_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/listing_card.dart';
import '../widgets/press_scale.dart';
import '../widgets/shimmer_listings_sliver.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.repository,
    required this.bookingRepository,
    required this.rentalCarRepository,
    required this.onProfilePressed,
    required this.onViewBookings,
    required this.onAccountChanged,
  });

  final ListingRepository repository;
  final BookingRepository bookingRepository;
  final RentalCarRepository rentalCarRepository;
  final VoidCallback onProfilePressed;
  final VoidCallback onViewBookings;
  final VoidCallback onAccountChanged;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Future<List<Listing>> _listingsFuture;
  late final TextEditingController _searchController;
  ListingFilter _selectedFilter = ListingFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _listingsFuture = widget.repository.fetchListings();
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _listingsFuture = widget.repository.fetchListings(
        filter: _selectedFilter,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshListings() async {
    final request = widget.repository.fetchListings(filter: _selectedFilter);
    setState(() {
      _listingsFuture = request;
    });

    try {
      await request;
    } catch (_) {
      // FutureBuilder renders the error state for this same request.
    }
  }

  void _selectFilter(ListingFilter filter) {
    if (filter == _selectedFilter) return;

    setState(() {
      _selectedFilter = filter;
      _listingsFuture = widget.repository.fetchListings(filter: filter);
    });
  }

  Future<void> _showFilterSheet() async {
    final selected = await showModalBottomSheet<ListingFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Text(
                  AppStrings.filterByCategory,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              for (final filter in ListingFilter.values)
                ListTile(
                  onTap: () => Navigator.pop(context, filter),
                  leading: Icon(listingFilterIcon(filter)),
                  title: Text(listingFilterLabel(filter)),
                  selected: filter == _selectedFilter,
                  selectedColor: AppPalette.forest,
                  trailing: filter == _selectedFilter
                      ? const Icon(Icons.check_circle, color: AppPalette.forest)
                      : null,
                ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) _selectFilter(selected);
  }

  List<Listing> _searchResults(List<Listing> listings) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return listings;

    return listings
        .where((listing) {
          return listing.title.toLowerCase().contains(query) ||
              listing.location.toLowerCase().contains(query) ||
              listing.description.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openListing(Listing listing) async {
    final page = listing.category == ListingCategory.carRental
        ? CarRentalBookingScreen(
            listing: listing,
            rentalCarRepository: widget.rentalCarRepository,
            bookingRepository: widget.bookingRepository,
            onViewBookings: widget.onViewBookings,
            onAccountChanged: widget.onAccountChanged,
          )
        : ListingDetailScreen(
            listing: listing,
            bookingRepository: widget.bookingRepository,
            onViewBookings: widget.onViewBookings,
            onAccountChanged: widget.onAccountChanged,
          );
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (context) => page));
    if (mounted) await _refreshListings();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refreshListings,
        child: FutureBuilder<List<Listing>>(
          future: _listingsFuture,
          builder: (context, snapshot) {
            return CustomScrollView(
              key: PageStorageKey(_selectedFilter),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 166,
                  toolbarHeight: 56,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppPalette.alabaster,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  flexibleSpace: _ExploreSliverHeader(
                    onProfilePressed: widget.onProfilePressed,
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ExploreControlsDelegate(
                    searchController: _searchController,
                    selectedFilter: _selectedFilter,
                    onSearchChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    onFilterSelected: _selectFilter,
                    onFilterPressed: _showFilterSheet,
                  ),
                ),
                ..._contentSlivers(snapshot),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(AsyncSnapshot<List<Listing>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [ShimmerListingsSliver()];
    }

    if (snapshot.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ExploreMessage(
            icon: Icons.cloud_off_outlined,
            title: AppStrings.feedErrorTitle,
            message: AppStrings.feedErrorMessage,
            details: snapshot.error.toString(),
            onRetry: _refreshListings,
          ),
        ),
      ];
    }

    final listings = _searchResults(snapshot.data ?? const <Listing>[]);
    if (listings.isEmpty) {
      final hasSearch = _searchQuery.trim().isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ExploreMessage(
            icon: Icons.travel_explore_outlined,
            title: hasSearch
                ? AppStrings.noMatchesTitle
                : AppStrings.emptyFeedTitle,
            message: hasSearch
                ? AppStrings.noMatchesMessage
                : AppStrings.emptyFeedMessage,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.only(
          left: 16,
          top: 20,
          right: 16,
          bottom: 110,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ListingCard(
                    listing: listings[index],
                    imageOnRight: index.isOdd,
                    onTap: () => _openListing(listings[index]),
                  ),
                ),
              ),
            );
          }, childCount: listings.length),
        ),
      ),
    ];
  }
}

class _ExploreSliverHeader extends StatelessWidget {
  const _ExploreSliverHeader({required this.onProfilePressed});

  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final collapsedHeight = topInset + 56;

    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedProgress =
            ((constraints.maxHeight - collapsedHeight) / (166 - 56)).clamp(
              0.0,
              1.0,
            );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (expandedProgress > 0)
              Positioned(
                left: 20,
                right: 82,
                bottom: 18,
                child: Opacity(
                  opacity: expandedProgress,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - expandedProgress)),
                    child: Text(
                      AppStrings.exploreGreeting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppPalette.charcoal,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                ),
              ),
            if (expandedProgress < 1)
              Positioned(
                top: topInset + 16,
                left: 74,
                right: 74,
                child: Opacity(
                  opacity: 1 - expandedProgress,
                  child: Text(
                    AppStrings.exploreGreeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppPalette.charcoal,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: topInset + 8,
              right: 16,
              child: Semantics(
                button: true,
                label: AppStrings.navProfile,
                child: InkResponse(
                  onTap: onProfilePressed,
                  radius: 24,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F5C677D),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppPalette.forest,
                      size: 21,
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

class _ExploreControlsDelegate extends SliverPersistentHeaderDelegate {
  const _ExploreControlsDelegate({
    required this.searchController,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterSelected,
    required this.onFilterPressed,
  });

  final TextEditingController searchController;
  final ListingFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ListingFilter> onFilterSelected;
  final VoidCallback onFilterPressed;

  @override
  double get minExtent => 118;

  @override
  double get maxExtent => 118;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppPalette.alabaster,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 5),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: _SearchCard(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  onFilterPressed: onFilterPressed,
                ),
              ),
            ),
          ),
          CategoryFilterBar(
            selectedFilter: selectedFilter,
            onSelected: onFilterSelected,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ExploreControlsDelegate oldDelegate) {
    return selectedFilter != oldDelegate.selectedFilter ||
        searchController != oldDelegate.searchController;
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.onChanged,
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F5C677D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search, color: AppPalette.slate, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: AppStrings.searchHint,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: AppStrings.filterByCategory,
                    child: PressScale(
                      onTap: onFilterPressed,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.62),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.72),
                            width: 0.6,
                          ),
                        ),
                        child: const SizedBox.square(
                          dimension: 44,
                          child: Icon(
                            Icons.tune,
                            size: 20,
                            color: AppPalette.smartBlue,
                          ),
                        ),
                      ),
                    ),
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

class _ExploreMessage extends StatelessWidget {
  const _ExploreMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? details;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (details != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  details!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text(AppStrings.tryAgain),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
