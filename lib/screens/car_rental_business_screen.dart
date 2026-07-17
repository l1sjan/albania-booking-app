import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
import '../models/rental_car.dart';
import '../services/rental_car_repository.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';
import '../widgets/business_photo_picker.dart';
import 'car_fleet_detail_screen.dart';

class CarRentalBusinessScreen extends StatefulWidget {
  const CarRentalBusinessScreen({
    super.key,
    required this.business,
    required this.repository,
    required this.onEditBusiness,
  });

  final Listing business;
  final RentalCarRepository repository;
  final VoidCallback onEditBusiness;

  @override
  State<CarRentalBusinessScreen> createState() =>
      _CarRentalBusinessScreenState();
}

class _CarRentalBusinessScreenState extends State<CarRentalBusinessScreen> {
  late Future<_FleetDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_FleetDashboardData> _loadDashboard() async {
    final now = DateTime.now();
    final carsRequest = widget.repository.fetchCars(widget.business.id);
    final bookedDaysRequest = widget.repository.fetchBookedDaysForMonth(
      widget.business.id,
      now,
    );
    final metricsRequest = widget.repository.fetchFleetMetrics(
      widget.business.id,
      now,
    );
    return _FleetDashboardData(
      cars: await carsRequest,
      bookedDaysByCarId: await bookedDaysRequest,
      metrics: await metricsRequest,
    );
  }

  Future<void> _refresh() async {
    final request = _loadDashboard();
    setState(() {
      _dashboardFuture = request;
    });
    await request;
  }

  Future<RentalCar?> _openEditor([RentalCar? car]) async {
    final draft = await Navigator.of(context).push<RentalCarDraft>(
      MaterialPageRoute(
        builder: (context) =>
            _RentalCarEditor(listingId: widget.business.id, car: car),
      ),
    );
    if (draft == null || !mounted) return null;

    try {
      await widget.repository.saveCar(draft, carId: car?.id);
      RentalCar? savedCar;
      if (car != null) {
        final cars = await widget.repository.fetchCars(car.listingId);
        for (final candidate in cars) {
          if (candidate.id == car.id) {
            savedCar = candidate;
            break;
          }
        }
      }
      if (!mounted) return savedCar;
      _showMessage(
        car == null ? AppStrings.carSaved : AppStrings.carChangesSaved,
      );
      await _refresh();
      return savedCar;
    } catch (error) {
      if (mounted) {
        _showMessage('${AppStrings.fleetSaveError}: $error', isError: true);
      }
      return null;
    }
  }

  Future<RentalCar?> _editCarFromDetail(RentalCar car) => _openEditor(car);

  Future<void> _deleteCar(RentalCar car) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text(AppStrings.deleteCarTitle),
        content: Text('${car.model}\n\n${AppStrings.deleteCarMessage}'),
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
    if (confirmed != true || !mounted) return;

    try {
      await widget.repository.deleteCar(car.id);
      if (!mounted) return;
      _showMessage(AppStrings.carDeleted);
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showMessage('${AppStrings.fleetSaveError}: $error', isError: true);
      }
    }
  }

  Future<void> _openCarDetails(RentalCar car) async {
    final action = await Navigator.of(context).push<CarFleetDetailAction>(
      MaterialPageRoute(
        builder: (context) => CarFleetDetailScreen(
          car: car,
          repository: widget.repository,
          onEditCar: _editCarFromDetail,
        ),
      ),
    );
    if (!mounted) return;
    if (action == null) {
      await _refresh();
      return;
    }

    await _deleteCar(car);
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_FleetDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          final dashboard = snapshot.data;
          final cars = dashboard?.cars ?? const <RentalCar>[];
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: _FleetHeader(
                        business: widget.business,
                        cars: cars,
                        metrics: dashboard?.metrics ?? RentalFleetMetrics.zero,
                        onAddCar: () => _openEditor(),
                        onEditBusiness: widget.onEditBusiness,
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
                  child: _FleetMessage(
                    icon: Icons.cloud_off_outlined,
                    title: AppStrings.fleetLoadError,
                    message: snapshot.error.toString(),
                    actionLabel: AppStrings.tryAgain,
                    onAction: _refresh,
                  ),
                )
              else if (cars.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FleetMessage(
                    icon: Icons.directions_car_outlined,
                    title: AppStrings.noCarsTitle,
                    message: AppStrings.noCarsMessage,
                    actionLabel: AppStrings.addCar,
                    onAction: () => _openEditor(),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Text(
                          AppStrings.fleetVehiclesTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index.isOdd) return const SizedBox(height: 12);
                      final car = cars[index ~/ 2];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: _RentalCarCard(
                            car: car,
                            bookedDaysThisMonth:
                                dashboard?.bookedDaysByCarId[car.id] ?? 0,
                            onTap: () => _openCarDetails(car),
                          ),
                        ),
                      );
                    }, childCount: cars.length * 2 - 1),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FleetDashboardData {
  const _FleetDashboardData({
    required this.cars,
    required this.bookedDaysByCarId,
    required this.metrics,
  });

  final List<RentalCar> cars;
  final Map<String, int> bookedDaysByCarId;
  final RentalFleetMetrics metrics;
}

