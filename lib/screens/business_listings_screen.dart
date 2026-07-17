import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
import '../services/business_repository.dart';
import '../services/rental_car_repository.dart';
import '../theme/app_theme.dart';
import '../utils/display_formatters.dart';
import '../widgets/business_photo_picker.dart';
import '../widgets/business_category_details.dart';
import '../widgets/listing_image.dart';
import 'car_rental_business_screen.dart';

class BusinessListingsScreen extends StatefulWidget {
  const BusinessListingsScreen({
    super.key,
    required this.repository,
    required this.rentalCarRepository,
  });

  final BusinessRepository repository;
  final RentalCarRepository rentalCarRepository;

  @override
  State<BusinessListingsScreen> createState() => BusinessListingsScreenState();
}

class BusinessListingsScreenState extends State<BusinessListingsScreen> {
  late Future<List<Listing>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _listingsFuture = widget.repository.fetchOwnerListings();
  }

  Future<void> refresh() async {
    final request = widget.repository.fetchOwnerListings();
    setState(() {
      _listingsFuture = request;
    });
    await request;
  }

  Future<void> openCreateListing() async {
    final listings = await widget.repository.fetchOwnerListings();
    if (!mounted) return;
    await _openEditor(listings.isEmpty ? null : listings.first);
  }

  Future<void> _openEditor([Listing? listing]) async {
    final draft = await showModalBottomSheet<BusinessListingDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ListingEditor(
        listing: listing,
        verifyPassword: widget.repository.verifyCurrentPassword,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      await widget.repository.saveListing(draft, listingId: listing?.id);
      if (!mounted) return;
      _showMessage(AppStrings.listingSaved);
      await refresh();
    } catch (error) {
      if (mounted) {
        _showMessage('${AppStrings.listingSaveError}: $error', isError: true);
      }
    }
  }

  Future<void> _setActive(Listing listing, bool isActive) async {
    try {
      await widget.repository.setListingActive(listing.id, isActive);
      if (!mounted) return;
      _showMessage(AppStrings.listingVisibilityUpdated);
      await refresh();
    } catch (error) {
      if (mounted) {
        _showMessage('${AppStrings.listingSaveError}: $error', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : AppPalette.forest,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<Listing>>(
          future: _listingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ListingsMessage(
                icon: Icons.cloud_off_outlined,
                title: AppStrings.feedErrorTitle,
                message: snapshot.error.toString(),
                actionLabel: AppStrings.tryAgain,
                onAction: refresh,
              );
            }

            final listings = snapshot.data ?? const <Listing>[];
            if (listings.isNotEmpty &&
                listings.first.category == ListingCategory.carRental) {
              final business = listings.first;
              return CarRentalBusinessScreen(
                business: business,
                repository: widget.rentalCarRepository,
                onEditBusiness: () => _openEditor(business),
              );
            }
            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.yourListings,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    AppStrings.listingsOwnerMessage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppPalette.slate,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (listings.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ListingsMessage(
                      icon: Icons.add_business_outlined,
                      title: AppStrings.noOwnerListingsTitle,
                      message: AppStrings.noOwnerListingsMessage,
                      actionLabel: AppStrings.addListing,
                      onAction: openCreateListing,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: _OwnerListingCard(
                            listing: listings.first,
                            onEdit: () => _openEditor(listings.first),
                            onVisibilityChanged: (value) =>
                                _setActive(listings.first, value),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OwnerListingCard extends StatelessWidget {
  const _OwnerListingCard({
    required this.listing,
    required this.onEdit,
    required this.onVisibilityChanged,
  });

  final Listing listing;
  final VoidCallback onEdit;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                listing.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: AppStrings.editListing,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        Text(
          '${listingCategoryLabel(listing.category)}  |  ${formatCurrency(listing.price, listing.currency)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppPalette.terracotta,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              listing.isActive
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 17,
              color: AppPalette.slate,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                listing.isActive
                    ? AppStrings.visibleToCustomers
                    : AppStrings.hiddenFromCustomers,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Switch(value: listing.isActive, onChanged: onVisibilityChanged),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 420;
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: useVerticalLayout ? double.infinity : 104,
            height: useVerticalLayout ? 156 : 116,
            child: ListingImage(listing: listing),
          ),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.warmSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppPalette.warmOutline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (useVerticalLayout) ...[
                  image,
                  const SizedBox(height: 14),
                  details,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      image,
                      const SizedBox(width: 14),
                      Expanded(child: details),
                    ],
                  ),
                if (listing.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    listing.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.slate,
                      height: 1.45,
                    ),
                  ),
                ],
                if (listing.businessDetails.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    AppStrings.businessHighlights,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  BusinessDetailsSection(listing: listing),
                ],
                if (listing.phone != null || listing.websiteUrl != null) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (listing.phone != null)
                        _ContactDetail(
                          icon: Icons.phone_outlined,
                          value: listing.phone!,
                        ),
                      if (listing.websiteUrl != null)
                        _ContactDetail(
                          icon: Icons.language_outlined,
                          value: listing.websiteUrl!,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactDetail extends StatelessWidget {
  const _ContactDetail({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppPalette.forest),
        const SizedBox(width: 6),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ListingEditor extends StatefulWidget {
  const _ListingEditor({required this.verifyPassword, this.listing});

  final Listing? listing;
  final Future<bool> Function(String password) verifyPassword;

  @override
  State<_ListingEditor> createState() => _ListingEditorState();
}

class _ListingEditorState extends State<_ListingEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _location;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _availability;
  late final TextEditingController _duration;
  late ListingCategory _category;
  late String _currency;
  late final Map<String, TextEditingController> _detailControllers;
  late final Map<String, bool> _detailToggles;
  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _removeExistingImage = false;
  bool _categoryWasChanged = false;

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    _title = TextEditingController(text: listing?.title);
    _description = TextEditingController(text: listing?.description);
    _price = TextEditingController(
      text: listing == null ? '' : formatNumber(listing.price),
    );
    _location = TextEditingController(text: listing?.location);
    _city = TextEditingController(
      text: listing?.city ?? listing?.location.split(',').first,
    );
    _phone = TextEditingController(text: listing?.phone);
    _email = TextEditingController(text: listing?.email);
    _website = TextEditingController(text: listing?.websiteUrl);
    _availability = TextEditingController(text: listing?.availabilityNote);
    _duration = TextEditingController(
      text: listing?.defaultBookingDurationMinutes?.toString(),
    );
    _category = listing?.category ?? ListingCategory.stay;
    _currency = listing?.currency ?? 'ALL';
    _detailControllers = {};
    _detailToggles = {};
    for (final category in ListingCategory.values) {
      for (final field in businessDetailFields(category)) {
        if (field.isToggle) {
          _detailToggles[field.key] =
              listing?.businessDetails[field.key] == true;
        } else {
          _detailControllers[field.key] = TextEditingController(
            text: listing?.businessDetails[field.key]?.toString(),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _price,
      _location,
      _city,
      _phone,
      _email,
      _website,
      _availability,
      _duration,
      ..._detailControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      BusinessListingDraft(
        title: _title.text,
        description:
            _category == ListingCategory.carRental &&
                _description.text.trim().isEmpty
            ? AppStrings.carRentalDefaultDescription(_city.text.trim())
            : _description.text,
        price: double.tryParse(_price.text.replaceAll(',', '')) ?? 0,
        location: _location.text,
        category: _category,
        currency: _currency,
        city: _city.text,
        imageUrl: _removeExistingImage ? null : widget.listing?.imageUrl,
        imageBytes: _imageBytes,
        imageFileName: _imageFileName,
        businessDetails: _businessDetails(),
        phone: _phone.text,
        email: _email.text,
        websiteUrl: _website.text,
        availabilityNote: _availability.text,
        defaultBookingDurationMinutes: _duration.text.trim().isEmpty
            ? null
            : int.parse(_duration.text),
      ),
    );
  }

  Map<String, dynamic> _businessDetails() {
    if (_category == ListingCategory.carRental) return const {};
    final details = <String, dynamic>{};
    for (final field in businessDetailFields(_category)) {
      if (field.isToggle) {
        details[field.key] = _detailToggles[field.key] ?? false;
        continue;
      }
      final value = _detailControllers[field.key]?.text.trim() ?? '';
      if (value.isNotEmpty) details[field.key] = value;
    }
    return details;
  }

  Future<void> _requestCategoryChange(ListingCategory nextCategory) async {
    if (nextCategory == _category) return;
    if (widget.listing == null) {
      setState(() {
        _category = nextCategory;
        if (nextCategory == ListingCategory.carRental) {
          _description.clear();
          _price.text = '0';
          _availability.clear();
          _duration.clear();
        }
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppPalette.terracotta,
        ),
        title: const Text(AppStrings.changeBusinessTypeTitle),
        content: const Text(AppStrings.changeBusinessTypeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.changeBusinessTypeContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _PasswordConfirmationDialog(verifyPassword: widget.verifyPassword),
    );
    if (verified != true || !mounted) return;

    setState(() {
      _category = nextCategory;
      _categoryWasChanged = true;
      _description.clear();
      _price.text = '0';
      _availability.clear();
      _duration.clear();
      _imageBytes = null;
      _imageFileName = null;
      _removeExistingImage = widget.listing?.imageUrl != null;
      for (final controller in _detailControllers.values) {
        controller.clear();
      }
      for (final key in _detailToggles.keys) {
        _detailToggles[key] = false;
      }
    });
  }

  Future<void> _choosePhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageFileName = image.name;
      _removeExistingImage = false;
    });
  }

  void _removePhoto() {
    setState(() {
      _imageBytes = null;
      _imageFileName = null;
      _removeExistingImage = widget.listing?.imageUrl != null;
    });
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
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.listing == null
                          ? AppStrings.createListing
                          : AppStrings.editListing,
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
              _textField(
                controller: _title,
                label: AppStrings.listingTitleLabel,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ListingCategory>(
                initialValue: _category,
                decoration: _decoration(AppStrings.categoryLabel),
                items: [
                  for (final category in ListingCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(listingCategoryLabel(category)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _requestCategoryChange(value);
                },
              ),
              if (_categoryWasChanged) ...[
                const SizedBox(height: 12),
                Material(
                  color: AppPalette.warmField,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: AppPalette.forest,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(AppStrings.businessTypeResetNotice),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_category != ListingCategory.carRental) ...[
                const SizedBox(height: 12),
                _textField(
                  controller: _description,
                  label: AppStrings.descriptionLabel,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _textField(
                        controller: _price,
                        label: AppStrings.priceLabel,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').replaceAll(',', ''),
                          );
                          return parsed != null && parsed >= 0
                              ? null
                              : AppStrings.invalidPrice;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: _decoration(AppStrings.currencyLabel),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _currency = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _textField(
                controller: _location,
                label: AppStrings.locationLabel,
              ),
              const SizedBox(height: 12),
              _textField(controller: _city, label: AppStrings.cityLabel),
              const SizedBox(height: 12),
              BusinessPhotoPicker(
                selectedBytes: _imageBytes,
                existingImageUrl: _removeExistingImage
                    ? null
                    : widget.listing?.imageUrl,
                onChoose: _choosePhoto,
                onRemove: _removePhoto,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _phone,
                      label: AppStrings.phoneLabel,
                      required: false,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      controller: _email,
                      label: AppStrings.email,
                      required: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _website,
                label: AppStrings.websiteLabel,
                required: false,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              if (_category != ListingCategory.carRental) ...[
                _textField(
                  controller: _availability,
                  label: AppStrings.availabilityNoteLabel,
                  required: false,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.categoryDetails,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.categoryDetailsMessage,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.slate),
                ),
                const SizedBox(height: 12),
                for (final field in businessDetailFields(_category)) ...[
                  if (field.isToggle)
                    Material(
                      color: AppPalette.warmField,
                      borderRadius: BorderRadius.circular(14),
                      child: SwitchListTile.adaptive(
                        value: _detailToggles[field.key] ?? false,
                        onChanged: (value) {
                          setState(() => _detailToggles[field.key] = value);
                        },
                        secondary: Icon(field.icon, color: AppPalette.forest),
                        title: Text(field.label),
                      ),
                    )
                  else
                    _textField(
                      controller: _detailControllers[field.key]!,
                      label: field.label,
                      required: false,
                      keyboardType: field.keyboardType,
                    ),
                  const SizedBox(height: 12),
                ],
                _textField(
                  controller: _duration,
                  label: AppStrings.durationLabel,
                  required: false,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    final parsed = int.tryParse(value!);
                    return parsed != null && parsed >= 15 && parsed <= 720
                        ? null
                        : AppStrings.invalidDuration;
                  },
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text(AppStrings.saveListing),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    bool required = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _decoration(label),
      validator:
          validator ??
          (value) => required && (value ?? '').trim().isEmpty
              ? AppStrings.requiredField
              : null,
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppPalette.warmField,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.forest),
      ),
    );
  }
}

class _PasswordConfirmationDialog extends StatefulWidget {
  const _PasswordConfirmationDialog({required this.verifyPassword});

  final Future<bool> Function(String password) verifyPassword;

  @override
  State<_PasswordConfirmationDialog> createState() =>
      _PasswordConfirmationDialogState();
}

class _PasswordConfirmationDialogState
    extends State<_PasswordConfirmationDialog> {
  final _password = TextEditingController();
  bool _isVerifying = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _error = AppStrings.requiredField);
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });
    bool verified;
    try {
      verified = await widget.verifyPassword(password);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = AppStrings.passwordVerificationError;
      });
      return;
    }
    if (!mounted) return;
    if (verified) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _isVerifying = false;
      _error = AppStrings.incorrectPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_outline, color: AppPalette.forest),
      title: const Text(AppStrings.confirmBusinessPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(AppStrings.confirmBusinessPasswordMessage),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: _obscurePassword,
            enabled: !_isVerifying,
            onSubmitted: (_) {
              if (!_isVerifying) _verify();
            },
            decoration: InputDecoration(
              labelText: AppStrings.currentPassword,
              errorText: _error,
              prefixIcon: const Icon(Icons.password_outlined),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                tooltip: _obscurePassword
                    ? AppStrings.showPassword
                    : AppStrings.hidePassword,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context, false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton.icon(
          onPressed: _isVerifying ? null : _verify,
          icon: _isVerifying
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.verified_user_outlined),
          label: const Text(AppStrings.verifyAndContinue),
        ),
      ],
    );
  }
}

class _ListingsMessage extends StatelessWidget {
  const _ListingsMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppPalette.forest),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
