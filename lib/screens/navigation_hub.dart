import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/account_profile.dart';
import '../services/booking_repository.dart';
import '../services/business_repository.dart';
import '../services/listing_repository.dart';
import '../services/notification_repository.dart';
import '../services/rental_car_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/press_scale.dart';
import 'bookings_screen.dart';
import 'business_dashboard_screen.dart';
import 'business_listings_screen.dart';
import 'business_onboarding_sheet.dart';
import 'business_profile_screen.dart';
import 'business_requests_screen.dart';
import 'explore_screen.dart';
import 'placeholder_tab.dart';
import 'profile_screen.dart';

class NavigationHub extends StatefulWidget {
  const NavigationHub({
    super.key,
    required this.repository,
    required this.bookingRepository,
    required this.businessRepository,
    required this.rentalCarRepository,
    this.notificationRepository,
    this.openPasswordRecoveryOnStart = false,
  });

  final ListingRepository repository;
  final BookingRepository bookingRepository;
  final BusinessRepository businessRepository;
  final RentalCarRepository rentalCarRepository;
  final NotificationRepository? notificationRepository;
  final bool openPasswordRecoveryOnStart;

  @override
  State<NavigationHub> createState() => _NavigationHubState();
}

class _NavigationHubState extends State<NavigationHub> {
  late Future<AccountProfile?> _accountFuture;
  StreamSubscription<void>? _passwordRecoverySubscription;
  bool _isPasswordRecoveryOpen = false;

  @override
  void initState() {
    super.initState();
    _accountFuture = widget.bookingRepository.fetchCurrentAccount();
    _passwordRecoverySubscription = widget
        .bookingRepository
        .passwordRecoveryEvents
        .listen((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openPasswordRecovery();
          });
        });
    if (widget.openPasswordRecoveryOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPasswordRecovery();
      });
    }
  }

  Future<void> _openPasswordRecovery() async {
    if (!mounted || _isPasswordRecoveryOpen) return;
    _isPasswordRecoveryOpen = true;
    await showPasswordUpdateSheet(context, widget.bookingRepository);
    _isPasswordRecoveryOpen = false;
    if (mounted) _refreshAccount();
  }

  void _refreshAccount() {
    if (!mounted) return;
    setState(() {
      _accountFuture = widget.bookingRepository.fetchCurrentAccount();
    });
  }

  @override
  void dispose() {
    _passwordRecoverySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountProfile?>(
      future: _accountFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppPalette.alabaster,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppPalette.alabaster,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.manage_accounts_outlined,
                      size: 46,
                      color: AppPalette.forest,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _refreshAccount,
                      child: const Text(AppStrings.tryAgain),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data;
        return _RoleNavigationShell(
          key: ValueKey(profile?.role ?? AccountRole.customer),
          profile: profile,
          listingRepository: widget.repository,
          bookingRepository: widget.bookingRepository,
          businessRepository: widget.businessRepository,
          rentalCarRepository: widget.rentalCarRepository,
          notificationRepository: widget.notificationRepository,
          onAccountChanged: _refreshAccount,
        );
      },
    );
  }
}

class _RoleNavigationShell extends StatefulWidget {
  const _RoleNavigationShell({
    super.key,
    required this.profile,
    required this.listingRepository,
    required this.bookingRepository,
    required this.businessRepository,
    required this.rentalCarRepository,
    this.notificationRepository,
    required this.onAccountChanged,
  });

  final AccountProfile? profile;
  final ListingRepository listingRepository;
  final BookingRepository bookingRepository;
  final BusinessRepository businessRepository;
  final RentalCarRepository rentalCarRepository;
  final NotificationRepository? notificationRepository;
  final VoidCallback onAccountChanged;

  @override
  State<_RoleNavigationShell> createState() => _RoleNavigationShellState();
}

class _RoleNavigationShellState extends State<_RoleNavigationShell> {
  late final PageController _pageController;
  late final List<Widget> _pages;
  late final List<_NavigationDestinationData> _destinations;
  final _bookingsKey = GlobalKey<BookingsScreenState>();
  final _businessDashboardKey = GlobalKey<BusinessDashboardScreenState>();
  final _businessListingsKey = GlobalKey<BusinessListingsScreenState>();
  int _selectedIndex = 0;

