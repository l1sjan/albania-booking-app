import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rental_car.dart';

class RentalFleetMetrics {
  const RentalFleetMetrics({
    required this.revenueThisMonth,
    required this.bookedCarsToday,
    required this.unavailableCarsToday,
  });

  static const zero = RentalFleetMetrics(
    revenueThisMonth: 0,
    bookedCarsToday: 0,
    unavailableCarsToday: 0,
  );

  final double revenueThisMonth;
  final int bookedCarsToday;
  final int unavailableCarsToday;
}

class RentalCarDraft {
  const RentalCarDraft({
    required this.listingId,
    required this.model,
    required this.engine,
    required this.pricePerDay,
    required this.currency,
    required this.transmission,
    this.productionYear,
    this.seatCount,
    this.imageUrl,
    this.imageBytes,
    this.imageFileName,
    this.isAvailable = true,
  });

  factory RentalCarDraft.fromCar(RentalCar car) {
    return RentalCarDraft(
      listingId: car.listingId,
      model: car.model,
      engine: car.engine,
      pricePerDay: car.pricePerDay,
      currency: car.currency,
      transmission: car.transmission,
      productionYear: car.productionYear,
      seatCount: car.seatCount,
      imageUrl: car.imageUrl,
      isAvailable: car.isAvailable,
    );
  }

  final String listingId;
  final String model;
  final String engine;
  final double pricePerDay;
  final String currency;
  final CarTransmission transmission;
  final int? productionYear;
  final int? seatCount;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final bool isAvailable;
}

abstract interface class RentalCarRepository {
  Future<List<RentalCar>> fetchCars(String listingId);

  Future<List<RentalCar>> fetchAvailableCars(
    String listingId,
    DateTime startsAt,
    DateTime endsAt,
  );

  Future<Map<String, int>> fetchBookedDaysForMonth(
    String listingId,
    DateTime month,
  );

  Future<RentalFleetMetrics> fetchFleetMetrics(
    String listingId,
    DateTime referenceDate,
  );

  Future<List<RentalCarReservation>> fetchConfirmedReservations(
    String carId,
    DateTime month,
  );

  Future<List<RentalCarUnavailability>> fetchUnavailablePeriods(
    String carId,
    DateTime month,
  );

  Future<void> createUnavailablePeriod(
    String carId,
    DateTime startsOn,
    DateTime endsOn, {
    String? reason,
  });

  Future<void> deleteUnavailablePeriod(String periodId);

  Future<void> saveCar(RentalCarDraft draft, {String? carId});

  Future<void> setCarAvailable(String carId, bool isAvailable);

  Future<void> deleteCar(String carId);
}

class SupabaseRentalCarRepository implements RentalCarRepository {
  const SupabaseRentalCarRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RentalCar>> fetchCars(String listingId) async {
    final rows = await _client
        .from('rental_cars')
        .select()
        .eq('listing_id', listingId)
        .order('created_at');
    return rows.map(RentalCar.fromJson).toList(growable: false);
  }

  @override
  Future<Map<String, int>> fetchBookedDaysForMonth(
    String listingId,
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final rows = await _client
        .from('bookings')
        .select('rental_car_id, starts_at, ends_at')
        .eq('listing_id', listingId)
        .eq('status', 'confirmed')
        .lt('starts_at', monthEnd.toUtc().toIso8601String())
        .gt('ends_at', monthStart.toUtc().toIso8601String());

    final totals = <String, int>{};
    for (final row in rows) {
      final carId = row['rental_car_id']?.toString();
      if (carId == null || carId.isEmpty) continue;
      final startsAt = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      final endsAt = DateTime.tryParse(row['ends_at']?.toString() ?? '');
      if (startsAt == null || endsAt == null) continue;

      final bookedDays = _daysInsideMonth(
        startsAt.toLocal(),
        endsAt.toLocal(),
        monthStart,
        monthEnd,
      );
      totals.update(
        carId,
        (value) => value + bookedDays,
        ifAbsent: () => bookedDays,
      );
    }
    return Map<String, int>.unmodifiable(totals);
  }

  @override
  Future<RentalFleetMetrics> fetchFleetMetrics(
    String listingId,
    DateTime referenceDate,
  ) async {
    final monthStart = DateTime(referenceDate.year, referenceDate.month);
    final monthEnd = DateTime(referenceDate.year, referenceDate.month + 1);
    final dayStart = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final bookingRows = await _client
        .from('bookings')
        .select('rental_car_id, starts_at, ends_at, price_amount')
        .eq('listing_id', listingId)
        .eq('status', 'confirmed')
        .lt('starts_at', monthEnd.toUtc().toIso8601String())
        .gt('ends_at', monthStart.toUtc().toIso8601String());

    var revenue = 0.0;
    final bookedCarIds = <String>{};
    for (final row in bookingRows) {
      final rawPrice = row['price_amount'];
      revenue += rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

      final carId = row['rental_car_id']?.toString();
      final startsAt = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      final endsAt = DateTime.tryParse(row['ends_at']?.toString() ?? '');
      if (carId == null || startsAt == null || endsAt == null) continue;
      final localStart = startsAt.toLocal();
      final localEnd = endsAt.toLocal();
      if (localStart.isBefore(dayEnd) && localEnd.isAfter(dayStart)) {
        bookedCarIds.add(carId);
      }
    }

    final carRows = await _client
        .from('rental_cars')
        .select('id, is_available')
        .eq('listing_id', listingId);
    final carIds = carRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    final unavailableCarIds = carRows
        .where((row) => row['is_available'] == false)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toSet();

    if (carIds.isNotEmpty) {
      final date = _dateOnlyString(dayStart);
      final unavailableRows = await _client
          .from('rental_car_unavailability')
          .select('rental_car_id')
          .inFilter('rental_car_id', carIds)
          .lte('starts_on', date)
          .gte('ends_on', date);
      unavailableCarIds.addAll(
        unavailableRows
            .map((row) => row['rental_car_id']?.toString())
            .whereType<String>(),
      );
    }

    return RentalFleetMetrics(
      revenueThisMonth: revenue,
      bookedCarsToday: bookedCarIds.length,
      unavailableCarsToday: unavailableCarIds.length,
    );
  }

