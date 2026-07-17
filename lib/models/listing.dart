enum ListingCategory { carRental, barber, dentist, restaurant, stay }

class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.category,
    required this.currency,
    this.imageUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.defaultBookingDurationMinutes,
    this.availabilityNote,
    this.ownerId,
    this.phone,
    this.email,
    this.websiteUrl,
    this.city,
    this.businessDetails = const {},
    this.country = 'Albania',
    this.isActive = true,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    final category = _category(json['category']);
    final rawPrice = category == ListingCategory.stay
        ? json['price_per_night'] ?? json['price_from']
        : json['price_from'] ?? json['price_per_night'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');

    if (price == null) {
      throw const FormatException('Invalid listing price_per_night value.');
    }

    final imageUrl = _imageUrl(json);

    return Listing(
      id: _requiredText(json['id'], 'id'),
      title: _requiredText(json['title'] ?? json['name'], 'title'),
      description: json['description']?.toString().trim() ?? '',
      price: price,
      location: _requiredText(
        json['location'] ?? _legacyLocation(json),
        'location',
      ),
      category: category,
      currency: _currency(json['currency'], category),
      imageUrl: imageUrl,
      rating: _optionalDouble(json['rating']),
      reviewCount: _optionalInt(json['review_count']),
      defaultBookingDurationMinutes: _nullableInt(
        json['default_booking_duration_minutes'],
      ),
      availabilityNote: _optionalText(json['availability_note']),
      ownerId: _optionalText(json['owner_id']),
      phone: _optionalText(json['phone']),
      email: _optionalText(json['email']),
      websiteUrl: _optionalText(json['website_url']),
      city: _optionalText(json['city']),
      businessDetails: _businessDetails(json['business_details']),
      country: _optionalText(json['country']) ?? 'Albania',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String title;
  final String description;
  final double price;
  final String location;
  final ListingCategory category;
  final String currency;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final int? defaultBookingDurationMinutes;
  final String? availabilityNote;
  final String? ownerId;
  final String? phone;
  final String? email;
  final String? websiteUrl;
  final String? city;
  final Map<String, dynamic> businessDetails;
  final String country;
  final bool isActive;

  bool get isService => category != ListingCategory.stay;

  Listing copyWith({bool? isActive}) {
    return Listing(
      id: id,
      title: title,
      description: description,
      price: price,
      location: location,
      category: category,
      currency: currency,
      imageUrl: imageUrl,
      rating: rating,
      reviewCount: reviewCount,
      defaultBookingDurationMinutes: defaultBookingDurationMinutes,
      availabilityNote: availabilityNote,
      ownerId: ownerId,
      phone: phone,
      email: email,
      websiteUrl: websiteUrl,
      city: city,
      businessDetails: businessDetails,
      country: country,
      isActive: isActive ?? this.isActive,
    );
  }

  static String _requiredText(Object? value, String field) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw FormatException('Missing required listing field: $field.');
    }
    return text;
  }

  static String _legacyLocation(Map<String, dynamic> json) {
    return [
      json['city']?.toString().trim(),
      json['country']?.toString().trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
  }

  static String? _imageUrl(Map<String, dynamic> json) {
    final canonicalUrl = json['image_url']?.toString().trim();
    if (canonicalUrl != null && canonicalUrl.isNotEmpty) return canonicalUrl;

    final legacyUrls = json['image_urls'];
    if (legacyUrls is List && legacyUrls.isNotEmpty) {
      final firstUrl = legacyUrls.first?.toString().trim();
      if (firstUrl != null && firstUrl.isNotEmpty) return firstUrl;
    }

    return null;
  }

  static double _optionalDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _optionalInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _businessDetails(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key.toString(), item)),
      );
    }
    return const {};
  }

  static ListingCategory _category(Object? value) {
    return switch (value?.toString()) {
      'car_rental' => ListingCategory.carRental,
      'barber' => ListingCategory.barber,
      'dentist' => ListingCategory.dentist,
      'restaurant' => ListingCategory.restaurant,
      _ => ListingCategory.stay,
    };
  }

  static String _currency(Object? value, ListingCategory category) {
    final currency = value?.toString().trim().toUpperCase() ?? '';
    if (currency.isNotEmpty) return currency;
    return category == ListingCategory.stay ? 'USD' : 'ALL';
  }
}
