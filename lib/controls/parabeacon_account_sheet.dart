import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/live_tracking_service.dart' as server_tracking;
import '../data/parabeacon_account_service.dart';
import '../data/pilot_avatar.dart';
import '../data/profile_image_url.dart';
import '../l10n/app_localizations.dart';
import 'app_notice.dart';
import 'profile_details_page.dart';
import 'profile_image_crop_page.dart';
import 'profile_image_preview.dart';

Future<void> showParaBeaconAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _ParaBeaconAccountSheet(),
  );
}

class _ParaBeaconAccountSheet extends StatefulWidget {
  const _ParaBeaconAccountSheet();

  @override
  State<_ParaBeaconAccountSheet> createState() =>
      _ParaBeaconAccountSheetState();
}

class _ParaBeaconAccountSheetState extends State<_ParaBeaconAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _savingProfileImage = false;
  bool _registering = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    ParaBeaconAccountService.instance.load();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final service = ParaBeaconAccountService.instance;
    if (_registering) {
      await service.register(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      await service.login(
        identifier: _usernameController.text,
        password: _passwordController.text,
      );
    }
  }

  Future<void> _pickProfileImage(
    ParaBeaconAccountService service,
    AppLocalizations l10n,
  ) async {
    if (_savingProfileImage || service.isBusy) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
    } on Object {
      if (mounted) {
        AppNotice.show(l10n.accountErrorService);
      }
      return;
    }
    if (!mounted || result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null ||
        bytes.isEmpty ||
        bytes.length > ParaBeaconAccountService.maxProfileImageSourceBytes) {
      AppNotice.show(l10n.accountInvalidProfileImage);
      return;
    }
    final croppedBytes = await ProfileImageCropPage.edit(
      context,
      imageBytes: Uint8List.fromList(bytes),
      title: l10n.accountCropProfileImage,
      instructions: l10n.accountCropInstructions,
      cropAction: l10n.accountCropAndUpload,
      cancelLabel: l10n.cancel,
      invalidImageMessage: l10n.accountInvalidProfileImage,
    );
    if (!mounted || croppedBytes == null) return;
    setState(() => _savingProfileImage = true);
    final saved = await service.uploadProfileImage(bytes: croppedBytes);
    if (!mounted) return;
    setState(() => _savingProfileImage = false);
    if (saved) {
      AppNotice.show(l10n.accountProfileImageSaved);
    }
  }

  Future<bool> _downloadProfileImage(String imageUrl) async {
    final imageUri = ProfileImageUrl.resolve(imageUrl);
    if (imageUri == null) return false;
    try {
      final response = await http
          .get(imageUri)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          response.bodyBytes.length >
              ParaBeaconAccountService.maxProfileImageUploadBytes) {
        return false;
      }
      final directory = await getTemporaryDirectory();
      final fileName = 'parabeacon-profile-${imageUri.pathSegments.last}.jpg';
      final file = File(p.join(directory.path, fileName));
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) return false;
      await Gal.putImage(file.path, album: 'ParaBeacon');
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _showProfileImagePreview(
    ParaBeaconAccountService service,
    AppLocalizations l10n,
  ) async {
    final imageUrl = service.user?.profileImageUrl;
    if (imageUrl == null) return;
    await showProfileImagePreview(
      context,
      imageUrl: imageUrl,
      title: l10n.accountProfileImage,
      closeLabel: l10n.close,
      changeLabel: l10n.accountChangeProfileImage,
      resetLabel: l10n.accountResetProfileImage,
      downloadLabel: l10n.accountDownloadProfileImage,
      downloadingLabel: l10n.accountDownloadingProfileImage,
      downloadSuccessLabel: l10n.accountProfileImageDownloaded,
      downloadFailedLabel: l10n.accountProfileImageDownloadFailed,
      onChange: () => _pickProfileImage(service, l10n),
      onReset: () => _removeProfileImage(service, l10n),
      onDownload: () => _downloadProfileImage(imageUrl),
    );
  }

  Future<void> _removeProfileImage(
    ParaBeaconAccountService service,
    AppLocalizations l10n,
  ) async {
    if (_savingProfileImage || service.isBusy) return;
    setState(() => _savingProfileImage = true);
    final removed = await service.removeProfileImage();
    if (!mounted) return;
    setState(() => _savingProfileImage = false);
    if (removed) {
      AppNotice.show(l10n.accountProfileImageRemoved);
    }
  }

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
    'accountInvalidCredentials' => l10n.accountErrorInvalidCredentials,
    'accountAlreadyExists' => l10n.accountErrorAlreadyExists,
    'accountInvalidInput' => l10n.accountErrorInvalidInput,
    'accountInvalidDisplayName' => l10n.accountDisplayNameInvalid,
    'accountInvalidProfileImage' => l10n.accountInvalidProfileImage,
    'accountCurrentPasswordIncorrect' => l10n.accountCurrentPasswordIncorrect,
    'accountSessionExpired' => l10n.accountSessionExpired,
    'accountPasswordUnchanged' => l10n.accountPasswordUnchanged,
    'accountConnectionFailure' => l10n.accountErrorConnection,
    'accountStorageFailure' => l10n.accountErrorStorage,
    'accountServiceUnavailable' ||
    'accountRequestFailed' => l10n.accountErrorService,
    _ => l10n.accountErrorService,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: ParaBeaconAccountService.instance,
      builder: (context, _) {
        final service = ParaBeaconAccountService.instance;
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
                          l10n.paraBeaconAccount,
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
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                Icons.account_circle_outlined,
                                size: 72,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.paraBeaconAccount,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.paraBeaconAccountSubtitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 28),
                              if (service.isLoading && !service.isLoaded)
                                const Center(child: CircularProgressIndicator())
                              else if (service.isSignedIn)
                                _buildProfile(context, service, l10n)
                              else
                                _buildForm(context, service, l10n),
                              if (kDebugMode) ...[
                                const SizedBox(height: 24),
                                _AccountDebugLogPanel(lines: service.debugLog),
                              ],
                            ],
                          ),
                        ),
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

  Widget _buildProfile(
    BuildContext context,
    ParaBeaconAccountService service,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final user = service.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Tooltip(
                  message: user?.profileImageUrl == null
                      ? l10n.accountChangeProfileImage
                      : l10n.accountProfileImage,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(23),
                      onTap: service.isBusy || _savingProfileImage
                          ? null
                          : user?.profileImageUrl == null
                          ? () => _pickProfileImage(service, l10n)
                          : () => _showProfileImagePreview(service, l10n),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PilotAvatarPicture(
                            avatarId: user?.avatarId ?? 0,
                            profileImageUrl: user?.profileImageUrl,
                            size: 96,
                          ),
                          PositionedDirectional(
                            bottom: -4,
                            end: -4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.accountProfileImage,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.username ?? l10n.accountSignedIn,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.accountSignedIn,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileDetailsPage(
                        account: service,
                        onChangeProfileImage: () =>
                            _pickProfileImage(service, l10n),
                        onOpenProfileImage: () =>
                            _showProfileImagePreview(service, l10n),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline),
                  label: Text(l10n.accountProfileDetailsButton),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 6),
                  Text(user!.email!),
                ],
                if (user?.createdAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.accountMemberSince}: ${MaterialLocalizations.of(context).formatMediumDate(user!.createdAt!.toLocal())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (service.errorCode != null) ...[
          const SizedBox(height: 12),
          _errorPanel(context, _errorText(l10n, service.errorCode!)),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: service.isLoading || _signingOut
              ? null
              : () async {
                  setState(() => _signingOut = true);
                  try {
                    await server_tracking.LiveTrackingService.instance
                        .closeForSignOut();
                  } finally {
                    await service.logout();
                    if (mounted) setState(() => _signingOut = false);
                  }
                },
          icon: _signingOut
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: Text(l10n.accountSignOut),
        ),
      ],
    );
  }

  Widget _buildForm(
    BuildContext context,
    ParaBeaconAccountService service,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.accountSignIn)),
            ButtonSegment(value: true, label: Text(l10n.accountCreate)),
          ],
          selected: {_registering},
          onSelectionChanged: service.isLoading
              ? null
              : (selection) {
                  setState(() => _registering = selection.first);
                  service.clearError();
                },
        ),
        const SizedBox(height: 20),
        if (service.errorCode != null) ...[
          _errorPanel(context, _errorText(l10n, service.errorCode!)),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameController,
                  keyboardType: _registering
                      ? TextInputType.text
                      : TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: _registering
                      ? const [AutofillHints.newUsername]
                      : const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: _registering
                        ? l10n.accountUsername
                        : l10n.accountIdentifier,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return l10n.accountUsernameRequired;
                    if (_registering &&
                        (text.runes.length < 3 || text.runes.length > 32)) {
                      return l10n.accountUsernameLength;
                    }
                    if (!_registering && text.length > 254) {
                      return l10n.accountErrorInvalidInput;
                    }
                    return null;
                  },
                ),
                if (_registering) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: l10n.accountEmailOptional,
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return null;
                      if (email.length > 254 ||
                          !RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(email)) {
                        return l10n.accountEmailInvalid;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: _registering
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autofillHints: _registering
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
                  onFieldSubmitted: _registering ? null : (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.accountPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? l10n.showPassword
                          : l10n.hidePassword,
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) return l10n.accountPasswordRequired;
                    if (_registering && password.runes.length < 6) {
                      return l10n.accountPasswordMinimum;
                    }
                    if (utf8.encode(password).length > 72) {
                      return l10n.accountPasswordMaximum;
                    }
                    return null;
                  },
                ),
                if (_registering) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmationController,
                    obscureText: _obscureConfirmation,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l10n.accountConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmation
                            ? l10n.showPassword
                            : l10n.hidePassword,
                        onPressed: () => setState(
                          () => _obscureConfirmation = !_obscureConfirmation,
                        ),
                        icon: Icon(
                          _obscureConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value != _passwordController.text
                        ? l10n.accountPasswordMismatch
                        : null,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: service.isLoading ? null : _submit,
                    icon: service.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _registering ? Icons.person_add_alt : Icons.login,
                          ),
                    label: Text(
                      service.isLoading
                          ? l10n.accountPleaseWait
                          : _registering
                          ? l10n.accountCreate
                          : l10n.accountSignIn,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.accountSecureSession,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorPanel(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDebugLogPanel extends StatelessWidget {
  const _AccountDebugLogPanel({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.bug_report_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Debug log (${lines.length})',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 180,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: lines.isEmpty
              ? Center(
                  child: Text(
                    'No account activity yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: lines.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(
                      lines[lines.length - index - 1],
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
