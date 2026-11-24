import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/parabeacon_account_service.dart';
import '../l10n/app_localizations.dart';
import 'app_notice.dart';

class ProfilePasswordChangeSection extends StatefulWidget {
  const ProfilePasswordChangeSection({required this.account, super.key});

  final ParaBeaconAccountService account;

  @override
  State<ProfilePasswordChangeSection> createState() =>
      _ProfilePasswordChangeSectionState();
}

class _ProfilePasswordChangeSectionState
    extends State<ProfilePasswordChangeSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _changingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context);
    if (_changingPassword || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _changingPassword = true);
    final changed = await widget.account.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (changed) {
      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
      AppNotice.show(l10n.accountPasswordChanged);
    }
    if (mounted) setState(() => _changingPassword = false);
  }

  String? _errorText(AppLocalizations l10n) =>
      switch (widget.account.errorCode) {
        'accountCurrentPasswordIncorrect' =>
          l10n.accountCurrentPasswordIncorrect,
        'accountSessionExpired' => l10n.accountSessionExpired,
        'accountPasswordUnchanged' => l10n.accountPasswordUnchanged,
        'accountConnectionFailure' => l10n.accountErrorConnection,
        'accountStorageFailure' => l10n.accountErrorStorage,
        'accountServiceUnavailable' ||
        'accountRequestFailed' => l10n.accountErrorService,
        _ => null,
      };

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggleVisibility,
    required String? Function(String?) validator,
    required TextInputAction textInputAction,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) => TextFormField(
    controller: controller,
    obscureText: obscure,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: obscure
            ? AppLocalizations.of(context).showPassword
            : AppLocalizations.of(context).hidePassword,
        onPressed: toggleVisibility,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator: validator,
    onFieldSubmitted: onSubmitted,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ExpansionTile(
        key: const ValueKey('profile-change-password'),
        leading: const Icon(Icons.lock_reset_outlined),
        title: Text(l10n.accountChangePassword),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _passwordField(
                    controller: _currentPasswordController,
                    label: l10n.accountCurrentPassword,
                    obscure: _obscureCurrentPassword,
                    toggleVisibility: () => setState(
                      () => _obscureCurrentPassword = !_obscureCurrentPassword,
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) => value == null || value.isEmpty
                        ? l10n.accountPasswordRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    controller: _newPasswordController,
                    label: l10n.accountNewPassword,
                    obscure: _obscureNewPassword,
                    toggleVisibility: () => setState(
                      () => _obscureNewPassword = !_obscureNewPassword,
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.accountPasswordRequired;
                      }
                      if (value.runes.length < 6) {
                        return l10n.accountPasswordMinimum;
                      }
                      if (utf8.encode(value).length > 72) {
                        return l10n.accountPasswordMaximum;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    controller: _confirmPasswordController,
                    label: l10n.accountConfirmPassword,
                    obscure: _obscureConfirmPassword,
                    toggleVisibility: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) => value != _newPasswordController.text
                        ? l10n.accountPasswordMismatch
                        : null,
                    onSubmitted: (_) => _changePassword(),
                  ),
                  if (_errorText(l10n) case final error?) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: widget.account.isBusy || _changingPassword
                          ? null
                          : _changePassword,
                      icon: _changingPassword
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset_outlined),
                      label: Text(l10n.accountChangePassword),
                    ),
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
