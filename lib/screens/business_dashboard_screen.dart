import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
import '../services/booking_repository.dart';
import '../services/business_repository.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({
    super.key,
    required this.businessRepository,
    required this.bookingRepository,
    required this.onAddListing,
    required this.onReviewRequests,
    required this.onStartOnboarding,
  });

  final BusinessRepository businessRepository;
  final BookingRepository bookingRepository;
  final VoidCallback onAddListing;
  final VoidCallback onReviewRequests;
  final VoidCallback onStartOnboarding;

  @override
  State<BusinessDashboardScreen> createState() =>
      BusinessDashboardScreenState();
}

class BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  late Future<List<Listing>> _businessFuture;

  @override
  void initState() {
    super.initState();
    _businessFuture = widget.businessRepository.fetchOwnerListings();
  }

  Future<void> refresh() async {
    final request = widget.businessRepository.fetchOwnerListings();
    setState(() {
      _businessFuture = request;
    });
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Listing>>(
      future: _businessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppPalette.alabaster,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _BusinessPreviewMessage(
            icon: Icons.cloud_off_outlined,
            title: AppStrings.businessDashboardError,
            message: snapshot.error.toString(),
            actionLabel: AppStrings.tryAgain,
            onAction: refresh,
          );
        }

        final listings = snapshot.data ?? const <Listing>[];
        if (listings.isEmpty) {
          return _BusinessPreviewMessage(
            icon: Icons.storefront_outlined,
            title: AppStrings.noOwnerListingsTitle,
            message: AppStrings.noOwnerListingsMessage,
            actionLabel: AppStrings.onboardingStart,
            onAction: widget.onStartOnboarding,
          );
        }

        return ListingDetailScreen(
          listing: listings.first,
          bookingRepository: widget.bookingRepository,
          onViewBookings: widget.onReviewRequests,
          onAccountChanged: () {},
          previewOnly: true,
        );
      },
    );
  }
}

class _BusinessPreviewMessage extends StatelessWidget {
  const _BusinessPreviewMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.alabaster,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 50, color: AppPalette.forest),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(actionLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
