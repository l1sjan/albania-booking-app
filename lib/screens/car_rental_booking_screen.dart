import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../models/listing.dart';
import '../models/rental_car.dart';
import '../services/booking_repository.dart';
import '../services/rental_car_repository.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';
import '../widgets/auth_sheet.dart';
import 'customer_car_detail_screen.dart';

class CarRentalBookingScreen extends StatefulWidget {
  const CarRentalBookingScreen({
    super.key,
    required this.listing,
    required this.rentalCarRepository,
    required this.bookingRepository,
    required this.onViewBookings,
    required this.onAccountChanged,
  });

  final Listing listing;
  final RentalCarRepository rentalCarRepository;
  final BookingRepository bookingRepository;
  final VoidCallback onViewBookings;
  final VoidCallback onAccountChanged;

  @override
  State<CarRentalBookingScreen> createState() => _CarRentalBookingScreenState();
}

class _CarRentalBookingScreenState extends State<CarRentalBookingScreen> {
  late DateTimeRange _dateRange;
  late Future<List<RentalCar>> _carsFuture;
  String? _submittingCarId;

  DateTime get _startsAt => DateTime(
    _dateRange.start.year,
    _dateRange.start.month,
    _dateRange.start.day,
    9,
  );

  DateTime get _endsAt => DateTime(
    _dateRange.end.year,
    _dateRange.end.month,
    _dateRange.end.day,
    18,
  );

  int get _rentalDays => _dateRange.duration.inDays.clamp(1, 365);

  @override
  void initState() {
    super.initState();
    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    _dateRange = DateTimeRange(
      start: tomorrow,
      end: tomorrow.add(const Duration(days: 2)),
    );
    _carsFuture = _fetchAvailableCars();
  }

  Future<List<RentalCar>> _fetchAvailableCars() {
    return widget.rentalCarRepository.fetchAvailableCars(
      widget.listing.id,
      _startsAt,
      _endsAt,
    );
  }

  Future<void> _refreshCars() async {
    final request = _fetchAvailableCars();
    setState(() {
      _carsFuture = request;
    });
    try {
      await request;
    } catch (_) {
      // The FutureBuilder below owns the visible error state.
    }
  }

  Future<void> _chooseDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: _dateRange,
      helpText: AppStrings.selectRentalDates,
    );
    if (range == null || !mounted) return;

    setState(() {
      _dateRange = range;
      _carsFuture = _fetchAvailableCars();
    });
  }

  Future<void> _openReservationConfirmation(RentalCar car) async {
    final details = await showDialog<_RentalBookingDetails>(
      context: context,
      builder: (context) => _ReservationConfirmationDialog(
        car: car,
        dateRange: _dateRange,
        rentalDays: _rentalDays,
      ),
    );
    if (details == null || !mounted) return;
    await _submitReservation(car, details);
  }

  Future<void> _openCarDetails(RentalCar car) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CustomerCarDetailScreen(
          car: car,
          dateRange: _dateRange,
          rentalDays: _rentalDays,
          onBook: () => _openReservationConfirmation(car),
        ),
      ),
    );
    if (mounted) await _refreshCars();
  }

  Future<void> _submitReservation(
    RentalCar car,
    _RentalBookingDetails details,
  ) async {
    if (!widget.bookingRepository.isAuthenticated) {
      final authenticated = await showAuthenticationSheet(
        context,
        widget.bookingRepository,
      );
      if (!authenticated || !mounted) return;
      widget.onAccountChanged();
    }
    if (!mounted) return;

    setState(() => _submittingCarId = car.id);
    try {
      final customerNotes = [
        '${AppStrings.pickupLocation}: ${details.pickupLocation}',
        if (details.notes.isNotEmpty) details.notes,
      ].join('. ');
      await widget.bookingRepository.createBooking(
        BookingRequest(
          listingId: widget.listing.id,
          rentalCarId: car.id,
          serviceName: car.model,
          startsAt: _startsAt,
          endsAt: _endsAt,
          priceAmount: car.pricePerDay * _rentalDays,
          currency: car.currency,
          customerNotes: customerNotes,
        ),
      );
      if (!mounted) return;
      await _refreshCars();
      if (!mounted) return;
      setState(() {
        _submittingCarId = null;
      });
      await _showSuccess();
    } catch (error) {
      if (mounted) {
        _showError(error.toString());
        await _refreshCars();
      }
    } finally {
      if (mounted && _submittingCarId != null) {
        setState(() {
          _submittingCarId = null;
        });
      }
    }
  }

  Future<void> _showSuccess() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: AppPalette.forest,
          size: 38,
        ),
        title: const Text(AppStrings.bookingCreatedTitle),
        content: const Text(AppStrings.carBookingCreatedMessage),
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
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.alabaster,
      appBar: AppBar(
        title: Text(widget.listing.title),
        backgroundColor: AppPalette.alabaster,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCars,
        child: FutureBuilder<List<RentalCar>>(
          future: _carsFuture,
          builder: (context, snapshot) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                        child: _RentalHeader(
                          listing: widget.listing,
                          dateRange: _dateRange,
                          rentalDays: _rentalDays,
                          onChooseDates: _chooseDates,
                        ),
                      ),
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _RentalMessage(
                      icon: Icons.cloud_off_outlined,
                      title: AppStrings.availableCarsErrorTitle,
                      message: snapshot.error.toString(),
                      actionLabel: AppStrings.tryAgain,
                      onAction: _refreshCars,
                    ),
                  )
                else if ((snapshot.data ?? const <RentalCar>[]).isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _RentalMessage(
                      icon: Icons.event_busy_outlined,
                      title: AppStrings.noCarsAvailableTitle,
                      message: AppStrings.noCarsAvailableMessage,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                    sliver: SliverList.separated(
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: _AvailableCarCard(
                            car: snapshot.data![index],
                            rentalDays: _rentalDays,
                            isSubmitting:
                                _submittingCarId == snapshot.data![index].id,
                            onDetails: () =>
                                _openCarDetails(snapshot.data![index]),
                            onBook: () => _openReservationConfirmation(
                              snapshot.data![index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RentalHeader extends StatelessWidget {
  const _RentalHeader({
    required this.listing,
    required this.dateRange,
    required this.rentalDays,
    required this.onChooseDates,
  });

  final Listing listing;
  final DateTimeRange dateRange;
  final int rentalDays;
  final VoidCallback onChooseDates;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.chooseYourCar,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
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
          ],
        ),
        const SizedBox(height: 20),
        Material(
          color: AppPalette.warmField,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onChooseDates,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_outlined,
                    color: AppPalette.forest,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.selectRentalDates,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppPalette.slate),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDateRange(dateRange.start, dateRange.end),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppStrings.rentalDays(rentalDays),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppPalette.terracotta,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.availableForSelectedDates,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _AvailableCarCard extends StatelessWidget {
  const _AvailableCarCard({
    required this.car,
    required this.rentalDays,
    required this.isSubmitting,
    required this.onDetails,
    required this.onBook,
  });

  final RentalCar car;
  final int rentalDays;
  final bool isSubmitting;
  final VoidCallback onDetails;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final total = car.pricePerDay * rentalDays;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppPalette.warmOutline),
      ),
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 440;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          car.model,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppPalette.slate),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    car.engine,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppPalette.slate),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CarDetailChip(
                        icon: Icons.settings_outlined,
                        label: car.transmission == CarTransmission.automatic
                            ? AppStrings.automatic
                            : AppStrings.manual,
                      ),
                      _CarDetailChip(
                        icon: Icons.payments_outlined,
                        label: AppStrings.perDay(
                          formatCurrency(car.pricePerDay, car.currency),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${AppStrings.total}: ${formatCurrency(total, car.currency)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppPalette.terracotta,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: isSubmitting ? null : onBook,
                    icon: isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.calendar_month_outlined),
                    label: const Text(AppStrings.bookThisCar),
                  ),
                ],
              );
              final photo = _CarPhoto(car: car, height: vertical ? 156 : 210);
              return vertical
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [photo, const SizedBox(height: 16), details],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 220, child: photo),
                        const SizedBox(width: 18),
                        Expanded(child: details),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _CarDetailChip extends StatelessWidget {
  const _CarDetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.warmField,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppPalette.forest),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _CarPhoto extends StatelessWidget {
  const _CarPhoto({required this.car, required this.height});

  final RentalCar car;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: car.imageUrl == null
            ? const _CarImageFallback()
            : Image.network(
                car.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _CarImageFallback(),
              ),
      ),
    );
  }
}

