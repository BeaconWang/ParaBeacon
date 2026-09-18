import 'dart:async';

import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../data/xcontest_auth_service.dart';
import '../l10n/app_localizations.dart';
import 'xcontest_login_sheet.dart';
import 'certificate_application_sheet.dart';
import 'asfc_flight_records_sheet.dart';

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

Future<void> showAsfcLoginSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _AsfcLoginSheet(),
  );
}

class _AsfcLoginSheet extends StatefulWidget {
  const _AsfcLoginSheet();

  @override
  State<_AsfcLoginSheet> createState() => _AsfcLoginSheetState();
}

class _ProfileField {
  const _ProfileField(this.label, this.value);

  final String label;
  final String value;
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl, required this.fallback});

  final String? imageUrl;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final initial = fallback.trim().isEmpty
        ? 'A'
        : fallback.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 30,
      backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
      onBackgroundImageError: imageUrl == null ? null : (_, _) {},
      child: imageUrl == null ? Text(initial) : null,
    );
  }
}

class _AccountsSheet extends StatefulWidget {
  const _AccountsSheet();

  @override
  State<_AccountsSheet> createState() => _AccountsSheetState();
}

class _AccountsSheetState extends State<_AccountsSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        AsfcAuthService.instance,
        XContestAuthService.instance,
      ]),
      builder: (context, _) {
        final asfc = AsfcAuthService.instance;
        final xcontest = XContestAuthService.instance;
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
                        l10n.accounts,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.accountsSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _AccountCard(
                        icon: Icons.account_circle_outlined,
                        title: l10n.asfcAccount,
                        subtitle: asfc.isSignedIn
                            ? '${l10n.asfcSignedIn} · ${asfc.username ?? ''}'
                            : l10n.asfcAccountSubtitle,
                        onTap: () => showAsfcLoginSheet(context),
                      ),
                      const SizedBox(height: 12),
                      _AccountCard(
                        icon: Icons.public,
                        title: l10n.xcontestAccount,
                        subtitle: xcontest.isSignedIn
                            ? '${l10n.xcontestSignedIn} · ${xcontest.fullName ?? xcontest.username ?? ''}'
                            : l10n.xcontestAccountSubtitle,
                        onTap: () => showXContestLoginSheet(context),
                      ),
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CertificateStatusPanel extends StatelessWidget {
  const _CertificateStatusPanel({
    required this.auth,
    required this.onApply,
  });

  final AsfcAuthService auth;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (auth.isCertificateInfoLoading && auth.certificateApplication == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }

    final certificate = auth.certificateStatus;
    switch (certificate.state) {
      case AsfcCertificateState.issued:
        return _issuedCard(context, theme, l10n, certificate);
      case AsfcCertificateState.pending:
        return Card(
          color: theme.colorScheme.secondaryContainer,
          child: ListTile(
            leading: Icon(
              Icons.hourglass_top_outlined,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            title: Text(l10n.certificatePendingApproval),
            subtitle: Text(l10n.certificatePendingApprovalSubtitle),
          ),
        );
      case AsfcCertificateState.none:
      case AsfcCertificateState.rejected:
        return FilledButton.icon(
          onPressed: auth.isLoading ? null : onApply,
          icon: const Icon(Icons.workspace_premium_outlined),
          label: Text(l10n.applyForCertificate),
        );
    }
  }

  Widget _issuedCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    AsfcCertificateStatus certificate,
  ) {
    final rows = <(String, String)>[
      if (certificate.fullName != null)
        (l10n.certificateFullName, certificate.fullName!),
      if (certificate.licenseNo != null)
        (l10n.certificateNumber, certificate.licenseNo!),
      if (certificate.level != null)
        (l10n.certificateLevel, certificate.level!),
      if (certificate.sportCode != null)
        (l10n.certificateSportCode, certificate.sportCode!),
      if (certificate.licenseStatusName != null)
        (l10n.certificateValidityStatus, certificate.licenseStatusName!),
      if (certificate.licenseValidStart != null ||
          certificate.licenseValidEnd != null)
        (
          l10n.certificateValidity,
          '${certificate.licenseValidStart ?? '-'} – ${certificate.licenseValidEnd ?? '-'}',
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.certificateDetails,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  l10n.certificateIssued,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            for (final row in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(row.$1),
                trailing: Text(row.$2),
              ),
          ],
        ),
      ),
    );
  }
}

