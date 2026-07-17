import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_profile.dart';
import '../models/booking.dart';

enum AuthenticationResult { authenticated, emailConfirmationRequired }

class BookingActionException implements Exception {
  const BookingActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class BookingRepository {
  bool get isAuthenticated;

  Stream<void> get passwordRecoveryEvents;

  Future<AuthenticationResult> authenticate({
    required String email,
    required String password,
    required bool createAccount,
    AccountRole accountRole = AccountRole.customer,
    String? displayName,
  });

  Future<AccountProfile?> fetchCurrentAccount();

  Future<void> updateAccountProfile({String? fullName, String? phone});

  Future<void> requestPasswordReset(String email);

  Future<void> updatePassword(String password);

  Future<void> signOut();

  Future<void> createBooking(BookingRequest request);

  Future<List<Booking>> fetchBookings();

  Future<List<Booking>> fetchOwnerBookings();

  Future<void> cancelBooking(String bookingId, {required String reason});

  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status, {
    String? cancellationReason,
  });
}

class SupabaseBookingRepository implements BookingRepository {
  const SupabaseBookingRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;

  @override
  Stream<void> get passwordRecoveryEvents => _client.auth.onAuthStateChange
      .where((state) => state.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<AuthenticationResult> authenticate({
    required String email,
    required String password,
    required bool createAccount,
    AccountRole accountRole = AccountRole.customer,
    String? displayName,
  }) async {
    if (createAccount) {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'account_role': accountRole.databaseValue,
          if (displayName != null && displayName.trim().isNotEmpty)
            'full_name': displayName.trim(),
        },
      );
      if (response.session != null && response.user != null) {
        await _syncRequestedBusinessRole(response.user!);
      }
      return response.session == null
          ? AuthenticationResult.emailConfirmationRequired
          : AuthenticationResult.authenticated;
    }

    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return AuthenticationResult.authenticated;
  }

  @override
  Future<AccountProfile?> fetchCurrentAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    await _syncRequestedBusinessRole(user);
    final row = await _client
        .from('users')
        .select('id, email, full_name, phone, avatar_url, role')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) {
      return AccountProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: user.userMetadata?['full_name']?.toString(),
        role: _requestedRole(user),
      );
    }
    return AccountProfile.fromJson(row);
  }

  @override
  Future<void> updateAccountProfile({String? fullName, String? phone}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in is required to update your profile.');
    }
    await _client
        .from('users')
        .update({
          'full_name': _nullableText(fullName),
          'phone': _nullableText(phone),
        })
        .eq('id', userId);
  }

  @override
  Future<void> requestPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }

  @override
  Future<void> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> createBooking(BookingRequest request) async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) {
      throw const AuthException('Sign in is required to create a booking.');
    }

    await _runBookingAction(() async {
      if (request.rentalCarId != null) {
        await _client.rpc(
          'create_rental_car_booking',
          params: {
            'p_listing_id': request.listingId,
            'p_rental_car_id': request.rentalCarId,
            'p_starts_at': request.startsAt.toUtc().toIso8601String(),
            'p_ends_at': request.endsAt.toUtc().toIso8601String(),
            'p_customer_notes': request.customerNotes,
          },
        );
        return;
      }

      await _client.rpc(
        'create_listing_booking',
        params: {
          'p_listing_id': request.listingId,
          'p_starts_at': request.startsAt.toUtc().toIso8601String(),
          'p_ends_at': request.endsAt.toUtc().toIso8601String(),
          'p_customer_notes': request.customerNotes,
        },
      );
    });
  }

  @override
  Future<List<Booking>> fetchBookings() async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) return const [];

    final bookingRows = await _client
        .from('bookings')
        .select(
          'id, listing_id, service_name, starts_at, ends_at, status, '
          'price_amount, currency, customer_notes, listing_notes, '
          'cancellation_reason, rental_car_id',
        )
        .eq('customer_id', customerId)
        .order('starts_at', ascending: false);

    return _hydrateBookings(bookingRows);
  }

  @override
  Future<List<Booking>> fetchOwnerBookings() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return const [];

    final listingRows = await _client
        .from('listings')
        .select('id')
        .eq('owner_id', ownerId);
    final listingIds = listingRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    if (listingIds.isEmpty) return const [];

    final bookingRows = await _client
        .from('bookings')
        .select(
          'id, listing_id, service_name, starts_at, ends_at, status, '
          'price_amount, currency, customer_notes, listing_notes, '
          'cancellation_reason, rental_car_id',
        )
        .inFilter('listing_id', listingIds)
        .order('starts_at', ascending: true);

    return _hydrateBookings(bookingRows);
  }

  @override
  Future<void> cancelBooking(String bookingId, {required String reason}) {
    return updateBookingStatus(
      bookingId,
      BookingStatus.canceled,
      cancellationReason: reason,
    );
  }

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status, {
    String? cancellationReason,
  }) async {
    await _runBookingAction(
      () => _client.rpc(
        'transition_booking_status',
        params: {
          'p_booking_id': bookingId,
          'p_status': status.name,
          'p_cancellation_reason': _nullableText(cancellationReason),
        },
      ),
    );
  }

  Future<void> _runBookingAction(Future<dynamic> Function() action) async {
    try {
      await action();
    } on PostgrestException catch (error) {
      throw _bookingActionException(error);
    }
  }

  Future<List<Booking>> _hydrateBookings(
    List<Map<String, dynamic>> bookingRows,
  ) async {
    if (bookingRows.isEmpty) return const [];

    final listingIds = bookingRows
        .map((row) => row['listing_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final listingRows = listingIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client.from('listings').select().inFilter('id', listingIds);
    final listingsById = {
      for (final row in listingRows) row['id'].toString(): row,
    };
    final carIds = bookingRows
        .map((row) => row['rental_car_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final carRows = carIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('rental_cars')
              .select('id, model, image_url')
              .inFilter('id', carIds);
    final carsById = {for (final row in carRows) row['id'].toString(): row};

    return bookingRows
        .map((row) {
          final hydrated = Map<String, dynamic>.from(row);
          final listing = listingsById[row['listing_id']?.toString()];
          if (listing != null) hydrated['listings'] = listing;
          final rentalCar = carsById[row['rental_car_id']?.toString()];
          if (rentalCar != null) hydrated['rental_cars'] = rentalCar;
          return Booking.fromJson(hydrated);
        })
        .toList(growable: false);
  }

  Future<void> _syncRequestedBusinessRole(User user) async {
    if (_requestedRole(user) != AccountRole.businessOwner) return;
    await _client
        .from('users')
        .update({'role': AccountRole.businessOwner.databaseValue})
        .eq('id', user.id)
        .eq('role', AccountRole.customer.databaseValue);
  }

  static AccountRole _requestedRole(User user) {
    return user.userMetadata?['account_role'] == 'business_owner'
        ? AccountRole.businessOwner
        : AccountRole.customer;
  }

  static String? _nullableText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static BookingActionException _bookingActionException(
    PostgrestException error,
  ) {
    return switch (error.code) {
      '23P01' => const BookingActionException(
        'Those dates are no longer available. Please choose another option.',
      ),
      '42501' => const BookingActionException(
        'You are not allowed to make this booking change.',
      ),
      _ => BookingActionException(error.message),
    };
  }
}