class _FleetHeader extends StatelessWidget {
  const _FleetHeader({
    required this.business,
    required this.cars,
    required this.metrics,
    required this.onAddCar,
    required this.onEditBusiness,
  });

  final Listing business;
  final List<RentalCar> cars;
  final RentalFleetMetrics metrics;
  final VoidCallback onAddCar;
  final VoidCallback onEditBusiness;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.warmOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.fleetTitle,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xD9FFFFFF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      business.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: Color(0xD9FFFFFF),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            business.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xD9FFFFFF)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onEditBusiness,
                tooltip: AppStrings.editBusinessDetails,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x1FFFFFFF),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FleetStat(
                label: AppStrings.totalCars,
                value: cars.length.toString(),
              ),
              _FleetStat(
                label: AppStrings.revenueThisMonth,
                value: formatCurrency(
                  metrics.revenueThisMonth,
                  business.currency,
                ),
              ),
              _FleetStat(
                label: AppStrings.bookedCarsToday,
                value: metrics.bookedCarsToday.toString(),
              ),
              _FleetStat(
                label: AppStrings.unavailableCars,
                value: metrics.unavailableCarsToday.toString(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddCar,
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.steelAzure,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.addCar),
          ),
        ],
      ),
    );
  }
}

class _FleetStat extends StatelessWidget {
  const _FleetStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: const Color(0xD9FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _RentalCarCard extends StatelessWidget {
  const _RentalCarCard({
    required this.car,
    required this.bookedDaysThisMonth,
    required this.onTap,
  });

  final RentalCar car;
  final int bookedDaysThisMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: car.model,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.warmOutline),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 198,
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  height: double.infinity,
                  child: _CarImage(car: car),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          car.engine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.slate),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _CarMeta(
                              icon: Icons.settings_outlined,
                              label:
                                  car.transmission == CarTransmission.automatic
                                  ? AppStrings.automatic
                                  : AppStrings.manual,
                            ),
                            _CarMeta(
                              icon: Icons.calendar_today_outlined,
                              label:
                                  car.productionYear?.toString() ??
                                  AppStrings.yearNotSet,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppStrings.perDay(
                                  formatCurrency(car.pricePerDay, car.currency),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppPalette.terracotta,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                AppStrings.bookedDaysThisMonth(
                                  bookedDaysThisMonth,
                                ),
                                maxLines: 2,
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppPalette.forest,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _CarMeta extends StatelessWidget {
  const _CarMeta({required this.icon, required this.label});

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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppPalette.forest),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _CarImage extends StatelessWidget {
  const _CarImage({required this.car});

  final RentalCar car;

  @override
  Widget build(BuildContext context) {
    if (car.imageUrl != null) {
      return Image.network(
        car.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _CarPlaceholder(),
      );
    }
    return const _CarPlaceholder();
  }
}

class _CarPlaceholder extends StatelessWidget {
  const _CarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.sand, AppPalette.sage],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_outlined,
          size: 38,
          color: AppPalette.forest,
        ),
      ),
    );
  }
}

class _RentalCarEditor extends StatefulWidget {
  const _RentalCarEditor({required this.listingId, this.car});

  final String listingId;
  final RentalCar? car;

  @override
  State<_RentalCarEditor> createState() => _RentalCarEditorState();
}

class _RentalCarEditorState extends State<_RentalCarEditor> {
  static const _engineSizes = [
    '0.8L',
    '1.0L',
    '1.2L',
    '1.4L',
    '1.5L',
    '1.6L',
    '1.8L',
    '2.0L',
    '2.2L',
    '2.5L',
    '3.0L',
    'Electric',
  ];
  static const _seatOptions = [2, 4, 5, 7, 8, 9];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _model;
  late final TextEditingController _price;
  late String? _engineSize;
  late int? _productionYear;
  late int? _seatCount;
  late String _currency;
  late CarTransmission _transmission;
  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _removeExistingImage = false;

