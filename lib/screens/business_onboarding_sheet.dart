import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
import '../services/business_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/business_photo_picker.dart';
import '../widgets/listing_image.dart';

Future<bool> showBusinessOnboardingSheet(
  BuildContext context,
  BusinessRepository repository,
) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => _BusinessOnboardingSheet(repository: repository),
      ) ??
      false;
}

class _BusinessOnboardingSheet extends StatefulWidget {
  const _BusinessOnboardingSheet({required this.repository});

  final BusinessRepository repository;

  @override
  State<_BusinessOnboardingSheet> createState() =>
      _BusinessOnboardingSheetState();
}

class _BusinessOnboardingSheetState extends State<_BusinessOnboardingSheet> {
  final _identityKey = GlobalKey<FormState>();
  final _publishKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _city = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _phone = TextEditingController();
  final _availability = TextEditingController();
  ListingCategory _category = ListingCategory.barber;
  int _step = 0;
  bool _isPublishing = false;
  String? _error;
  Uint8List? _imageBytes;
  String? _imageFileName;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _city,
      _description,
      _price,
      _phone,
      _availability,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1 && _identityKey.currentState!.validate()) {
      setState(() => _step = 2);
    }
  }

  void _previous() {
    if (_step > 0) setState(() => _step -= 1);
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
    });
  }

  void _removePhoto() {
    setState(() {
      _imageBytes = null;
      _imageFileName = null;
    });
  }

  Future<void> _publish() async {
    if (!_publishKey.currentState!.validate()) return;
    setState(() {
      _isPublishing = true;
      _error = null;
    });

    try {
      await widget.repository.saveListing(
        BusinessListingDraft(
          title: _title.text,
          description: _description.text,
          price: double.parse(_price.text.replaceAll(',', '')),
          location: '${_city.text.trim()}, Albania',
          category: _category,
          currency: 'ALL',
          city: _city.text,
          imageBytes: _imageBytes,
          imageFileName: _imageFileName,
          phone: _phone.text,
          availabilityNote: _availability.text,
          defaultBookingDurationMinutes: _defaultDuration,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _error = error.toString();
        });
      }
    }
  }

  int? get _defaultDuration {
    return switch (_category) {
      ListingCategory.barber => 60,
      ListingCategory.dentist => 60,
      ListingCategory.restaurant => 90,
      ListingCategory.carRental || ListingCategory.stay => null,
    };
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: _step > 0
                        ? IconButton(
                            onPressed: _isPublishing ? null : _previous,
                            tooltip: AppStrings.back,
                            icon: const Icon(Icons.arrow_back),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      AppStrings.onboardingTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      onPressed: _isPublishing
                          ? null
                          : () => Navigator.pop(context, false),
                      tooltip: AppStrings.close,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Progress(step: _step),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _buildStep(context),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ActionRow(
                step: _step,
                isPublishing: _isPublishing,
                onNext: _next,
                onPublish: _publish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return switch (_step) {
      0 => _WelcomeStep(key: const ValueKey('welcome')),
      1 => Form(
        key: _identityKey,
        child: _IdentityStep(
          key: const ValueKey('identity'),
          title: _title,
          city: _city,
          category: _category,
          onCategoryChanged: (category) {
            setState(() => _category = category);
          },
        ),
      ),
      _ => Form(
        key: _publishKey,
        child: _PublishStep(
          key: const ValueKey('publish'),
          description: _description,
          price: _price,
          phone: _phone,
          availability: _availability,
          selectedBytes: _imageBytes,
          onChoosePhoto: _choosePhoto,
          onRemovePhoto: _removePhoto,
        ),
      ),
    };
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${AppStrings.setupProgress} ${step + 1} of 3',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppPalette.slate),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (step + 1) / 3,
              minHeight: 5,
              color: AppPalette.forest,
              backgroundColor: AppPalette.warmField,
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppPalette.forest,
            shape: BoxShape.circle,
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Icon(Icons.storefront_outlined, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.onboardingWelcomeTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.onboardingWelcomeMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppPalette.slate,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    super.key,
    required this.title,
    required this.city,
    required this.category,
    required this.onCategoryChanged,
  });

  final TextEditingController title;
  final TextEditingController city;
  final ListingCategory category;
  final ValueChanged<ListingCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.onboardingIdentityTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.onboardingIdentityMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppPalette.slate,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _OnboardingField(
          controller: title,
          label: AppStrings.listingTitleLabel,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ListingCategory>(
          initialValue: category,
          decoration: _onboardingDecoration(AppStrings.categoryLabel),
          items: [
            for (final value in ListingCategory.values)
              DropdownMenuItem(
                value: value,
                child: Text(listingCategoryLabel(value)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onCategoryChanged(value);
          },
        ),
        const SizedBox(height: 12),
        _OnboardingField(controller: city, label: AppStrings.cityLabel),
      ],
    );
  }
}

class _PublishStep extends StatelessWidget {
  const _PublishStep({
    super.key,
    required this.description,
    required this.price,
    required this.phone,
    required this.availability,
    required this.selectedBytes,
    required this.onChoosePhoto,
    required this.onRemovePhoto,
  });

  final TextEditingController description;
  final TextEditingController price;
  final TextEditingController phone;
  final TextEditingController availability;
  final Uint8List? selectedBytes;
  final VoidCallback onChoosePhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.onboardingPublishTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.onboardingPublishMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppPalette.slate,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _OnboardingField(
          controller: description,
          label: AppStrings.descriptionLabel,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        _OnboardingField(
          controller: price,
          label: AppStrings.priceLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final parsed = double.tryParse((value ?? '').replaceAll(',', ''));
            return parsed != null && parsed >= 0
                ? null
                : AppStrings.invalidPrice;
          },
        ),
        const SizedBox(height: 12),
        _OnboardingField(
          controller: phone,
          label: AppStrings.phoneLabel,
          required: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _OnboardingField(
          controller: availability,
          label: AppStrings.availabilityNoteLabel,
          required: false,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        BusinessPhotoPicker(
          selectedBytes: selectedBytes,
          existingImageUrl: null,
          onChoose: onChoosePhoto,
          onRemove: onRemovePhoto,
        ),
      ],
    );
  }
}

class _OnboardingField extends StatelessWidget {
  const _OnboardingField({
    required this.controller,
    required this.label,
    this.required = true,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _onboardingDecoration(label),
      validator:
          validator ??
          (value) => required && (value ?? '').trim().isEmpty
              ? AppStrings.requiredField
              : null,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.step,
    required this.isPublishing,
    required this.onNext,
    required this.onPublish,
  });

  final int step;
  final bool isPublishing;
  final VoidCallback onNext;
  final Future<void> Function() onPublish;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isPublishing
                ? null
                : step == 2
                ? onPublish
                : onNext,
            icon: isPublishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    step == 2 ? Icons.publish_outlined : Icons.arrow_forward,
                  ),
            label: Text(
              step == 2 ? AppStrings.publishListing : AppStrings.continueLabel,
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _onboardingDecoration(String label) {
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
