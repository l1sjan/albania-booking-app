import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/rental_car.dart';
import '../services/rental_car_repository.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';

enum CarFleetDetailAction { delete }

class CarFleetDetailScreen extends StatefulWidget {
  const CarFleetDetailScreen({
    super.key,
    required this.car,
    required this.repository,
    required this.onEditCar,
  });

  final RentalCar car;
  final RentalCarRepository repository;
  final Future<RentalCar?> Function(RentalCar car) onEditCar;

  @override
  State<CarFleetDetailScreen> createState() => _CarFleetDetailScreenState();
}

class _CarFleetDetailScreenState extends State<CarFleetDetailScreen> {
  late DateTime _visibleMonth;
  late Future<_CarCalendarData> _calendarFuture;
  late RentalCar _car;
  bool _isBlockingDates = false;

  @override
  void initState() {
    super.initState();
    _car = widget.car;
    _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _calendarFuture = _loadCalendar();
  }

  Future<_CarCalendarData> _loadCalendar() async {
    final reservationsRequest = widget.repository.fetchConfirmedReservations(
      _car.id,
      _visibleMonth,
    );
    final unavailableRequest = widget.repository.fetchUnavailablePeriods(
      _car.id,
      _visibleMonth,
    );
    return _CarCalendarData(
      reservations: await reservationsRequest,
      unavailablePeriods: await unavailableRequest,
    );
  }

