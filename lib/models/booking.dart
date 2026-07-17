enum BookingStatus { pending, confirmed, completed, canceled }

class BookingRequest {
  const BookingRequest({
    required this.listingId,
    required this.serviceName,
    required this.startsAt,
    required this.endsAt,
    required this.priceAmount,
    required this.currency,
    this.customerNotes,
    this.rentalCarId,
  });

  final String listingId;
  final String serviceName;
  final DateTime startsAt;
  final DateTime endsAt;
  final double priceAmount;
  final String currency;
  final String? customerNotes;
  final String? rentalCarId;
}

class Booking {
  const Booking({
    required this.id,
    required this.listingId,
    required this.serviceName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.currency,
    this.priceAmount,
    this.customerNotes,
    this.listingNotes,
    this.cancellationReason,
    this.rentalCarId,
    this.listingTitle,
    this.listingLocation,
    this.listingImageUrl,
    this.rentalCarModel,
    this.rentalCarImageUrl,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final listingData = json['listings'];
    final listing = listingData is Map
        ? Map<String, dynamic>.from(listingData)
        : const <String, dynamic>{};
    final rentalCarData = json['rental_cars'];
    final rentalCar = rentalCarData is Map
        ? Map<String, dynamic>.from(rentalCarData)
        : const <String, dynamic>{};

    return Booking(
      id: json['id'].toString(),
      listingId: json['listing_id'].toString(),
      serviceName: json['service_name']?.toString() ?? '',
      startsAt: DateTime.parse(json['starts_at'].toString()).toLocal(),
      endsAt: DateTime.parse(json['ends_at'].toString()).toLocal(),
      status: _status(json['status']),
      priceAmount: _optionalDouble(json['price_amount']),
      currency: json['currency']?.toString().trim().toUpperCase() ?? 'ALL',
      customerNotes: _optionalText(json['customer_notes']),
      listingNotes: _optionalText(json['listing_notes']),
      cancellationReason: _optionalText(json['cancellation_reason']),
      rentalCarId: _optionalText(json['rental_car_id']),
      listingTitle: _optionalText(listing['title'] ?? listing['name']),
      listingLocation: _optionalText(
        listing['location'] ?? _legacyLocation(listing),
      ),
      listingImageUrl: _optionalText(
        listing['image_url'] ?? _legacyImageUrl(listing),
      ),
      rentalCarModel: _optionalText(rentalCar['model']),
      rentalCarImageUrl: _optionalText(rentalCar['image_url']),
    );
  }

  final String id;
  final String listingId;
  final String serviceName;
  final DateTime startsAt;
  final DateTime endsAt;
  final BookingStatus status;
  final double? priceAmount;
  final String currency;
  final String? customerNotes;
  final String? listingNotes;
  final String? cancellationReason;
  final String? rentalCarId;
  final String? listingTitle;
  final String? listingLocation;
  final String? listingImageUrl;
  final String? rentalCarModel;
  final String? rentalCarImageUrl;

  bool get isActive {
    return status != BookingStatus.completed &&
        status != BookingStatus.canceled &&
        !endsAt.isBefore(DateTime.now());
  }

  Booking copyWith({BookingStatus? status, String? cancellationReason}) {
    return Booking(
      id: id,
      listingId: listingId,
      serviceName: serviceName,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status ?? this.status,
      priceAmount: priceAmount,
      currency: currency,
      customerNotes: customerNotes,
      listingNotes: listingNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      rentalCarId: rentalCarId,
      listingTitle: listingTitle,
      listingLocation: listingLocation,
      listingImageUrl: listingImageUrl,
      rentalCarModel: rentalCarModel,
      rentalCarImageUrl: rentalCarImageUrl,
    );
  }

  static BookingStatus _status(Object? value) {
    return switch (value?.toString()) {
      'confirmed' => BookingStatus.confirmed,
      'completed' => BookingStatus.completed,
      'canceled' => BookingStatus.canceled,
      _ => BookingStatus.pending,
    };
  }

  static double? _optionalDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _legacyLocation(Map<String, dynamic> listing) {
    return [
      listing['city']?.toString().trim(),
      listing['country']?.toString().trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
  }

  static String? _legacyImageUrl(Map<String, dynamic> listing) {
    final imageUrls = listing['image_urls'];
    if (imageUrls is! List || imageUrls.isEmpty) return null;
    return imageUrls.first?.toString();
  }
}
