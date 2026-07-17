import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

Future<String?> showBookingReasonDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _BookingReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    ),
  );
}

class _BookingReasonDialog extends StatefulWidget {
  const _BookingReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  State<_BookingReasonDialog> createState() => _BookingReasonDialogState();
}

class _BookingReasonDialogState extends State<_BookingReasonDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 3) {
      setState(() => _errorText = AppStrings.reasonRequired);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: AppStrings.reasonLabel,
              hintText: AppStrings.cancellationReasonHint,
              errorText: _errorText,
            ),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.keepBooking),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
