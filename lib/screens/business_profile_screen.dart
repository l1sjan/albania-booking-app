import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/account_profile.dart';
import '../services/booking_repository.dart';
import '../theme/app_theme.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({
    super.key,
    required this.profile,
    required this.repository,
    required this.onAccountChanged,
    required this.onManageListings,
    required this.onManageRequests,
  });

  final AccountProfile profile;
  final BookingRepository repository;
  final VoidCallback onAccountChanged;
  final VoidCallback onManageListings;
  final VoidCallback onManageRequests;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  Future<void> _editAccount() async {
    final result = await showModalBottomSheet<({String name, String phone})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _AccountEditor(profile: widget.profile),
    );
    if (result == null || !mounted) return;

    try {
      await widget.repository.updateAccountProfile(
        fullName: result.name,
        phone: result.phone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.accountSaved),
          backgroundColor: AppPalette.forest,
        ),
      );
      widget.onAccountChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.signOutTitle),
        content: const Text(AppStrings.signOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.signOut();
    widget.onAccountChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.businessProfileTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.businessProfileMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.slate,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppPalette.warmOutline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 27,
                            backgroundColor: AppPalette.outline,
                            child: Icon(
                              Icons.storefront_outlined,
                              color: AppPalette.forest,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profile.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.profile.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _editAccount,
                            tooltip: AppStrings.editAccount,
                            color: Colors.white,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _BusinessOption(
                    icon: Icons.store_mall_directory_outlined,
                    title: AppStrings.manageListings,
                    message: AppStrings.manageListingsMessage,
                    onTap: widget.onManageListings,
                  ),
                  const SizedBox(height: 12),
                  _BusinessOption(
                    icon: Icons.event_note_outlined,
                    title: AppStrings.manageRequests,
                    message: AppStrings.manageRequestsMessage,
                    onTap: widget.onManageRequests,
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text(AppStrings.signOut),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessOption extends StatelessWidget {
  const _BusinessOption({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.warmSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppPalette.warmField,
                child: Icon(icon, color: AppPalette.forest),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppPalette.slate),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({required this.profile});

  final AccountProfile profile;

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.accountDetails,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: AppStrings.close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: AppStrings.ownerName,
                  filled: true,
                  fillColor: AppPalette.warmField,
                ),
                validator: (value) => (value?.trim().length ?? 0) >= 2
                    ? null
                    : AppStrings.invalidName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: AppStrings.phoneLabel,
                  filled: true,
                  fillColor: AppPalette.warmField,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(context, (
                    name: _name.text.trim(),
                    phone: _phone.text.trim(),
                  ));
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text(AppStrings.saveAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
