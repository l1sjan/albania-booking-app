import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:albania_booking_app/main.dart';
import 'package:albania_booking_app/models/account_profile.dart';
import 'package:albania_booking_app/models/booking.dart';
import 'package:albania_booking_app/models/listing.dart';
import 'package:albania_booking_app/models/rental_car.dart';
import 'package:albania_booking_app/screens/business_requests_screen.dart';
import 'package:albania_booking_app/services/booking_repository.dart';
import 'package:albania_booking_app/services/business_repository.dart';
import 'package:albania_booking_app/services/listing_repository.dart';
import 'package:albania_booking_app/services/rental_car_repository.dart';
import 'package:albania_booking_app/theme/app_theme.dart';
import 'package:albania_booking_app/utils/display_formatters.dart';
import 'package:albania_booking_app/utils/auth_redirect.dart';
import 'package:albania_booking_app/widgets/auth_sheet.dart';
import 'package:albania_booking_app/widgets/press_scale.dart';

class _FakeListingRepository implements ListingRepository {
  final requestedFilters = <ListingFilter>[];

  @override
  Future<List<Listing>> fetchListings({
    ListingFilter filter = ListingFilter.all,
  }) async {
    requestedFilters.add(filter);

    if (filter == ListingFilter.transport) {
      return const [
        Listing(
          id: 'listing-3',
          title: 'Tirana Drive',
          description: 'Flexible car rental across Albania.',
          price: 3500,
          location: 'Tirana, Albania',
          category: ListingCategory.carRental,
          currency: 'ALL',
        ),
      ];
    }

    return const [
      Listing(
        id: 'listing-1',
        title: 'Ionian Sea View Loft',
        description: 'A bright coastal loft with a private balcony.',
        price: 120,
        location: 'Sarande, Albania',
        category: ListingCategory.stay,
        currency: 'USD',
      ),
      Listing(
        id: 'listing-2',
        title: 'Berat Barber Studio',
        description: 'Classic cuts and beard care in the old town.',
        price: 1000,
        location: 'Berat, Albania',
        category: ListingCategory.barber,
        currency: 'ALL',
      ),
    ];
  }
}

class _FakeBookingRepository implements BookingRepository {
  final createdRequests = <BookingRequest>[];
  final bookings = <Booking>[];
  final passwordResetEmails = <String>[];
  final updatedPasswords = <String>[];
  bool authenticated = true;
  AccountRole role = AccountRole.customer;
  String fullName = 'Test User';

  @override
  bool get isAuthenticated => authenticated;

  @override
  Stream<void> get passwordRecoveryEvents => const Stream<void>.empty();

  @override
  Future<AuthenticationResult> authenticate({
    required String email,
    required String password,
    required bool createAccount,
    AccountRole accountRole = AccountRole.customer,
    String? displayName,
  }) async {
    authenticated = true;
    role = accountRole;
    if (displayName != null && displayName.isNotEmpty) fullName = displayName;
    return AuthenticationResult.authenticated;
  }

  @override
  Future<AccountProfile?> fetchCurrentAccount() async {
    if (!authenticated) return null;
    return AccountProfile(
      id: 'user-1',
      email: 'owner@example.com',
      fullName: fullName,
      role: role,
    );
  }

  @override
  Future<void> updateAccountProfile({String? fullName, String? phone}) async {
    if (fullName != null) this.fullName = fullName;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    passwordResetEmails.add(email.trim());
  }

  @override
  Future<void> updatePassword(String password) async {
    updatedPasswords.add(password);
  }

  @override
  Future<void> signOut() async {
    authenticated = false;
    role = AccountRole.customer;
  }