  bool get _ownerMode => widget.profile?.isBusinessOwner ?? false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (_ownerMode) {
      _destinations = const [
        _NavigationDestinationData(
          Icons.store_mall_directory_outlined,
          Icons.store_mall_directory,
          AppStrings.ownerListings,
        ),
        _NavigationDestinationData(
          Icons.inbox_outlined,
          Icons.inbox,
          AppStrings.ownerRequests,
        ),
        _NavigationDestinationData(
          Icons.space_dashboard_outlined,
          Icons.space_dashboard,
          AppStrings.ownerOverview,
        ),
        _NavigationDestinationData(
          Icons.business_center_outlined,
          Icons.business_center,
          AppStrings.ownerBusiness,
        ),
      ];
      _pages = [
        BusinessListingsScreen(
          key: _businessListingsKey,
          repository: widget.businessRepository,
          rentalCarRepository: widget.rentalCarRepository,
        ),
        BusinessRequestsScreen(
          repository: widget.bookingRepository,
          notificationRepository: widget.notificationRepository,
          embedded: true,
        ),
        BusinessDashboardScreen(
          key: _businessDashboardKey,
          businessRepository: widget.businessRepository,
          bookingRepository: widget.bookingRepository,
          onAddListing: _openCreateListing,
          onReviewRequests: () => _selectPage(1),
          onStartOnboarding: _openBusinessOnboarding,
        ),
        BusinessProfileScreen(
          profile: widget.profile!,
          repository: widget.bookingRepository,
          onAccountChanged: widget.onAccountChanged,
          onManageListings: () => _selectPage(0),
          onManageRequests: () => _selectPage(1),
        ),
      ];
    } else {
      _destinations = const [
        _NavigationDestinationData(
          Icons.explore_outlined,
          Icons.explore,
          AppStrings.navExplore,
        ),
        _NavigationDestinationData(
          Icons.favorite_outline,
          Icons.favorite,
          AppStrings.navSaved,
        ),
        _NavigationDestinationData(
          Icons.calendar_month_outlined,
          Icons.calendar_month,
          AppStrings.navBookings,
        ),
        _NavigationDestinationData(
          Icons.person_outline,
          Icons.person,
          AppStrings.navProfile,
        ),
      ];
      _pages = [
        ExploreScreen(
          repository: widget.listingRepository,
          bookingRepository: widget.bookingRepository,
          rentalCarRepository: widget.rentalCarRepository,
          onProfilePressed: () => _selectPage(3),
          onViewBookings: () => _selectPage(2),
          onAccountChanged: widget.onAccountChanged,
        ),
        const PlaceholderTab(
          icon: Icons.favorite_outline,
          title: AppStrings.savedTitle,
          message: AppStrings.savedMessage,
        ),
        BookingsScreen(
          key: _bookingsKey,
          repository: widget.bookingRepository,
          notificationRepository: widget.notificationRepository,
          onAccountChanged: widget.onAccountChanged,
        ),
        ProfileScreen(
          repository: widget.bookingRepository,
          onAccountChanged: widget.onAccountChanged,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openCreateListing() {
    _selectPage(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _businessListingsKey.currentState?.openCreateListing();
    });
  }

  Future<void> _openBusinessOnboarding() async {
    final completed = await showBusinessOnboardingSheet(
      context,
      widget.businessRepository,
    );
    if (!completed || !mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(AppStrings.onboardingComplete),
          backgroundColor: AppPalette.forest,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(20, 0, 20, 96),
        ),
      );
    await _businessDashboardKey.currentState?.refresh();
    await _businessListingsKey.currentState?.refresh();
  }

  void _selectPage(int index) {
    if (_ownerMode && index == 0) {
      _businessListingsKey.currentState?.refresh();
    } else if (!_ownerMode && index == 2) {
      _bookingsKey.currentState?.refresh();
    }
    if (index == _selectedIndex) return;

    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppPalette.alabaster,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (index != _selectedIndex) {
                  setState(() => _selectedIndex = index);
                }
              },
              children: _pages,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _FloatingNavigationIsland(
                    destinations: _destinations,
                    selectedIndex: _selectedIndex,
                    onSelected: _selectPage,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavigationIsland extends StatelessWidget {
  const _FloatingNavigationIsland({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavigationDestinationData> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F5C677D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 0.6,
              ),
            ),
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      child: _NavigationItem(
                        icon: destinations[index].icon,
                        selectedIcon: destinations[index].selectedIcon,
                        label: destinations[index].label,
                        selected: index == selectedIndex,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? AppPalette.smartBlue : AppPalette.blueSlate;
    final labelColor = selected ? AppPalette.primaryText : AppPalette.blueSlate;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                height: 32,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.96, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: selected
                      ? Padding(
                          key: ValueKey('selected_$label'),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(selectedIcon, color: iconColor, size: 22),
                                const SizedBox(width: 6),
                                Text(
                                  label,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: labelColor,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          key: ValueKey('unselected_$label'),
                          color: iconColor,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 5 : 0,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppPalette.forest,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationDestinationData {
  const _NavigationDestinationData(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
