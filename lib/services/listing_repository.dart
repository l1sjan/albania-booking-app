import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/listing.dart';

enum ListingFilter { all, stays, transport, beautyWellness, restaurants }

abstract interface class ListingRepository {
  Future<List<Listing>> fetchListings({
    ListingFilter filter = ListingFilter.all,
  });
}

class SupabaseListingRepository implements ListingRepository {
  const SupabaseListingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Listing>> fetchListings({
    ListingFilter filter = ListingFilter.all,
  }) async {
    final query = _client.from('listings').select();
    late final List<Map<String, dynamic>> rows;

    switch (filter) {
      case ListingFilter.all:
      case ListingFilter.restaurants:
        rows = await query;
      case ListingFilter.stays:
        rows = await query.eq('category', 'other');
      case ListingFilter.transport:
        rows = await query.eq('category', 'car_rental');
      case ListingFilter.beautyWellness:
        rows = await query.inFilter('category', ['barber', 'dentist']);
    }

    final listings = rows.map(Listing.fromJson).toList(growable: false);
    if (filter == ListingFilter.restaurants) {
      return listings
          .where((listing) => listing.category == ListingCategory.restaurant)
          .toList(growable: false);
    }

    return listings;
  }
}
