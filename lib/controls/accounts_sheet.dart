import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../l10n/app_localizations.dart';

Future<void> showAccountsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _AccountsSheet(),
  );
}

class _AccountsSheet extends StatefulWidget {
  const _AccountsSheet();

  @override
  State<_AccountsSheet> createState() => _AccountsSheetState();
}

class _AccountsSheetState extends State<_AccountsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final auth = AsfcAuthService.instance;
    _usernameController = TextEditingController(text: auth.username ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await AsfcAuthService.instance.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (!mounted || success) {
      if (mounted && success) Navigator.of(context).pop();
      return;
    }
    final auth = AsfcAuthService.instance;
    final error = auth.errorCode;
    final reason = auth.errorMessage;
    final message = error == 'connectionFailed'
        ? l10n.asfcConnectionFailed
        : error == 'missingCredentials'
        ? l10n.asfcCredentialsRequired
        : reason == null
        ? l10n.asfcLoginFailed
        : l10n.asfcLoginFailedWithReason(reason);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: AsfcAuthService.instance,
      builder: (context, _) {
        final auth = AsfcAuthService.instance;
        return Material(
          color: theme.colorScheme.surface,
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          l10n.accounts,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.asfcAccount,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.asfcAccountSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (auth.isSignedIn) ...[
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                (auth.username ?? 'A')
                                    .substring(0, 1)
                                    .toUpperCase(),
                              ),
                            ),
                            title: Text(auth.username ?? l10n.asfcSignedIn),
                            subtitle: Text(l10n.asfcSignedIn),
                          ),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: auth.isLoading
                              ? null
                              : AsfcAuthService.instance.logout,
                          icon: const Icon(Icons.logout),
                          label: Text(l10n.logout),
                        ),
                      ] else ...[
                        if (auth.errorCode == 'loginFailed' ||
                            auth.errorCode == 'connectionFailed') ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    auth.errorMessage ??
                                        (auth.errorCode == 'connectionFailed'
                                            ? l10n.asfcConnectionFailed
                                            : l10n.asfcLoginFailed),
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _usernameController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: InputDecoration(
                                  labelText: l10n.asfcUsername,
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? l10n.asfcCredentialsRequired
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  labelText: l10n.asfcPassword,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? l10n.showPassword
                                        : l10n.hidePassword,
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? l10n.asfcCredentialsRequired
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: auth.isLoading ? null : _login,
                                  icon: auth.isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.login),
                                  label: Text(
                                    auth.isLoading
                                        ? l10n.loggingIn
                                        : l10n.login,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