  @override
  Future<void> createBooking(BookingRequest request) async {
    createdRequests.add(request);
    bookings.add(
      Booking(
        id: 'booking-${bookings.length}',
        listingId: request.listingId,
        serviceName: request.serviceName,
        startsAt: request.startsAt,
        endsAt: request.endsAt,
        status: BookingStatus.pending,
        priceAmount: request.priceAmount,
        currency: request.currency,
        customerNotes: request.customerNotes,
        rentalCarId: request.rentalCarId,
        listingTitle: request.serviceName,
        listingLocation: 'Sarande, Albania',
      ),
    );
  }

  @override
  Future<List<Booking>> fetchBookings() async {
    return List<Booking>.unmodifiable(bookings);
  }

  @override
  Future<List<Booking>> fetchOwnerBookings() async {
    return List<Booking>.unmodifiable(bookings);
  }

  @override
  Future<void> cancelBooking(String bookingId, {required String reason}) async {
    await updateBookingStatus(
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
    final index = bookings.indexWhere((booking) => booking.id == bookingId);
    if (index == -1) throw StateError('Booking not found.');
    bookings[index] = bookings[index].copyWith(
      status: status,
      cancellationReason: cancellationReason,
    );
  }
}

class _FakeBusinessRepository implements BusinessRepository {
  _FakeBusinessRepository({List<Listing>? initialListings})
    : listings = List<Listing>.of(
        initialListings ??
            [
              const Listing(
                id: 'owner-listing-1',
                title: 'Berat Barber Studio',
                description: 'Classic cuts in the old town.',
                price: 1000,
                location: 'Berat, Albania',
                category: ListingCategory.barber,
                currency: 'ALL',
                city: 'Berat',
              ),
            ],
      );

  final savedDrafts = <BusinessListingDraft>[];
  final List<Listing> listings;
  @override
  Future<List<Listing>> fetchOwnerListings() async {
    return List<Listing>.unmodifiable(listings);
  }

  @override
  Future<void> saveListing(
    BusinessListingDraft draft, {
    String? listingId,
  }) async {
    savedDrafts.add(draft);
    final listing = Listing(
      id: listingId ?? 'owner-listing-${listings.length + 1}',
      title: draft.title,
      description: draft.description,
      price: draft.price,
      location: draft.location,
      category: draft.category,
      currency: draft.currency,
      city: draft.city,
      imageUrl: draft.imageUrl,
      email: draft.email,
      websiteUrl: draft.websiteUrl,
      phone: draft.phone,
      availabilityNote: draft.availabilityNote,
      defaultBookingDurationMinutes: draft.defaultBookingDurationMinutes,
      businessDetails: draft.businessDetails,
    );
    if (listingId == null) {
      listings.add(listing);
      return;
    }
    final index = listings.indexWhere((item) => item.id == listingId);
    if (index != -1) listings[index] = listing;
  }

  @override
  Future<bool> verifyCurrentPassword(String password) async {
    return password == 'owner-password';
  }

  @override
  Future<void> setListingActive(String listingId, bool isActive) async {
    final index = listings.indexWhere((listing) => listing.id == listingId);
    if (index != -1) {
      listings[index] = listings[index].copyWith(isActive: isActive);
    }
  }
}

class _FakeRentalCarRepository implements RentalCarRepository {
  _FakeRentalCarRepository({
    List<RentalCar>? initialCars,
    Map<String, int>? monthlyBookedDays,
    Map<String, List<RentalCarReservation>>? reservationsByCar,
    Map<String, List<RentalCarUnavailability>>? unavailablePeriodsByCar,
    this.fleetMetrics = RentalFleetMetrics.zero,
  }) : cars = List<RentalCar>.of(initialCars ?? const <RentalCar>[]),
       _monthlyBookedDays = Map<String, int>.of(monthlyBookedDays ?? const {}),
       _reservationsByCar = Map<String, List<RentalCarReservation>>.of(
         reservationsByCar ?? const {},
       ),
       _unavailablePeriodsByCar = Map<String, List<RentalCarUnavailability>>.of(
         unavailablePeriodsByCar ?? const {},
       );