  Future<void> _refreshCalendar({DateTime? showMonth}) async {
    if (showMonth != null) {
      _visibleMonth = DateTime(showMonth.year, showMonth.month);
    }
    final request = _loadCalendar();
    setState(() {
      _calendarFuture = request;
    });
    await request;
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + offset,
    );
    setState(() {
      _visibleMonth = nextMonth;
      _calendarFuture = _loadCalendar();
    });
  }

  Future<void> _blockDates() async {
    if (_isBlockingDates) return;
    setState(() => _isBlockingDates = true);

    final today = DateUtils.dateOnly(DateTime.now());
    final lastDate = DateTime(today.year + 2, today.month, today.day);
    try {
      final range = await showDateRangePicker(
        context: context,
        firstDate: today,
        lastDate: lastDate,
        currentDate: today,
        initialDateRange: DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        ),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        helpText: AppStrings.selectUnavailableDates,
        saveText: AppStrings.continueLabel,
      );
      if (range == null || !mounted) return;

      // Web completes the picker Future before its route finishes unmounting.
      // Let that transition settle before pushing the confirmation dialog.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final reason = await showDialog<String>(
        context: context,
        builder: (context) => _UnavailableReasonDialog(range: range),
      );
      if (reason == null || !mounted) return;

      await widget.repository.createUnavailablePeriod(
        _car.id,
        range.start,
        range.end,
        reason: reason,
      );
      if (!mounted) return;
      await _refreshCalendar(showMonth: range.start);
      if (mounted) _showMessage(AppStrings.unavailableDatesSaved);
    } catch (error) {
      if (mounted) {
        _showMessage(
          '${AppStrings.unavailableDatesError}: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isBlockingDates = false);
    }
  }

  Future<void> _removeUnavailablePeriod(RentalCarUnavailability period) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_available_outlined),
        title: const Text(AppStrings.removeUnavailableDatesTitle),
        content: const Text(AppStrings.removeUnavailableDatesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.removeUnavailableDates),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.repository.deleteUnavailablePeriod(period.id);
      if (!mounted) return;
      await _refreshCalendar();
      if (mounted) _showMessage(AppStrings.unavailableDatesRemoved);
    } catch (error) {
      if (mounted) {
        _showMessage(
          '${AppStrings.unavailableDatesError}: $error',
          isError: true,
        );
      }
    }
  }

  Future<void> _editCar() async {
    final savedCar = await widget.onEditCar(_car);
    if (!mounted || savedCar == null) return;

    setState(() {
      _car = savedCar;
    });
    _showMessage(AppStrings.carChangesSaved);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : AppPalette.forest,
        ),
      );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text(AppStrings.deleteCarTitle),
        content: Text('${_car.model}\n\n${AppStrings.deleteCarMessage}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.removeCar),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, CarFleetDetailAction.delete);
    }
  }

  @override
  Widget build(BuildContext context) {
    final car = _car;
    return Scaffold(
      appBar: AppBar(
        title: Text(car.model),
        actions: [
          IconButton(
            onPressed: _confirmDelete,
            tooltip: AppStrings.deleteCar,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<_CarCalendarData>(
        future: _calendarFuture,
        builder: (context, snapshot) {
          final calendar = snapshot.data ?? _CarCalendarData.empty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _BookingCalendar(
                month: _visibleMonth,
                reservations: calendar.reservations,
                unavailablePeriods: calendar.unavailablePeriods,
                isLoading: snapshot.connectionState == ConnectionState.waiting,
                hasError: snapshot.hasError,
                onPreviousMonth: () => _changeMonth(-1),
                onNextMonth: () => _changeMonth(1),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _isBlockingDates ? null : _blockDates,
                icon: _isBlockingDates
                    ? const Icon(Icons.hourglass_top_outlined)
                    : const Icon(Icons.event_busy_outlined),
                label: const Text(AppStrings.blockDates),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.singleUnavailableDayHint,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.slate),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.carDetails,
                style: Theme.of(context).textTheme.headlineSmall,
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
                      _CarDetailRow(
                        icon: Icons.directions_car_outlined,
                        label: AppStrings.carModel,
                        value: car.model,
                      ),
                      _CarDetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: AppStrings.productionYear,
                        value:
                            car.productionYear?.toString() ??
                            AppStrings.yearNotSet,
                      ),
                      _CarDetailRow(
                        icon: Icons.tire_repair_outlined,
                        label: AppStrings.carEngine,
                        value: car.engine,
                      ),
                      _CarDetailRow(
                        icon: Icons.settings_outlined,
                        label: AppStrings.carTransmission,
                        value: car.transmission == CarTransmission.automatic
                            ? AppStrings.automatic
                            : AppStrings.manual,
                      ),
                      _CarDetailRow(
                        icon: Icons.event_seat_outlined,
                        label: AppStrings.seatCount,
                        value:
                            car.seatCount?.toString() ?? AppStrings.seatsNotSet,
                      ),
                      _CarDetailRow(
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _editCar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.forest,
                    side: const BorderSide(color: AppPalette.forest),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text(AppStrings.editCar),
                ),
              ),
              if (calendar.unavailablePeriods.isNotEmpty) ...[
                const SizedBox(height: 20),
                _UnavailablePeriodsCard(
                  periods: calendar.unavailablePeriods,
                  onRemove: _removeUnavailablePeriod,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UnavailableReasonDialog extends StatefulWidget {
  const _UnavailableReasonDialog({required this.range});

  final DateTimeRange range;

  @override
  State<_UnavailableReasonDialog> createState() =>
      _UnavailableReasonDialogState();
}

class _UnavailableReasonDialogState extends State<_UnavailableReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.event_busy_outlined),
      title: const Text(AppStrings.confirmUnavailableDates),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDateRange(widget.range.start, widget.range.end),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(AppStrings.singleUnavailableDayHint),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: AppStrings.unavailableReason,
                hintText: AppStrings.unavailableReasonHint,
                filled: true,
              ),
              maxLength: 120,
              maxLines: 2,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(AppStrings.blockDates),
        ),
      ],
    );
  }
}

class _CarCalendarData {
  const _CarCalendarData({
    required this.reservations,
    required this.unavailablePeriods,
  });

  static const empty = _CarCalendarData(
    reservations: [],
    unavailablePeriods: [],
  );

  final List<RentalCarReservation> reservations;
  final List<RentalCarUnavailability> unavailablePeriods;
}

class _UnavailablePeriodsCard extends StatelessWidget {
  const _UnavailablePeriodsCard({
    required this.periods,
    required this.onRemove,
  });

