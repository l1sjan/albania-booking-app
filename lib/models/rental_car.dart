enum CarTransmission { automatic, manual }

class RentalCar {
  const RentalCar({
    required this.id,
    required this.listingId,
    required this.model,
    required this.engine,
    required this.pricePerDay,
    required this.currency,
    required this.transmission,
    this.productionYear,
    this.seatCount,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory RentalCar.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price_per_day'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');
    if (price == null) {
      throw const FormatException('Invalid rental car price_per_day value.');
    }

    return RentalCar(
      id: _requiredText(json['id'], 'id'),
      listingId: _requiredText(json['listing_id'], 'listing_id'),
      model: _requiredText(json['model'], 'model'),
      engine: _requiredText(json['engine'], 'engine'),
      pricePerDay: price,
      currency: _currency(json['currency']),
      transmission: json['transmission']?.toString() == 'manual'
          ? CarTransmission.manual
          : CarTransmission.automatic,
      productionYear: _optionalInt(json['production_year']),
      seatCount: _optionalInt(json['seat_count']),
      imageUrl: _optionalText(json['image_url']),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  final String id;
  final String listingId;
  final String model;
  final String engine;
  final double pricePerDay;
  final String currency;
  final CarTransmission transmission;
  final int? productionYear;
  final int? seatCount;
  final String? imageUrl;
  final bool isAvailable;

  RentalCar copyWith({bool? isAvailable}) {
    return RentalCar(
      id: id,
      listingId: listingId,
      model: model,
      engine: engine,
      pricePerDay: pricePerDay,
      currency: currency,
      transmission: transmission,
      productionYear: productionYear,
      seatCount: seatCount,
      imageUrl: imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  static String _requiredText(Object? value, String field) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw FormatException('Missing required rental car field: $field.');
    }
    return text;
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _optionalInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _currency(Object? value) {
    final currency = value?.toString().trim().toUpperCase() ?? '';
    return currency.isEmpty ? 'ALL' : currency;
  }
}

class RentalCarReservation {
  const RentalCarReservation({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;
}

class RentalCarUnavailability {
  const RentalCarUnavailability({
    required this.id,
    required this.rentalCarId,
    required this.startsOn,
    required this.endsOn,
    this.reason,
  });

  factory RentalCarUnavailability.fromJson(Map<String, dynamic> json) {
    return RentalCarUnavailability(
      id: RentalCar._requiredText(json['id'], 'id'),
      rentalCarId: RentalCar._requiredText(
        json['rental_car_id'],
        'rental_car_id',
      ),
      startsOn: DateTime.parse(json['starts_on'].toString()),
      endsOn: DateTime.parse(json['ends_on'].toString()),
      reason: RentalCar._optionalText(json['reason']),
    );
  }

  final String id;
  final String rentalCarId;
  final DateTime startsOn;
  final DateTime endsOn;
  final String? reason;
}