class _CarImageFallback extends StatelessWidget {
  const _CarImageFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppPalette.sand, AppPalette.sage]),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_outlined,
          size: 42,
          color: AppPalette.forest,
        ),
      ),
    );
  }
}

class _ReservationSummary extends StatelessWidget {
  const _ReservationSummary({
    required this.car,
    required this.dateRange,
    required this.rentalDays,
  });

  final RentalCar car;
  final DateTimeRange dateRange;
  final int rentalDays;

  @override
  Widget build(BuildContext context) {
    final total = car.pricePerDay * rentalDays;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.warmField,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(car.model, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              formatDateRange(dateRange.start, dateRange.end),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.slate),
            ),
            const SizedBox(height: 6),
            Text(
              '${AppStrings.rentalDays(rentalDays)} · ${formatCurrency(total, car.currency)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppPalette.terracotta,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationConfirmationDialog extends StatefulWidget {
  const _ReservationConfirmationDialog({
    required this.car,
    required this.dateRange,
    required this.rentalDays,
  });

  final RentalCar car;
  final DateTimeRange dateRange;
  final int rentalDays;

  @override
  State<_ReservationConfirmationDialog> createState() =>
      _ReservationConfirmationDialogState();
}

class _ReservationConfirmationDialogState
    extends State<_ReservationConfirmationDialog> {
  final _pickupController = TextEditingController();
  final _notesController = TextEditingController();
  String? _pickupError;

  @override
  void dispose() {
    _pickupController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _confirm() {
    final pickupLocation = _pickupController.text.trim();
    if (pickupLocation.isEmpty) {
      setState(() => _pickupError = AppStrings.pickupRequiredError);
      return;
    }
    Navigator.pop(
      context,
      _RentalBookingDetails(
        pickupLocation: pickupLocation,
        notes: _notesController.text.trim(),
      ),
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
      errorText: label == AppStrings.pickupLocation ? _pickupError : null,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.directions_car_outlined, color: AppPalette.forest),
      title: Text(AppStrings.reserveCarTitle(widget.car.model)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReservationSummary(
              car: widget.car,
              dateRange: widget.dateRange,
              rentalDays: widget.rentalDays,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pickupController,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_pickupError != null) setState(() => _pickupError = null);
              },
              decoration: _inputDecoration(
                label: AppStrings.pickupLocation,
                hint: AppStrings.pickupHint,
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: 12),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text(AppStrings.confirmBooking),
        ),
      ],
    );
  }
}

class _RentalMessage extends StatelessWidget {
  const _RentalMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: AppPalette.forest),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.slate,
                  height: 1.5,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RentalBookingDetails {
  const _RentalBookingDetails({
    required this.pickupLocation,
    required this.notes,
  });

  final String pickupLocation;
  final String notes;
}