  final List<RentalCarUnavailability> periods;
  final ValueChanged<RentalCarUnavailability> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppPalette.warmOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.unavailablePeriods,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final period in periods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.event_busy_outlined,
                  color: AppPalette.forest,
                ),
                title: Text(
                  formatDateRange(period.startsOn, period.endsOn),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: period.reason == null ? null : Text(period.reason!),
                trailing: IconButton(
                  onPressed: () => onRemove(period),
                  tooltip: AppStrings.removeUnavailableDates,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingCalendar extends StatelessWidget {
  const _BookingCalendar({
    required this.month,
    required this.reservations,
    required this.unavailablePeriods,
    required this.isLoading,
    required this.hasError,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final List<RentalCarReservation> reservations;
  final List<RentalCarUnavailability> unavailablePeriods;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmptyDays = DateTime(month.year, month.month).weekday - 1;
    final cellCount = leadingEmptyDays + daysInMonth;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppPalette.warmOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.carBookingCalendar,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: onPreviousMonth,
                  tooltip: AppStrings.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: onNextMonth,
                  tooltip: AppStrings.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              formatMonthYear(month),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppPalette.forest),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.carBookingCalendarMessage,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.slate),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _CalendarLegend(
                  color: AppPalette.terracotta,
                  label: AppStrings.confirmedBookingLegend,
                ),
                _CalendarLegend(
                  color: AppPalette.forest,
                  label: AppStrings.unavailableDateLegend,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _WeekdayHeader(),
            const SizedBox(height: 8),
            if (isLoading)
              const SizedBox(
                height: 184,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (hasError)
              SizedBox(
                height: 184,
                child: Center(
                  child: Text(
                    AppStrings.fleetLoadError,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppPalette.slate),
                  ),
                ),
              )
            else ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemCount: cellCount,
                itemBuilder: (context, index) {
                  if (index < leadingEmptyDays) return const SizedBox();
                  final day = index - leadingEmptyDays + 1;
                  final date = DateTime(month.year, month.month, day);
                  final isBooked = reservations.any(
                    (reservation) => _isBookedDate(date, reservation),
                  );
                  final isUnavailable = unavailablePeriods.any(
                    (period) => _isUnavailableDate(date, period),
                  );
                  return Semantics(
                    container: true,
                    excludeSemantics: true,
                    label: isBooked
                        ? AppStrings.bookedOn(formatDate(date))
                        : isUnavailable
                        ? AppStrings.unavailableOn(formatDate(date))
                        : formatDate(date),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isBooked
                            ? AppPalette.terracotta
                            : isUnavailable
                            ? AppPalette.forest
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$day',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isBooked
                                  ? Colors.white
                                  : isUnavailable
                                  ? Colors.white
                                  : AppPalette.charcoal,
                              fontWeight: isBooked || isUnavailable
                                  ? FontWeight.w800
                                  : null,
                            ),
                      ),
                    ),
                  );
                },
              ),
              if (reservations.isEmpty && unavailablePeriods.isEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  AppStrings.noBookingsThisMonth,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.slate),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  bool _isBookedDate(DateTime date, RentalCarReservation reservation) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      reservation.startsAt.year,
      reservation.startsAt.month,
      reservation.startsAt.day,
    );
    final end = DateTime(
      reservation.endsAt.year,
      reservation.endsAt.month,
      reservation.endsAt.day,
    );
    return !day.isBefore(start) && day.isBefore(end);
  }

  bool _isUnavailableDate(DateTime date, RentalCarUnavailability period) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      period.startsOn.year,
      period.startsOn.month,
      period.startsOn.day,
    );
    final end = DateTime(
      period.endsOn.year,
      period.endsOn.month,
      period.endsOn.day,
    );
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const SizedBox.square(dimension: 10),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final weekday in AppStrings.calendarWeekdays)
          Expanded(
            child: Text(
              weekday,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppPalette.slate,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _CarDetailRow extends StatelessWidget {
  const _CarDetailRow({
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
