import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/account_profile.dart';
import '../services/booking_repository.dart';
import '../theme/app_theme.dart';

Future<bool> showAuthenticationSheet(
  BuildContext context,
  BookingRepository repository,
) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => _AuthenticationSheet(repository: repository),
      ) ??
      false;
}

class _AuthenticationSheet extends StatefulWidget {
  const _AuthenticationSheet({required this.repository});

  final BookingRepository repository;

  @override
  State<_AuthenticationSheet> createState() => _AuthenticationSheetState();
}

class _AuthenticationSheetState extends State<_AuthenticationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _createAccount = false;
  AccountRole _accountRole = AccountRole.customer;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _confirmationSent = false;
  bool _isResettingPassword = false;
  bool _passwordResetSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
      _confirmationSent = false;
      _passwordResetSent = false;
    });

    try {
      if (_isResettingPassword) {
        await widget.repository.requestPasswordReset(_emailController.text);
        if (!mounted) return;
        setState(() => _passwordResetSent = true);
        return;
      }

      final result = await widget.repository.authenticate(
        email: _emailController.text,
        password: _passwordController.text,
        createAccount: _createAccount,
        accountRole: _accountRole,
        displayName: _nameController.text,
      );
      if (!mounted) return;

      if (result == AuthenticationResult.authenticated) {
        Navigator.pop(context, true);
        return;
      }

      setState(() => _confirmationSent = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _passwordResetSent
                            ? AppStrings.passwordResetSentTitle
                            : _confirmationSent
                            ? AppStrings.emailConfirmationTitle
                            : _isResettingPassword
                            ? AppStrings.resetPasswordTitle
                            : AppStrings.signInRequiredTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      tooltip: AppStrings.close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _passwordResetSent
                      ? AppStrings.passwordResetSentMessage
                      : _confirmationSent
                      ? AppStrings.emailConfirmationMessage
                      : _isResettingPassword
                      ? AppStrings.resetPasswordMessage
                      : AppStrings.signInRequiredMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.slate,
                    height: 1.45,
                  ),
                ),
                if (!_confirmationSent && !_passwordResetSent) ...[
                  const SizedBox(height: 22),
                  if (_createAccount && !_isResettingPassword) ...[
                    Text(
                      AppStrings.accountType,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<AccountRole>(
                      segments: const [
                        ButtonSegment(
                          value: AccountRole.customer,
                          icon: Icon(Icons.person_outline),
                          label: Text(AppStrings.customerAccount),
                        ),
                        ButtonSegment(
                          value: AccountRole.businessOwner,
                          icon: Icon(Icons.storefront_outlined),
                          label: Text(AppStrings.businessAccount),
                        ),
                      ],
                      selected: {_accountRole},
                      onSelectionChanged: (selection) {
                        setState(() => _accountRole = selection.first);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        label: _accountRole == AccountRole.businessOwner
                            ? AppStrings.ownerName
                            : AppStrings.fullName,
                        icon: Icons.badge_outlined,
                      ),
                      validator: (value) {
                        if (!_createAccount) return null;
                        return (value?.trim().length ?? 0) >= 2
                            ? null
                            : AppStrings.invalidName;
                      },
                    ),
                    if (_accountRole == AccountRole.businessOwner) ...[
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.businessAccountMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.slate,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: _fieldDecoration(
                      label: AppStrings.email,
                      icon: Icons.mail_outline,
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return email.contains('@') && email.contains('.')
                          ? null
                          : AppStrings.invalidEmail;
                    },
                  ),
                  if (!_isResettingPassword) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration:
                          _fieldDecoration(
                            label: AppStrings.password,
                            icon: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              tooltip: AppStrings.password,
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                      validator: (value) => (value?.length ?? 0) >= 6
                          ? null
                          : AppStrings.invalidPassword,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (!_createAccount)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                  _isResettingPassword = true;
                                  _error = null;
                                }),
                          child: const Text(AppStrings.forgotPassword),
                        ),
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isResettingPassword
                                ? AppStrings.sendResetLink
                                : _createAccount
                                ? AppStrings.createAccount
                                : AppStrings.signIn,
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : _isResettingPassword
                        ? () => setState(() {
                            _isResettingPassword = false;
                            _error = null;
                          })
                        : () => setState(() {
                            _createAccount = !_createAccount;
                            _accountRole = AccountRole.customer;
                            _error = null;
                          }),
                    child: Text(
                      _isResettingPassword
                          ? AppStrings.backToSignIn
                          : _createAccount
                          ? AppStrings.useExistingAccount
                          : AppStrings.createAccount,
                    ),
                  ),
                ],
                if (_passwordResetSent) ...[
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => setState(() {
                      _passwordResetSent = false;
                      _isResettingPassword = false;
                      _error = null;
                    }),
                    child: const Text(AppStrings.backToSignIn),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppPalette.warmField,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.forest),
      ),
    );
  }
}

Future<void> showPasswordUpdateSheet(
  BuildContext context,
  BookingRepository repository,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _PasswordUpdateSheet(repository: repository),
  );
}

class _PasswordUpdateSheet extends StatefulWidget {
  const _PasswordUpdateSheet({required this.repository});

  final BookingRepository repository;

  @override
  State<_PasswordUpdateSheet> createState() => _PasswordUpdateSheetState();
}

class _PasswordUpdateSheetState extends State<_PasswordUpdateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isSubmitting = false;
  bool _isComplete = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.repository.updatePassword(_password.text);
      if (!mounted) return;
      setState(() => _isComplete = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: _isComplete
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.passwordUpdatedTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.passwordUpdatedMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.slate,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.done),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.chooseNewPassword,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.resetPasswordMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.slate,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofocus: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: _passwordDecoration(
                        AppStrings.chooseNewPassword,
                      ),
                      validator: (value) => (value?.length ?? 0) >= 6
                          ? null
                          : AppStrings.invalidPassword,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: _passwordDecoration(
                        AppStrings.confirmNewPassword,
                      ),
                      validator: (value) => value == _password.text
                          ? null
                          : AppStrings.passwordMismatch,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(AppStrings.updatePassword),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  InputDecoration _passwordDecoration(String label) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      filled: true,
      fillColor: AppPalette.warmField,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.forest),
      ),
    );
  }
}
