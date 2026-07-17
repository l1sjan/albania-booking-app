import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_strings.dart';
import 'screens/navigation_hub.dart';
import 'services/booking_repository.dart';
import 'services/business_repository.dart';
import 'services/listing_repository.dart';
import 'services/notification_repository.dart';
import 'services/rental_car_repository.dart';
import 'theme/app_theme.dart';
import 'utils/auth_redirect.dart';

late final SupabaseClient supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Read this before Supabase consumes the browser URL fragment.
  final isPasswordRecovery = isPasswordRecoveryCallback(Uri.base);

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  supabase = Supabase.instance.client;

  runApp(
    AlbaniaBookingApp(
      notificationRepository: SupabaseNotificationRepository(supabase),
      openPasswordRecoveryOnStart:
          isPasswordRecovery && supabase.auth.currentSession != null,
    ),
  );
}

class AlbaniaBookingApp extends StatelessWidget {
  const AlbaniaBookingApp({
    super.key,
    this.listingRepository,
    this.bookingRepository,
    this.businessRepository,
    this.rentalCarRepository,
    this.notificationRepository,
    this.openPasswordRecoveryOnStart = false,
  });

  final ListingRepository? listingRepository;
  final BookingRepository? bookingRepository;
  final BusinessRepository? businessRepository;
  final RentalCarRepository? rentalCarRepository;
  final NotificationRepository? notificationRepository;
  final bool openPasswordRecoveryOnStart;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: NavigationHub(
        repository: listingRepository ?? SupabaseListingRepository(supabase),
        bookingRepository:
            bookingRepository ?? SupabaseBookingRepository(supabase),
        businessRepository:
            businessRepository ?? SupabaseBusinessRepository(supabase),
        rentalCarRepository:
            rentalCarRepository ?? SupabaseRentalCarRepository(supabase),
        notificationRepository: notificationRepository,
        openPasswordRecoveryOnStart: openPasswordRecoveryOnStart,
      ),
    );
  }
}
