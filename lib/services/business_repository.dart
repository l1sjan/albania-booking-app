import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/listing.dart';

class BusinessListingDraft {
  const BusinessListingDraft({
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.category,
    required this.currency,
    required this.city,
    this.imageUrl,
    this.imageBytes,
    this.imageFileName,
    this.businessDetails = const {},
    this.phone,
    this.email,
    this.websiteUrl,
    this.availabilityNote,
    this.defaultBookingDurationMinutes,
  });

  factory BusinessListingDraft.fromListing(Listing listing) {
    return BusinessListingDraft(
      title: listing.title,
      description: listing.description,
      price: listing.price,
      location: listing.location,
      category: listing.category,
      currency: listing.currency,
      city: listing.city ?? listing.location.split(',').first.trim(),
      imageUrl: listing.imageUrl,
      businessDetails: listing.businessDetails,
      phone: listing.phone,
      email: listing.email,
      websiteUrl: listing.websiteUrl,
      availabilityNote: listing.availabilityNote,
      defaultBookingDurationMinutes: listing.defaultBookingDurationMinutes,
    );
  }

  final String title;
  final String description;
  final double price;
  final String location;
  final ListingCategory category;
  final String currency;
  final String city;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final Map<String, dynamic> businessDetails;
  final String? phone;
  final String? email;
  final String? websiteUrl;
  final String? availabilityNote;
  final int? defaultBookingDurationMinutes;
}

abstract interface class BusinessRepository {
  Future<List<Listing>> fetchOwnerListings();

  Future<bool> verifyCurrentPassword(String password);

  Future<void> saveListing(BusinessListingDraft draft, {String? listingId});

  Future<void> setListingActive(String listingId, bool isActive);
}

class SupabaseBusinessRepository implements BusinessRepository {
  const SupabaseBusinessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> verifyCurrentPassword(String password) async {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) return false;

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user?.id == user.id;
    } on AuthException {
      return false;
    }
  }

  @override
  Future<List<Listing>> fetchOwnerListings() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return const [];

    final rows = await _client
        .from('listings')
        .select()
        .eq('owner_id', ownerId)
        .order('updated_at', ascending: false);
    return rows.map(Listing.fromJson).toList(growable: false);
  }

  @override
  Future<void> saveListing(
    BusinessListingDraft draft, {
    String? listingId,
  }) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) {
      throw const AuthException('Sign in is required to manage a business.');
    }

    if (listingId == null) {
      final existing = await _client
          .from('listings')
          .select('id')
          .eq('owner_id', ownerId)
          .limit(1);
      if (existing.isNotEmpty) {
        throw StateError('Each business account can manage one business.');
      }
    }

    final imageUrl = await _resolveImageUrl(draft, ownerId);

    final legacyCompatibleRow = <String, dynamic>{
      'owner_id': ownerId,
      'name': draft.title.trim(),
      'description': draft.description.trim(),
      'price_from': draft.price,
      'category': _categoryValue(draft.category),
      'currency': draft.currency.trim().toUpperCase(),
      'city': draft.city.trim(),
      'country': 'Albania',
      'image_urls': imageUrl == null ? <String>[] : [imageUrl],
      'phone': _nullableText(draft.phone),
      'email': _nullableText(draft.email),
      'website_url': _nullableText(draft.websiteUrl),
      'availability_note': _nullableText(draft.availabilityNote),
      'default_booking_duration_minutes': draft.defaultBookingDurationMinutes,
    };
    final currentSchemaRow = <String, dynamic>{
      ...legacyCompatibleRow,
      'title': draft.title.trim(),
      'price_per_night': draft.price,
      'location': draft.location.trim(),
      'image_url': imageUrl,
      'business_details': draft.businessDetails,
    };

    if (listingId == null) {
      final slug = _slugFor(draft.title);
      await _writeWithSchemaFallback(
        currentSchemaRow: {...currentSchemaRow, 'slug': slug},
        legacyCompatibleRow: {...legacyCompatibleRow, 'slug': slug},
      );
      return;
    }

    await _writeWithSchemaFallback(
      currentSchemaRow: currentSchemaRow,
      legacyCompatibleRow: legacyCompatibleRow,
      listingId: listingId,
      ownerId: ownerId,
    );
  }

  @override
  Future<void> setListingActive(String listingId, bool isActive) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) {
      throw const AuthException('Sign in is required to manage a business.');
    }
    await _client
        .from('listings')
        .update({'is_active': isActive})
        .eq('id', listingId)
        .eq('owner_id', ownerId);
  }

  static String _slugFor(String title) {
    final normalized = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final prefix = normalized.isEmpty ? 'business' : normalized;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}';
  }

  static String? _nullableText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _categoryValue(ListingCategory category) {
    return switch (category) {
      ListingCategory.carRental => 'car_rental',
      ListingCategory.barber => 'barber',
      ListingCategory.dentist => 'dentist',
      ListingCategory.restaurant => 'restaurant',
      ListingCategory.stay => 'other',
    };
  }

  Future<String?> _resolveImageUrl(
    BusinessListingDraft draft,
    String ownerId,
  ) async {
    if (draft.imageBytes == null) return _nullableText(draft.imageUrl);

    final extension = _fileExtension(draft.imageFileName);
    final path = '$ownerId/${DateTime.now().microsecondsSinceEpoch}.$extension';
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

  Future<void> _writeWithSchemaFallback({
    required Map<String, dynamic> currentSchemaRow,
    required Map<String, dynamic> legacyCompatibleRow,
    String? listingId,
    String? ownerId,
  }) async {
    try {
      await _writeRow(currentSchemaRow, listingId: listingId, ownerId: ownerId);
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST204') rethrow;
      await _writeRow(
        legacyCompatibleRow,
        listingId: listingId,
        ownerId: ownerId,
      );
    }
  }

  Future<void> _writeRow(
    Map<String, dynamic> row, {
    String? listingId,
    String? ownerId,
  }) async {
    if (listingId == null) {
      await _client.from('listings').insert(row);
      return;
    }
    await _client
        .from('listings')
        .update(row)
        .eq('id', listingId)
        .eq('owner_id', ownerId!);
  }
}
