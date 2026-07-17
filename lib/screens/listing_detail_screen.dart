import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../models/listing.dart';
import '../services/booking_repository.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/business_category_details.dart';
import '../widgets/listing_image.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({
    super.key,
    required this.listing,
    required this.bookingRepository,
    required this.onViewBookings,
    required this.onAccountChanged,
    this.previewOnly = false,
  });

  final Listing listing;
  final BookingRepository bookingRepository;
  final VoidCallback onViewBookings;
  final VoidCallback onAccountChanged;
  final bool previewOnly;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  static const _serviceHours = [9, 11, 14, 16];

  late DateTimeRange _dateRange;
  late DateTime _serviceDate;
  int _serviceHour = 11;
  int _guestCount = 2;
  bool _isSubmitting = false;
  final _pickupController = TextEditingController();
  final _notesController = TextEditingController();

  Listing get listing => widget.listing;
  bool get _usesDateRange =>
      listing.category == ListingCategory.stay ||
      listing.category == ListingCategory.carRental;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    _serviceDate = tomorrow;
    _dateRange = DateTimeRange(
      start: tomorrow,
      end: tomorrow.add(const Duration(days: 2)),
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _chooseDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: _dateRange,
      helpText: AppStrings.selectDates,
    );
    if (result != null && mounted) setState(() => _dateRange = result);
  }

  Future<void> _chooseServiceDate() async {
    final result = await showDatePicker(
      context: context,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _serviceDate,
      helpText: AppStrings.selectDate,
    );
    if (result != null && mounted) setState(() => _serviceDate = result);
  }

  DateTime get _startsAt {
    if (_usesDateRange) {
      final hour = listing.category == ListingCategory.stay ? 15 : 9;
      return DateTime(
        _dateRange.start.year,
        _dateRange.start.month,
        _dateRange.start.day,
        hour,
      );
    }

    return DateTime(
      _serviceDate.year,
      _serviceDate.month,
      _serviceDate.day,
      _serviceHour,
    );
  }

  DateTime get _endsAt {
    if (_usesDateRange) {
      final hour = listing.category == ListingCategory.stay ? 11 : 18;
      return DateTime(
        _dateRange.end.year,
        _dateRange.end.month,
        _dateRange.end.day,
        hour,
      );
    }

    final duration =
        listing.defaultBookingDurationMinutes == null ||
            listing.defaultBookingDurationMinutes! <= 0
        ? 60
        : listing.defaultBookingDurationMinutes!;
    return _startsAt.add(Duration(minutes: duration));
  }

  double get _totalPrice {
    if (!_usesDateRange) return listing.price;
    final units = _dateRange.duration.inDays.clamp(1, 365);
    return listing.price * units;
  }

  String? get _customerNotes {
    final details = <String>[];
    if (listing.category == ListingCategory.stay) {
      details.add(AppStrings.guestCount(_guestCount));
    }
    if (listing.category == ListingCategory.carRental) {
      details.add(
        '${AppStrings.pickupLocation}: ${_pickupController.text.trim()}',
      );
    }
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) details.add(notes);
    return details.isEmpty ? null : details.join('. ');
  }

  Future<void> _confirmBooking() async {
    if (listing.category == ListingCategory.carRental &&
        _pickupController.text.trim().isEmpty) {
      _showError(AppStrings.pickupRequiredError);
      return;
    }

    if (!widget.bookingRepository.isAuthenticated) {
      final authenticated = await showAuthenticationSheet(
        context,
        widget.bookingRepository,
      );
      if (!authenticated || !mounted) return;
      widget.onAccountChanged();
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.bookingRepository.createBooking(
        BookingRequest(
          listingId: listing.id,
          serviceName: listing.title,
          startsAt: _startsAt,
          endsAt: _endsAt,
          priceAmount: _totalPrice,
          currency: listing.currency,
          customerNotes: _customerNotes,
        ),
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await _showSuccess();
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  Future<void> _showSuccess() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: AppPalette.forest,
            size: 38,
          ),
          title: const Text(AppStrings.bookingCreatedTitle),
          content: const Text(AppStrings.bookingCreatedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(AppStrings.keepExploring),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                widget.onViewBookings();
              },
              child: const Text(AppStrings.viewBookings),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.alabaster,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 340,
            backgroundColor: AppPalette.alabaster,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: widget.previewOnly
                  ? const SizedBox.shrink()
                  : IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      tooltip: AppStrings.back,
                      icon: const Icon(Icons.arrow_back),
                    ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'listing_image_${listing.id}',
                transitionOnUserGestures: true,
                child: ListingImage(listing: listing),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ListingHeader(listing: listing),
                      if (widget.previewOnly) ...[
                        const SizedBox(height: 14),
                        const _PreviewNotice(),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        AppStrings.about,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        listing.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppPalette.slate,
                          height: 1.6,
                        ),
                      ),
                      if (listing.availabilityNote != null) ...[
                        const SizedBox(height: 20),
                        _AvailabilityNote(note: listing.availabilityNote!),
                      ],
                      if (listing.businessDetails.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        Text(
                          AppStrings.businessHighlights,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        BusinessDetailsSection(listing: listing),
                      ],
                      if (!widget.previewOnly) ...[
                        const SizedBox(height: 30),
                        Text(
                          AppStrings.bookingDetails,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppPalette.warmField,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _bookingControls(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.previewOnly
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x180466C8),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.total,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(color: AppPalette.slate),
                                ),
                                Text(
                                  formatCurrency(_totalPrice, listing.currency),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppPalette.terracotta,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _isSubmitting ? null : _confirmBooking,
                            icon: _isSubmitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.calendar_month_outlined),
                            label: const Text(AppStrings.confirmBooking),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _bookingControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_usesDateRange)
          _SelectionTile(
            icon: Icons.date_range_outlined,
            label: AppStrings.selectDates,
            value: formatDateRange(_dateRange.start, _dateRange.end),
            onTap: _chooseDateRange,
          )
        else ...[
          _SelectionTile(
            icon: Icons.event_outlined,
            label: AppStrings.selectDate,
            value: formatDate(_serviceDate),
            onTap: _chooseServiceDate,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.selectTime,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hour in _serviceHours)
                ChoiceChip(
                  selected: _serviceHour == hour,
                  onSelected: (_) => setState(() => _serviceHour = hour),
                  label: Text(formatTime(DateTime(2026, 1, 1, hour))),
                ),
            ],
          ),
        ],
        if (listing.category == ListingCategory.stay) ...[
          const SizedBox(height: 16),
          _GuestStepper(
            count: _guestCount,
            onDecrease: _guestCount == 1
                ? null
                : () => setState(() => _guestCount--),
            onIncrease: _guestCount == 12
                ? null
                : () => setState(() => _guestCount++),
          ),
        ],
        if (listing.category == ListingCategory.carRental) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _pickupController,
            decoration: _inputDecoration(
              label: AppStrings.pickupLocation,
              hint: AppStrings.pickupHint,
              icon: Icons.location_on_outlined,
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          minLines: 2,
          maxLines: 4,
          decoration: _inputDecoration(
            label: AppStrings.bookingNotes,
            hint: AppStrings.bookingNotesHint,
            icon: Icons.notes_outlined,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppPalette.warmSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.forest),
      ),
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.warmField,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, color: AppPalette.forest),
            SizedBox(width: 9),
            Expanded(child: Text(AppStrings.customerPreviewMessage)),
          ],
        ),
      ),
    );
  }
}

class _ListingHeader extends StatelessWidget {
  const _ListingHeader({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.forest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  listingCategoryIcon(listing.category),
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  listingCategoryLabel(listing.category),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(listing.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppPalette.forest,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                listing.location,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.slate),
              ),
            ),
            if (listing.rating > 0) ...[
              const Icon(Icons.star, size: 18, color: AppPalette.terracotta),
              const SizedBox(width: 4),
              Text(
                '${listing.rating.toStringAsFixed(1)} '
                '(${AppStrings.reviewCount(listing.reviewCount)})',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AvailabilityNote extends StatelessWidget {
  const _AvailabilityNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule_outlined, color: AppPalette.forest, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.availability,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 3),
              Text(
                note,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.slate),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.warmSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppPalette.forest),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppPalette.slate,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(value, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppPalette.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestStepper extends StatelessWidget {
  const _GuestStepper({
    required this.count,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int count;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.warmSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.group_outlined, color: AppPalette.forest),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppStrings.guestCount(count),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              onPressed: onDecrease,
              tooltip: AppStrings.decreaseGuests,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              onPressed: onIncrease,
              tooltip: AppStrings.increaseGuests,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
