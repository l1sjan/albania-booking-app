import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

class BusinessPhotoPicker extends StatelessWidget {
  const BusinessPhotoPicker({
    super.key,
    required this.selectedBytes,
    required this.existingImageUrl,
    required this.onChoose,
    required this.onRemove,
    this.title = AppStrings.businessPhoto,
    this.message = AppStrings.photoOptional,
    this.placeholderIcon = Icons.storefront_outlined,
  });

  final Uint8List? selectedBytes;
  final String? existingImageUrl;
  final VoidCallback onChoose;
  final VoidCallback onRemove;
  final String title;
  final String message;
  final IconData placeholderIcon;

  bool get _hasPhoto => selectedBytes != null || existingImageUrl != null;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.warmField,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(width: 82, height: 82, child: _preview()),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.slate),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 2,
                    children: [
                      TextButton.icon(
                        onPressed: onChoose,
                        icon: Icon(
                          _hasPhoto
                              ? Icons.edit_outlined
                              : Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _hasPhoto
                              ? AppStrings.changePhoto
                              : AppStrings.choosePhoto,
                        ),
                      ),
                      if (_hasPhoto)
                        IconButton(
                          onPressed: onRemove,
                          tooltip: AppStrings.removePhoto,
                          icon: const Icon(Icons.close, size: 19),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (selectedBytes != null) {
      return Image.memory(selectedBytes!, fit: BoxFit.cover);
    }
    if (existingImageUrl != null) {
      return Image.network(
        existingImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.sand, AppPalette.sage],
        ),
      ),
      child: Center(child: Icon(placeholderIcon, color: AppPalette.forest)),
    );
  }
}