class _AsfcLoginSheetState extends State<_AsfcLoginSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _smsCodeController;
  late final TextEditingController _captchaController;
  bool _obscurePassword = true;
  bool _smsMode = false;
  Timer? _smsCountdownTimer;
  int _smsSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    final auth = AsfcAuthService.instance;
    XContestAuthService.instance.load();
    _usernameController = TextEditingController(text: auth.username ?? '');
    _passwordController = TextEditingController();
    _smsCodeController = TextEditingController();
    _captchaController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await auth.load();
      if (auth.isSignedIn) {
        await Future.wait([
          auth.loadProfile(),
          auth.loadCertificateApplication(),
        ]);
      }
    });
  }

  @override
  void dispose() {
    _smsCountdownTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _smsCodeController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await AsfcAuthService.instance.login(
      username: _usernameController.text,
      password: _passwordController.text,
      smsCode: _smsMode ? _smsCodeController.text : null,
    );
    if (success) {
      await Future.wait([
        AsfcAuthService.instance.loadProfile(force: true),
        AsfcAuthService.instance.loadCertificateApplication(force: true),
      ]);
    }
  }

  Future<void> _refreshCaptcha() async {
    await AsfcAuthService.instance.loadCaptcha(
      mobile: _usernameController.text,
    );
  }

  Future<void> _sendSmsCode() async {
    final success = await AsfcAuthService.instance.sendSmsCode(
      mobile: _usernameController.text,
      captcha: _captchaController.text,
    );
    if (!mounted || !success) return;
    _smsCountdownTimer?.cancel();
    setState(() => _smsSecondsRemaining = 60);
    _smsCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_smsSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _smsSecondsRemaining = 0);
      } else {
        setState(() => _smsSecondsRemaining--);
      }
    });
  }

  Future<void> _setLoginMode(bool smsMode) async {
    setState(() => _smsMode = smsMode);
    if (smsMode && _usernameController.text.trim().isNotEmpty) {
      await _refreshCaptcha();
    }
  }

  String _errorText(AppLocalizations l10n, AsfcAuthService auth) {
    if (auth.errorMessage != null) return auth.errorMessage!;
    switch (auth.errorCode) {
      case 'connectionFailed':
        return l10n.asfcConnectionFailed;
      case 'captchaRequired':
        return l10n.asfcCaptchaRequired;
      case 'captchaLoadFailed':
        return l10n.asfcCaptchaLoadFailed;
      case 'smsCodeSendFailed':
        return l10n.asfcSmsCodeSendFailed;
      case 'smsMobileRequired':
        return l10n.asfcMobileRequired;
      case 'smsCredentialsRequired':
        return l10n.asfcSmsCredentialsRequired;
      default:
        return l10n.asfcLoginFailed;
    }
  }

  String _profileTitle(Map<String, dynamic>? profile, AsfcAuthService auth) {
    final circle = profile?['circleInfo'];
    final user = profile?['user'];
    final nickname = circle is Map<String, dynamic>
        ? circle['userNickname']
        : null;
    final username = user is Map<String, dynamic> ? user['username'] : null;
    return _nonEmptyString(nickname) ??
        _nonEmptyString(username) ??
        auth.username ??
        'ASFC';
  }

  String? _profileDescription(Map<String, dynamic>? profile) {
    final circle = profile?['circleInfo'];
    if (circle is Map<String, dynamic>) {
      return _nonEmptyString(circle['description']);
    }
    return null;
  }

  String? _nonEmptyString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  List<_ProfileField> _profileFields(
    Map<String, dynamic> profile,
    AppLocalizations l10n,
  ) {
    final fields = <_ProfileField>[];
    void flatten(String path, Object? value) {
      if (value is Map<String, dynamic>) {
        for (final entry in value.entries) {
          flatten(path.isEmpty ? entry.key : '$path.${entry.key}', entry.value);
        }
        return;
      }
      if (value is List) {
        for (var index = 0; index < value.length; index++) {
          flatten('$path.${index + 1}', value[index]);
        }
        return;
      }
      if (value == null) return;
      final key = path.split('.').last.toLowerCase();
      if (key.contains('token') || key.contains('password')) return;
      if (key == 'headportrait' || key.contains('credentialsphoto')) {
        fields.add(
          _ProfileField(_humanize(path), l10n.asfcInformationAvailable),
        );
        return;
      }
      fields.add(_ProfileField(_humanize(path), _safeProfileValue(key, value)));
    }

    flatten('', profile);
    return fields;
  }

  String _safeProfileValue(String key, Object value) {
    final text = value.toString();
    if (key == 'credentialsnumber') return _maskValue(text, 4);
    if (key == 'mobile' || key.contains('phone')) return _maskValue(text, 3);
    return text;
  }

  String _maskValue(String value, int visibleSuffix) {
    if (value.length <= visibleSuffix) return '••••';
    final hidden = List.filled(value.length - visibleSuffix, '•').join();
    return '$hidden${value.substring(value.length - visibleSuffix)}';
  }

  String _humanize(String value) {
    final parts = value.split('.');
    return parts
        .map(
          (part) => part
              .replaceAllMapped(
                RegExp(r'([a-z0-9])([A-Z])'),
                (match) => '${match.group(1)} ${match.group(2)}',
              )
              .replaceAll('_', ' ')
              .replaceFirstMapped(
                RegExp(r'^[a-z]'),
                (match) => match.group(0)!.toUpperCase(),
              ),
        )
        .join(' · ');
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
                          l10n.asfcAccount,
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
                        Builder(
                          builder: (context) {
                            final profile = auth.profile;
                            final title = _profileTitle(profile, auth);
                            final description = _profileDescription(profile);
                            final fields = profile == null
                                ? const <_ProfileField>[]
                                : _profileFields(profile, l10n);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _ProfileAvatar(
                                          imageUrl: auth.avatarUrl,
                                          fallback: title,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style:
                                                    theme.textTheme.titleLarge,
                                              ),
                                              if (description != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  description,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                              const SizedBox(height: 6),
                                              Text(
                                                l10n.asfcSignedIn,
                                                style: TextStyle(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: l10n.asfcRefreshProfile,
                                          onPressed: auth.isProfileLoading ||
                                                  auth.isCertificateInfoLoading
                                              ? null
                                              : () async {
                                                  await Future.wait([
                                                    auth.loadProfile(force: true),
                                                    auth.loadCertificateApplication(
                                                      force: true,
                                                    ),
                                                  ]);
                                                },
                                          icon: const Icon(Icons.refresh),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (auth.isProfileLoading) ...[
                                  const SizedBox(height: 12),
                                  const LinearProgressIndicator(),
                                ],
                                if (auth.profileErrorCode != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: theme
                                              .colorScheme
                                              .onErrorContainer,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            auth.profileErrorMessage ??
                                                l10n.asfcProfileLoadFailed,
                                            style: TextStyle(
                                              color: theme
                                                  .colorScheme
                                                  .onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (fields.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    l10n.asfcProfileInformation,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Card(
                                    child: Column(
                                      children: [
                                        for (
                                          var index = 0;
                                          index < fields.length;
                                          index++
                                        ) ...[
                                          ListTile(
                                            dense: true,
                                            title: Text(fields[index].label),
                                            subtitle: Text(fields[index].value),
                                          ),
                                          if (index < fields.length - 1)
                                            const Divider(height: 1),
                                        ],
                                      ],
                                    ),
                                  ),
                                ] else if (!auth.isProfileLoading &&
                                    auth.profileErrorCode == null) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    l10n.asfcNoProfileInformation,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 20),
                                _CertificateStatusPanel(
                                  auth: auth,
                                  onApply: () => showCertificateApplicationSheet(context),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => showAsfcFlightRecordsSheet(context),
                                  icon: const Icon(Icons.flight_takeoff_outlined),
                                  label: Text(l10n.asfcFlightRecords),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: auth.isLoading
                                      ? null
                                      : AsfcAuthService.instance.logout,
                                  icon: const Icon(Icons.logout),
                                  label: Text(l10n.logout),
                                ),
                              ],
                            );
                          },
                        ),
                      ] else ...[
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment<String>(
                              value: 'password',
                              label: Text(l10n.asfcPasswordLogin),
                              icon: const Icon(Icons.password_outlined),
                            ),
                            ButtonSegment<String>(
                              value: 'sms',
                              label: Text(l10n.asfcSmsLogin),
                              icon: const Icon(Icons.sms_outlined),
                            ),
                          ],
                          selected: {_smsMode ? 'sms' : 'password'},
                          onSelectionChanged:
                              auth.isLoading ||
                                  auth.isCaptchaLoading ||
                                  auth.isSmsCodeLoading
                              ? null
                              : (selection) =>
                                    _setLoginMode(selection.first == 'sms'),
                        ),
                        const SizedBox(height: 20),
                        if (auth.errorCode != null &&
                            auth.errorCode != 'missingCredentials') ...[
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
                                  labelText: _smsMode
                                      ? l10n.asfcMobile
                                      : l10n.asfcUsername,
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? (_smsMode
                                          ? l10n.asfcMobileRequired
                                          : l10n.asfcCredentialsRequired)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              if (!_smsMode)
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
                                        () => _obscurePassword =
                                            !_obscurePassword,
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
                                )
                              else ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 132,
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: theme.colorScheme.outline,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: auth.captchaImageBytes == null
                                          ? Text(l10n.asfcCaptcha)
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              child: Image.memory(
                                                auth.captchaImageBytes!,
                                                width: 132,
                                                height: 52,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => Text(
                                                  l10n.asfcCaptchaLoadFailed,
                                                ),
                                              ),
                                            ),
                                    ),
                                    IconButton(
                                      tooltip: l10n.asfcRefreshCaptcha,
                                      onPressed: auth.isCaptchaLoading
                                          ? null
                                          : _refreshCaptcha,
                                      icon: auth.isCaptchaLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _captchaController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: l10n.asfcCaptcha,
                                    prefixIcon: const Icon(
                                      Icons.verified_outlined,
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? l10n.asfcCaptchaRequired
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _smsCodeController,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode,
                                        ],
                                        onFieldSubmitted: (_) => _login(),
                                        decoration: InputDecoration(
                                          labelText: l10n.asfcSmsCode,
                                          prefixIcon: const Icon(
                                            Icons.sms_outlined,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? l10n.asfcSmsCodeRequired
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed:
                                          auth.isSmsCodeLoading ||
                                              _smsSecondsRemaining > 0
                                          ? null
                                          : _sendSmsCode,
                                      child: auth.isSmsCodeLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              _smsSecondsRemaining > 0
                                                  ? l10n.asfcSmsCountdown(
                                                      _smsSecondsRemaining,
                                                    )
                                                  : l10n.asfcSendSmsCode,
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed:
                                      auth.isLoading ||
                                          auth.isCaptchaLoading ||
                                          auth.isSmsCodeLoading
                                      ? null
                                      : _login,
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