  @override
  Future<List<RentalCarReservation>> fetchConfirmedReservations(
    String carId,
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final rows = await _client
        .from('bookings')
        .select('starts_at, ends_at')
        .eq('rental_car_id', carId)
        .eq('status', 'confirmed')
        .lt('starts_at', monthEnd.toUtc().toIso8601String())
        .gt('ends_at', monthStart.toUtc().toIso8601String())
        .order('starts_at');

    return rows
        .map((row) {
          final startsAt = DateTime.parse(
            row['starts_at'].toString(),
          ).toLocal();
          final endsAt = DateTime.parse(row['ends_at'].toString()).toLocal();
          return RentalCarReservation(startsAt: startsAt, endsAt: endsAt);
        })
        .toList(growable: false);
  }

  @override
  Future<List<RentalCarUnavailability>> fetchUnavailablePeriods(
    String carId,
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final rows = await _client
        .from('rental_car_unavailability')
        .select()
        .eq('rental_car_id', carId)
        .lt('starts_on', _dateOnlyString(monthEnd))
        .gte('ends_on', _dateOnlyString(monthStart))
        .order('starts_on');
    return rows.map(RentalCarUnavailability.fromJson).toList(growable: false);
  }

  @override
  Future<void> createUnavailablePeriod(
    String carId,
    DateTime startsOn,
    DateTime endsOn, {
    String? reason,
  }) async {
    _requireOwner();
    await _client.from('rental_car_unavailability').insert({
      'rental_car_id': carId,
      'starts_on': _dateOnlyString(startsOn),
      'ends_on': _dateOnlyString(endsOn),
      'reason': _nullableText(reason),
    });
  }

  @override
  Future<void> deleteUnavailablePeriod(String periodId) async {
    _requireOwner();
    await _client.from('rental_car_unavailability').delete().eq('id', periodId);
  }

  @override
  Future<List<RentalCar>> fetchAvailableCars(
    String listingId,
    DateTime startsAt,
    DateTime endsAt,
  ) async {
    final response = await _client.rpc(
      'available_rental_cars',
      params: {
        'p_listing_id': listingId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
      },
    );
    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    return rows.map(RentalCar.fromJson).toList(growable: false);
  }

  @override
  Future<void> saveCar(RentalCarDraft draft, {String? carId}) async {
    final ownerId = _requireOwner();
    final imageUrl = await _resolveImageUrl(draft, ownerId);
    final row = <String, dynamic>{
      'listing_id': draft.listingId,
      'model': draft.model.trim(),
      'engine': draft.engine.trim(),
      'production_year': draft.productionYear,
      'seat_count': draft.seatCount,
      'price_per_day': draft.pricePerDay,
      'currency': draft.currency.trim().toUpperCase(),
      'transmission': switch (draft.transmission) {
        CarTransmission.automatic => 'automatic',
        CarTransmission.manual => 'manual',
      },
      'image_url': imageUrl,
      'is_available': draft.isAvailable,
    };

    if (carId == null) {
      await _client.from('rental_cars').insert(row);
      return;
    }
    await _client.from('rental_cars').update(row).eq('id', carId);
  }

  @override
  Future<void> setCarAvailable(String carId, bool isAvailable) async {
    _requireOwner();
    await _client
        .from('rental_cars')
        .update({'is_available': isAvailable})
        .eq('id', carId);
  }

  @override
  Future<void> deleteCar(String carId) async {
    _requireOwner();
    await _client.from('rental_cars').delete().eq('id', carId);
  }

  String _requireOwner() {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) {
      throw const AuthException('Sign in is required to manage your fleet.');
    }
    return ownerId;
  }

  Future<String?> _resolveImageUrl(RentalCarDraft draft, String ownerId) async {
    if (draft.imageBytes == null) return _nullableText(draft.imageUrl);

    final extension = _fileExtension(draft.imageFileName);
    final path =
        '$ownerId/fleet/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final storage = _client.storage.from('business-images');
    await storage.uploadBinary(
      path,
      draft.imageBytes!,
      fileOptions: FileOptions(
        cacheControl: '31536000',
        contentType: _contentTypeFor(extension),
      ),
    );
    return storage.getPublicUrl(path);
  }

  static String? _nullableText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _fileExtension(String? fileName) {
    final extension = RegExp(
      r'\.([a-zA-Z0-9]+)$',
    ).firstMatch(fileName ?? '')?.group(1)?.toLowerCase();
    return switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      'jpg' || 'jpeg' => 'jpg',
      _ => 'jpg',
    };
  }

  static String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  static String _dateOnlyString(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static int _daysInsideMonth(
    DateTime startsAt,
    DateTime endsAt,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    final bookingStart = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final bookingEnd = DateTime(endsAt.year, endsAt.month, endsAt.day);
    final start = bookingStart.isAfter(monthStart) ? bookingStart : monthStart;
    final end = bookingEnd.isBefore(monthEnd) ? bookingEnd : monthEnd;
    return end.isAfter(start) ? end.difference(start).inDays : 0;
  }
}
