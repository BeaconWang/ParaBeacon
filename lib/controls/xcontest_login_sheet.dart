import 'package:flutter/material.dart';

import '../data/xcontest_auth_service.dart';
import '../l10n/app_localizations.dart';

Future<void> showXContestLoginSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _XContestLoginSheet(),
  );
}

class _XContestLoginSheet extends StatefulWidget {
  const _XContestLoginSheet();

  @override
  State<_XContestLoginSheet> createState() => _XContestLoginSheetState();
}

class _XContestProfileField {
  const _XContestProfileField(this.label, this.value);

  final String label;
  final String value;
}

class _XContestLoginSheetState extends State<_XContestLoginSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final auth = XContestAuthService.instance;
    _usernameController = TextEditingController(text: auth.username ?? '');
    _passwordController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => auth.load());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await XContestAuthService.instance.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );
    // Never retain the password in the form after the request completes.
    _passwordController.clear();
    if (!success && mounted) setState(() {});
  }

  List<_XContestProfileField> _profileFields(
    AppLocalizations l10n,
    XContestAuthService auth,
  ) {
    final information = auth.accountInformation;
    return [
      if (information['full_name'] != null)
        _XContestProfileField(l10n.xcontestFullName, information['full_name']!),
      if (information['username'] != null)
        _XContestProfileField(l10n.xcontestUsername, information['username']!),
      if (information['uid'] != null)
        _XContestProfileField(l10n.xcontestUserId, information['uid']!),
    ];
  }

  String _errorText(AppLocalizations l10n, XContestAuthService auth) {
    if (auth.errorMessage != null) return auth.errorMessage!;
    switch (auth.errorCode) {
      case 'missingCredentials':
        return l10n.xcontestCredentialsRequired;
      case 'invalidCredentials':
        return l10n.xcontestInvalidCredentials;
      case 'connectionFailed':
        return l10n.xcontestConnectionFailed;
      default:
        return l10n.xcontestLoginFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: XContestAuthService.instance,
      builder: (context, _) {
        final auth = XContestAuthService.instance;
        final displayName = auth.fullName ?? auth.username ?? 'XContest';
        final profileFields = _profileFields(l10n, auth);
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
                          l10n.xcontestAccount,
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
                        Icons.public,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.xcontestAccount,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.xcontestAccountSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (auth.isSignedIn)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Text(
                                        displayName.trim().isEmpty
                                            ? 'X'
                                            : displayName
                                                  .trim()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onPrimaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: theme.textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n.xcontestSignedIn,
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              l10n.xcontestProfileInformation,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Card(
                              child: Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < profileFields.length;
                                    index++
                                  ) ...[
                                    ListTile(
                                      dense: true,
                                      title: Text(profileFields[index].label),
                                      subtitle: Text(
                                        profileFields[index].value,
                                      ),
                                    ),
                                    if (index < profileFields.length - 1)
                                      const Divider(height: 1),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: auth.isLoading ? null : auth.logout,
                              icon: const Icon(Icons.logout),
                              label: Text(l10n.logout),
                            ),
                          ],
                        )
                      else ...[
                        if (auth.errorCode != null) ...[
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
                                    _errorText(l10n, auth),
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
                                  labelText: l10n.xcontestUsername,
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? l10n.xcontestCredentialsRequired
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
                                  labelText: l10n.xcontestPassword,
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
                                    ? l10n.xcontestCredentialsRequired
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