  final List<RentalCar> cars;
  final savedDrafts = <RentalCarDraft>[];
  final Map<String, int> _monthlyBookedDays;
  final Map<String, List<RentalCarReservation>> _reservationsByCar;
  final Map<String, List<RentalCarUnavailability>> _unavailablePeriodsByCar;
  final RentalFleetMetrics fleetMetrics;

  @override
  Future<List<RentalCar>> fetchCars(String listingId) async {
    return cars
        .where((car) => car.listingId == listingId)
        .toList(growable: false);
  }

  @override
  Future<List<RentalCar>> fetchAvailableCars(
    String listingId,
    DateTime startsAt,
    DateTime endsAt,
  ) async {
    return cars
        .where((car) => car.listingId == listingId && car.isAvailable)
        .toList(growable: false);
  }

  @override
  Future<Map<String, int>> fetchBookedDaysForMonth(
    String listingId,
    DateTime month,
  ) async {
    return Map<String, int>.unmodifiable(_monthlyBookedDays);
  }

  @override
  Future<RentalFleetMetrics> fetchFleetMetrics(
    String listingId,
    DateTime referenceDate,
  ) async {
    return fleetMetrics;
  }

  @override
  Future<List<RentalCarReservation>> fetchConfirmedReservations(
    String carId,
    DateTime month,
  ) async {
    return List<RentalCarReservation>.unmodifiable(
      _reservationsByCar[carId] ?? const [],
    );
  }

  @override
  Future<List<RentalCarUnavailability>> fetchUnavailablePeriods(
    String carId,
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    return List<RentalCarUnavailability>.unmodifiable(
      (_unavailablePeriodsByCar[carId] ?? const []).where(
        (period) =>
            period.startsOn.isBefore(monthEnd) &&
            !period.endsOn.isBefore(monthStart),
      ),
    );
  }

  @override
  Future<void> createUnavailablePeriod(
    String carId,
    DateTime startsOn,
    DateTime endsOn, {
    String? reason,
  }) async {
    final periods = _unavailablePeriodsByCar.putIfAbsent(carId, () => []);
    periods.add(
      RentalCarUnavailability(
        id: 'period-${periods.length + 1}',
        rentalCarId: carId,
        startsOn: startsOn,
        endsOn: endsOn,
        reason: reason,
      ),
    );
  }

  @override
  Future<void> deleteUnavailablePeriod(String periodId) async {
    for (final periods in _unavailablePeriodsByCar.values) {
      periods.removeWhere((period) => period.id == periodId);
    }
  }

  @override
  Future<void> saveCar(RentalCarDraft draft, {String? carId}) async {
    savedDrafts.add(draft);
    final car = RentalCar(
      id: carId ?? 'car-${cars.length + 1}',
      listingId: draft.listingId,
      model: draft.model,
      engine: draft.engine,
      pricePerDay: draft.pricePerDay,
      currency: draft.currency,
      transmission: draft.transmission,
      productionYear: draft.productionYear,
      seatCount: draft.seatCount,
      imageUrl: draft.imageUrl,
      isAvailable: draft.isAvailable,
    );
    if (carId == null) {
      cars.add(car);
      return;
    }
    final index = cars.indexWhere((item) => item.id == carId);
    if (index != -1) cars[index] = car;
  }

  @override
  Future<void> setCarAvailable(String carId, bool isAvailable) async {
    final index = cars.indexWhere((car) => car.id == carId);
    if (index != -1) {
      cars[index] = cars[index].copyWith(isAvailable: isAvailable);
    }
  }