  @override
  void initState() {
    super.initState();
    final car = widget.car;
    _model = TextEditingController(text: car?.model);
    _engineSize = car?.engine;
    _productionYear = car?.productionYear;
    _seatCount = car?.seatCount;
    _price = TextEditingController(
      text: car == null ? '' : formatNumber(car.pricePerDay),
    );
    _currency = car?.currency ?? 'ALL';
    _transmission = car?.transmission ?? CarTransmission.automatic;
  }

  @override
  void dispose() {
    _model.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageFileName = image.name;
      _removeExistingImage = false;
    });
  }

  void _removePhoto() {
    setState(() {
      _imageBytes = null;
      _imageFileName = null;
      _removeExistingImage = widget.car?.imageUrl != null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.car != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.save_outlined),
          title: const Text(AppStrings.saveCarChangesTitle),
          content: const Text(AppStrings.saveCarChangesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(AppStrings.saveChanges),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    Navigator.of(context).pop(
      RentalCarDraft(
        listingId: widget.listingId,
        model: _model.text,
        engine: _engineSize!,
        productionYear: _productionYear,
        seatCount: _seatCount,
        pricePerDay: double.parse(_price.text.replaceAll(',', '')),
        currency: _currency,
        transmission: _transmission,
        imageUrl: _removeExistingImage ? null : widget.car?.imageUrl,
        imageBytes: _imageBytes,
        imageFileName: _imageFileName,
        isAvailable: widget.car?.isAvailable ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.car == null ? AppStrings.addCar : AppStrings.editCar,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  32 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  Text(
                    widget.car == null
                        ? AppStrings.fleetMessage
                        : AppStrings.editCarMessage,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppPalette.slate),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _model,
                    decoration: _decoration(
                      AppStrings.carModel,
                      hint: AppStrings.carModelHint,
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _engineSize,
                    decoration: _decoration(AppStrings.carEngine),
                    items: _availableEngineSizes
                        .map(
                          (engineSize) => DropdownMenuItem(
                            value: engineSize,
                            child: Text(engineSize),
                          ),
                        )
                        .toList(growable: false),
                    validator: (value) =>
                        value == null ? AppStrings.requiredField : null,
                    onChanged: (value) => setState(() => _engineSize = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _productionYear,
                    decoration: _decoration(AppStrings.productionYear),
                    items: _productionYears
                        .map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          ),
                        )
                        .toList(growable: false),
                    validator: (value) =>
                        value == null ? AppStrings.requiredField : null,
                    onChanged: (value) =>
                        setState(() => _productionYear = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CarTransmission>(
                    initialValue: _transmission,
                    decoration: _decoration(AppStrings.carTransmission),
                    items: const [
                      DropdownMenuItem(
                        value: CarTransmission.automatic,
                        child: Text(AppStrings.automatic),
                      ),
                      DropdownMenuItem(
                        value: CarTransmission.manual,
                        child: Text(AppStrings.manual),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _transmission = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _seatCount,
                    decoration: _decoration(AppStrings.seatCount),
                    items: _seatOptions
                        .map(
                          (seats) => DropdownMenuItem(
                            value: seats,
                            child: Text(seats.toString()),
                          ),
                        )
                        .toList(growable: false),
                    validator: (value) =>
                        value == null ? AppStrings.requiredField : null,
                    onChanged: (value) => setState(() => _seatCount = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoration(AppStrings.carPricePerDay),
                          validator: (value) {
                            final price = double.tryParse(
                              (value ?? '').replaceAll(',', ''),
                            );
                            return price != null && price >= 0
                                ? null
                                : AppStrings.invalidPrice;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: _decoration(AppStrings.currencyLabel),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _currency = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BusinessPhotoPicker(
                    selectedBytes: _imageBytes,
                    existingImageUrl: _removeExistingImage
                        ? null
                        : widget.car?.imageUrl,
                    onChoose: _choosePhoto,
                    onRemove: _removePhoto,
                    title: AppStrings.carPhoto,
                    message: AppStrings.carPhotoMessage,
                    placeholderIcon: Icons.directions_car_outlined,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      widget.car == null
                          ? AppStrings.saveCar
                          : AppStrings.saveChanges,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return (value ?? '').trim().isEmpty ? AppStrings.requiredField : null;
  }

  List<String> get _availableEngineSizes {
    final selected = _engineSize;
    if (selected == null || _engineSizes.contains(selected)) {
      return _engineSizes;
    }
    return [selected, ..._engineSizes];
  }

  List<int> get _productionYears {
    final latestYear = DateTime.now().year + 1;
    return List<int>.generate(
      latestYear - 1950 + 1,
      (index) => latestYear - index,
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppPalette.warmField,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.forest),
      ),
    );
  }
}

class _FleetMessage extends StatelessWidget {
  const _FleetMessage({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppPalette.forest),
            const SizedBox(height: 14),
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
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
