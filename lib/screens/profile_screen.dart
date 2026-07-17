import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/booking_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.onAccountChanged,
  });

  final BookingRepository repository;
  final VoidCallback onAccountChanged;

  Future<void> _signIn(BuildContext context) async {
    final authenticated = await showAuthenticationSheet(context, repository);
    if (authenticated) onAccountChanged();
  }

  Future<void> _signOut() async {
    await repository.signOut();
    onAccountChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.profileTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppPalette.warmField,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 25,
                          backgroundColor: AppPalette.forest,
                          child: Icon(
                            Icons.person_outline,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            repository.isAuthenticated
                                ? AppStrings.profileMessage
                                : AppStrings.signInRequiredMessage,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppPalette.slate),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!repository.isAuthenticated)
                  FilledButton.icon(
                    onPressed: () => _signIn(context),
                    icon: const Icon(Icons.login),
                    label: const Text(AppStrings.signIn),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text(AppStrings.signOut),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