  @override
  Future<void> deleteCar(String carId) async {
    cars.removeWhere((car) => car.id == carId);
  }
}

Finder _navigationDestination(String label) {
  return find.byWidgetPredicate((widget) {
    return widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.selected != null &&
        widget.properties.label == label;
  });
}

void main() {
  test('maps a legacy listing row into the property feed contract', () {
    final listing = Listing.fromJson({
      'id': 'legacy-1',
      'name': 'Old Town Stay',
      'description': 'A restored apartment near the bazaar.',
      'price_from': 84,
      'city': 'Gjirokaster',
      'country': 'Albania',
      'image_urls': ['https://example.com/stay.jpg'],
    });

    expect(listing.title, 'Old Town Stay');
    expect(listing.price, 84);
    expect(listing.location, 'Gjirokaster, Albania');
    expect(listing.imageUrl, 'https://example.com/stay.jpg');
    expect(listing.category, ListingCategory.stay);
    expect(listing.currency, 'USD');
  });

  test('maps legacy listing details embedded into a booking', () {
    final booking = Booking.fromJson({
      'id': 'booking-1',
      'listing_id': 'listing-1',
      'service_name': 'Tirana Drive',
      'starts_at': '2026-07-20T09:00:00Z',
      'ends_at': '2026-07-22T18:00:00Z',
      'status': 'pending',
      'price_amount': 7000,
      'currency': 'ALL',
      'listings': {
        'name': 'Tirana Drive',
        'city': 'Tirana',
        'country': 'Albania',
        'image_urls': ['https://example.com/car.jpg'],
      },
    });

    expect(booking.listingTitle, 'Tirana Drive');
    expect(booking.listingLocation, 'Tirana, Albania');
    expect(booking.listingImageUrl, 'https://example.com/car.jpg');
  });

  test('identifies Supabase password recovery callback URLs', () {
    expect(
      isPasswordRecoveryCallback(
        Uri.parse('http://localhost:60482/#access_token=token&type=recovery'),
      ),
      isTrue,
    );
    expect(
      isPasswordRecoveryCallback(
        Uri.parse('https://app.example.com/?type=recovery'),
      ),
      isTrue,
    );
    expect(
      isPasswordRecoveryCallback(
        Uri.parse('http://localhost:60482/#access_token=token&type=signup'),
      ),
      isFalse,
    );
  });

  testWidgets('sends a password reset link from the authentication sheet', (
    tester,
  ) async {
    final bookingRepository = _FakeBookingRepository()..authenticated = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  await showAuthenticationSheet(context, bookingRepository);
                },
                child: const Text('Open sign in'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'customer@example.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(bookingRepository.passwordResetEmails, ['customer@example.com']);
    expect(find.text('Reset link sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates a password from the recovery sheet', (tester) async {
    final bookingRepository = _FakeBookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  await showPasswordUpdateSheet(context, bookingRepository);
                },
                child: const Text('Open password update'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open password update'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'new-pass-123');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-pass-123');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(bookingRepository.updatedPasswords, ['new-pass-123']);
    expect(find.text('Password updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows navigation and dynamically filters listings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeListingRepository();
    final bookingRepository = _FakeBookingRepository();
    await tester.pumpWidget(
      AlbaniaBookingApp(
        listingRepository: repository,
        bookingRepository: bookingRepository,
        businessRepository: _FakeBusinessRepository(),
        rentalCarRepository: _FakeRentalCarRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find your next adventure'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(_navigationDestination('Explore'), findsOneWidget);
    expect(_navigationDestination('Saved'), findsOneWidget);
    expect(_navigationDestination('Bookings'), findsOneWidget);
    expect(_navigationDestination('Profile'), findsOneWidget);
    expect(find.text('Ionian Sea View Loft'), findsOneWidget);
    expect(find.text(r'$120 / night'), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Berat Barber Studio'), findsOneWidget);
    expect(find.text('Barber'), findsOneWidget);
    expect(find.text('1,000 Lek / service'), findsOneWidget);
    expect(find.byType(PressScale), findsAtLeastNWidgets(7));
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == 'listing_image_listing-1',
      ),
      findsOneWidget,
    );

    final allPressScale = tester.widget<PressScale>(
      find.ancestor(of: find.text('All'), matching: find.byType(PressScale)),
    );
    expect(allPressScale.pressedScale, 0.93);
    expect(allPressScale.onTap, isNotNull);

    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();

    expect(repository.requestedFilters.last, ListingFilter.transport);
    expect(find.text('Tirana Drive'), findsOneWidget);
    expect(find.text('Car Rental'), findsOneWidget);
    expect(find.text('3,500 Lek / day'), findsOneWidget);

    await tester.tap(_navigationDestination('Saved'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your favorite services and stays will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('renders the Mediterranean shell at a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeListingRepository();
    final bookingRepository = _FakeBookingRepository();
    await tester.pumpWidget(
      AlbaniaBookingApp(
        listingRepository: repository,
        bookingRepository: bookingRepository,
        businessRepository: _FakeBusinessRepository(),
        rentalCarRepository: _FakeRentalCarRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find your next adventure'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Ionian Sea View Loft'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final cardPressScale = tester.widget<PressScale>(
      find.ancestor(
        of: find.text('Ionian Sea View Loft'),
        matching: find.byType(PressScale),
      ),
    );
    expect(cardPressScale.pressedScale, 0.96);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('All')),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();

    expect(repository.requestedFilters.last, ListingFilter.transport);
    expect(find.text('Tirana Drive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a booking from the listing detail flow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final listingRepository = _FakeListingRepository();
    final bookingRepository = _FakeBookingRepository();
    await tester.pumpWidget(
      AlbaniaBookingApp(
        listingRepository: listingRepository,
        bookingRepository: bookingRepository,
        businessRepository: _FakeBusinessRepository(),
        rentalCarRepository: _FakeRentalCarRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ionian Sea View Loft'));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Booking details'), findsOneWidget);
    expect(find.text('2 guests'), findsOneWidget);
    expect(find.text('Confirm booking'), findsOneWidget);

    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();

    expect(bookingRepository.createdRequests, hasLength(1));
    expect(bookingRepository.createdRequests.single.priceAmount, 240);
    expect(find.text('Booking requested'), findsOneWidget);

    await tester.tap(find.text('View bookings'));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Ionian Sea View Loft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customers book an available car for a selected rental period', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bookingRepository = _FakeBookingRepository();
    final rentalCarRepository = _FakeRentalCarRepository(
      initialCars: const [
        RentalCar(
          id: 'public-car-1',
          listingId: 'listing-3',
          model: 'Skoda Kodiaq',
          engine: '2.0 TDI',
          pricePerDay: 4800,
          currency: 'ALL',
          transmission: CarTransmission.automatic,
          productionYear: 2023,
          seatCount: 5,
        ),
      ],
    );

    await tester.pumpWidget(
      AlbaniaBookingApp(
        listingRepository: _FakeListingRepository(),
        bookingRepository: bookingRepository,
        businessRepository: _FakeBusinessRepository(),
        rentalCarRepository: rentalCarRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirana Drive'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your car'), findsOneWidget);
    expect(find.text('Skoda Kodiaq'), findsOneWidget);
    expect(find.text('Available for these dates'), findsOneWidget);

    await tester.tap(find.text('Skoda Kodiaq'));
    await tester.pumpAndSettle();
    expect(find.text('Car details'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
    expect(find.text('Seats'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Book this car'), 160);
    await tester.tap(find.text('Book this car'));
    await tester.pumpAndSettle();
    expect(find.text('Reserve Skoda Kodiaq'), findsOneWidget);
    expect(find.textContaining('9,600 Lek'), findsWidgets);

    final pickupField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Pickup location',
    );
    await tester.enterText(pickupField, 'Tirana International Airport');
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();

    expect(bookingRepository.createdRequests, hasLength(1));
    expect(
      bookingRepository.createdRequests.single.rentalCarId,
      'public-car-1',
    );
    expect(bookingRepository.createdRequests.single.priceAmount, 9600);
    expect(find.text('Booking requested'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancels customer bookings and confirms owner requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final listingRepository = _FakeListingRepository();
    final bookingRepository = _FakeBookingRepository()
      ..bookings.addAll([
        Booking(
          id: 'customer-booking',
          listingId: 'listing-1',
          serviceName: 'Customer reservation',
          startsAt: DateTime(2026, 7, 20, 11),
          endsAt: DateTime(2026, 7, 20, 12),
          status: BookingStatus.pending,
          priceAmount: 1000,
          currency: 'ALL',
          listingTitle: 'Customer reservation',
          listingLocation: 'Tirana, Albania',
        ),
        Booking(
          id: 'owner-booking',
          listingId: 'listing-2',
          serviceName: 'Owner request',
          startsAt: DateTime(2026, 7, 21, 11),
          endsAt: DateTime(2026, 7, 21, 12),
          status: BookingStatus.pending,
          priceAmount: 1200,
          currency: 'ALL',
          listingTitle: 'Owner request',
          listingLocation: 'Berat, Albania',
        ),
      ]);

    await tester.pumpWidget(
      AlbaniaBookingApp(
        listingRepository: listingRepository,
        bookingRepository: bookingRepository,
        businessRepository: _FakeBusinessRepository(),
        rentalCarRepository: _FakeRentalCarRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_navigationDestination('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer reservation'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel booking'), findsOneWidget);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this booking?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Change of plans');
    await tester.tap(find.text('Cancel reservation'));
    await tester.pumpAndSettle();

    expect(bookingRepository.bookings.first.status, BookingStatus.canceled);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BusinessRequestsScreen(repository: bookingRepository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owner request'), findsOneWidget);
    await tester.tap(find.text('Owner request'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm request'), findsOneWidget);
    await tester.tap(find.text('Confirm request'));
    await tester.pumpAndSettle();

    expect(bookingRepository.bookings.last.status, BookingStatus.confirmed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('business accounts receive the dedicated owner workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bookingRepository = _FakeBookingRepository()
      ..role = AccountRole.businessOwner
      ..fullName = 'Arben Kola';

    await tester.pumpWidget(
      AlbaniaBookingApp(
        listingRepository: _FakeListingRepository(),
        bookingRepository: bookingRepository,
        businessRepository: _FakeBusinessRepository(),
        rentalCarRepository: _FakeRentalCarRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Berat Barber Studio'), findsOneWidget);
    expect(_navigationDestination('Preview'), findsOneWidget);
    expect(_navigationDestination('Requests'), findsOneWidget);
    expect(_navigationDestination('Business'), findsOneWidget);
    expect(_navigationDestination('Account'), findsOneWidget);
    expect(_navigationDestination('Explore'), findsNothing);

    expect(find.text('Your business'), findsOneWidget);
    expect(find.text('Berat Barber Studio'), findsOneWidget);
    expect(find.byTooltip('Add listing'), findsNothing);

    await tester.tap(_navigationDestination('Preview'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This is your public customer view. Booking controls are hidden here.',
      ),
      findsOneWidget,
    );

    await tester.tap(_navigationDestination('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Business account'), findsOneWidget);
    expect(find.text('Arben Kola'), findsOneWidget);
    expect(find.text('Manage listings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('car rental owners manage vehicles inside their single business', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bookingRepository = _FakeBookingRepository()
      ..role = AccountRole.businessOwner;
    final businessRepository = _FakeBusinessRepository(
      initialListings: const [
        Listing(
          id: 'rental-business-1',
          title: 'Tirana Drive',
          description: 'Reliable rentals around Albania.',
          price: 3500,
          location: 'Tirana, Albania',
          category: ListingCategory.carRental,
          currency: 'ALL',
          city: 'Tirana',
        ),
      ],
    );
    final rentalCarRepository = _FakeRentalCarRepository(
      initialCars: const [
        RentalCar(
          id: 'car-1',
          listingId: 'rental-business-1',
          model: 'Volkswagen Golf 8',
          engine: '2.0 TDI',
          pricePerDay: 4500,
          currency: 'ALL',
          transmission: CarTransmission.automatic,
          productionYear: 2022,
          seatCount: 5,
        ),
      ],
      monthlyBookedDays: const {'car-1': 22},
      fleetMetrics: const RentalFleetMetrics(
        revenueThisMonth: 12500,
        bookedCarsToday: 1,
        unavailableCarsToday: 1,
      ),
      reservationsByCar: {
        'car-1': [
          RentalCarReservation(
            startsAt: DateTime(DateTime.now().year, DateTime.now().month, 8),
            endsAt: DateTime(DateTime.now().year, DateTime.now().month, 11),
          ),
        ],
      },
      unavailablePeriodsByCar: {
        'car-1': [
          RentalCarUnavailability(
            id: 'unavailable-1',
            rentalCarId: 'car-1',
            startsOn: DateTime(DateTime.now().year, DateTime.now().month, 20),
            endsOn: DateTime(DateTime.now().year, DateTime.now().month, 20),
            reason: 'Scheduled maintenance',
          ),
        ],
      },
    );

    await tester.pumpWidget(
      AlbaniaBookingApp(
        listingRepository: _FakeListingRepository(),
        bookingRepository: bookingRepository,
        businessRepository: businessRepository,
        rentalCarRepository: rentalCarRepository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_navigationDestination('Business'));
    await tester.pumpAndSettle();

    expect(find.text('Your fleet'), findsOneWidget);
    expect(find.text('Volkswagen Golf 8'), findsOneWidget);
    expect(find.text('2022'), findsOneWidget);
    expect(find.text('Revenue this month'), findsOneWidget);
    expect(find.text('12,500 Lek'), findsOneWidget);
    expect(find.text('Booked cars today'), findsOneWidget);
    expect(find.text('Unavailable cars'), findsOneWidget);
    expect(find.text('22 booked days this month'), findsOneWidget);
    expect(find.text('Create business'), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);

    await tester.tap(find.text('Add car'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Make and model'),
      'Toyota Corolla',
    );
    await tester.tap(find.text('Engine size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.8L').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Production year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price per day'),
      '5200',
    );
    await tester.ensureVisible(find.text('Save car'));
    await tester.tap(find.text('Save car'));
    await tester.pumpAndSettle();

    expect(rentalCarRepository.savedDrafts, hasLength(1));
    expect(rentalCarRepository.savedDrafts.single.model, 'Toyota Corolla');
    expect(rentalCarRepository.savedDrafts.single.engine, '1.8L');
    expect(rentalCarRepository.savedDrafts.single.seatCount, 5);
    expect(rentalCarRepository.cars, hasLength(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Volkswagen Golf 8'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Booking calendar'), findsOneWidget);
    expect(find.text('Block dates'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Booked on ${formatDate(DateTime(DateTime.now().year, DateTime.now().month, 8))}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Unavailable on ${formatDate(DateTime(DateTime.now().year, DateTime.now().month, 20))}',
      ),
      findsOneWidget,
    );
    final detailPageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Edit car'),
      160,
      scrollable: detailPageScroll,
    );
    await tester.tap(find.text('Edit car'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Make and model'),
      'Volkswagen Arteon',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Save car changes?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save changes'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Arteon'), findsWidgets);
    expect(
      rentalCarRepository.cars.singleWhere((car) => car.id == 'car-1').model,
      'Volkswagen Arteon',
    );
    await tester.scrollUntilVisible(
      find.text('Car details'),
      160,
      scrollable: detailPageScroll,
    );
    expect(find.text('Car details'), findsOneWidget);
    expect(find.text('Seats'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Scheduled maintenance'),
      160,
      scrollable: detailPageScroll,
    );
    expect(find.text('Scheduled maintenance'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Block dates'));
    await tester.tap(find.text('Block dates'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Select unavailable dates'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Confirm unavailable dates'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason (optional)'),
      'Cleaning and inspection',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Block dates'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Confirm unavailable dates'), findsNothing);
    final savedPeriods = await rentalCarRepository.fetchUnavailablePeriods(
      'car-1',
      DateTime.now(),
    );
    expect(
      savedPeriods.any((period) => period.reason == 'Cleaning and inspection'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'changing business type requires confirmation and the owner password',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bookingRepository = _FakeBookingRepository()
        ..role = AccountRole.businessOwner;
      final businessRepository = _FakeBusinessRepository();

      await tester.pumpWidget(
        AlbaniaBookingApp(
          listingRepository: _FakeListingRepository(),
          bookingRepository: bookingRepository,
          businessRepository: businessRepository,
          rentalCarRepository: _FakeRentalCarRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_navigationDestination('Business'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit business'));
      await tester.pumpAndSettle();

      final categoryField = find.byType(
        DropdownButtonFormField<ListingCategory>,
      );
      await tester.ensureVisible(categoryField);
      await tester.tap(categoryField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Car Rental').last);
      await tester.pumpAndSettle();

      expect(find.text('Change business type?'), findsOneWidget);
      await tester.tap(find.text('Continue securely'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm your password'), findsOneWidget);

      final passwordField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Current password',
      );
      await tester.enterText(passwordField, 'wrong-password');
      await tester.tap(find.text('Verify and continue'));
      await tester.pumpAndSettle();
      expect(find.text('That password is not correct.'), findsOneWidget);

      await tester.enterText(passwordField, 'owner-password');
      await tester.tap(find.text('Verify and continue'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The previous category setup has been cleared. Save the business '
          'profile to open the new workspace.',
        ),
        findsOneWidget,
      );
      expect(find.text('Base price'), findsNothing);
      expect(find.text('Description'), findsNothing);

      await tester.ensureVisible(find.text('Save business profile'));
      await tester.tap(find.text('Save business profile'));
      await tester.pumpAndSettle();

      expect(
        businessRepository.savedDrafts.last.category,
        ListingCategory.carRental,
      );
      expect(find.text('Your fleet'), findsOneWidget);
      expect(find.text('Berat Barber Studio'), findsOneWidget);
      expect(find.text('Add car'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('onboards an owner by publishing their first listing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bookingRepository = _FakeBookingRepository()
      ..role = AccountRole.businessOwner;
    final businessRepository = _FakeBusinessRepository(
      initialListings: <Listing>[],
    );

    await tester.pumpWidget(
      AlbaniaBookingApp(
        listingRepository: _FakeListingRepository(),
        bookingRepository: bookingRepository,
        businessRepository: businessRepository,
        rentalCarRepository: _FakeRentalCarRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_navigationDestination('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Set up business'), findsOneWidget);
    await tester.tap(find.text('Set up business'));
    await tester.pumpAndSettle();
    expect(find.text('Make your business bookable'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Business name',
    );
    final cityField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'City',
    );
    expect(titleField, findsOneWidget);
    expect(cityField, findsOneWidget);
    await tester.enterText(titleField, 'Korca Coffee House');
    await tester.enterText(cityField, 'Korca');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to publish'), findsOneWidget);
    final descriptionField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Description',
    );
    final priceField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Base price',
    );
    await tester.enterText(descriptionField, 'Coffee and homemade desserts.');
    await tester.enterText(priceField, '450');
    expect(find.text('Image URL'), findsNothing);
    expect(find.text('Choose from gallery'), findsOneWidget);
    await tester.ensureVisible(find.text('Publish business'));
    await tester.tap(find.text('Publish business'));
    await tester.pumpAndSettle();

    expect(businessRepository.savedDrafts, hasLength(1));
    expect(businessRepository.savedDrafts.single.title, 'Korca Coffee House');
    expect(businessRepository.savedDrafts.single.imageUrl, isNull);
    expect(businessRepository.savedDrafts.single.imageBytes, isNull);
    await tester.tap(_navigationDestination('Business'));
    await tester.pumpAndSettle();
    expect(find.text('Korca Coffee House'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
