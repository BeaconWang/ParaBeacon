import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../l10n/app_localizations.dart';

Future<void> showCertificateApplicationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _CertificateApplicationSheet(),
  );
}

class _CertificateApplicationSheet extends StatefulWidget {
  const _CertificateApplicationSheet();

  @override
  State<_CertificateApplicationSheet> createState() =>
      _CertificateApplicationSheetState();
}

class _CertificateApplicationSheetState
    extends State<_CertificateApplicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  String _sex = 'MAN';
  String? _licensePhoto;
  String? _groupPhoto;
  bool _uploadingLicensePhoto = false;
  bool _uploadingGroupPhoto = false;
  bool _submitting = false;
  bool _prefilled = false;

  static const _fieldNames = [
    'fullName',
    'birthday',
    'country',
    'ethnicityCode',
    'credentialsNumber',
    'mobile',
    'email',
    'address',
    'area',
    'agencyName',
    'coachId',
    'urgentContactName',
    'urgentContactPhone',
    'urgentBloodType',
  ];

  @override
  void initState() {
    super.initState();
    for (final name in _fieldNames) {
      _controllers[name] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = AsfcAuthService.instance;
      await auth.load();
      if (auth.isSignedIn) await auth.loadProfile();
      if (mounted) _prefillFromProfile(auth.profile);
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String name) => _controllers[name]!;

  void _prefillFromProfile(Map<String, dynamic>? profile) {
    if (_prefilled || profile == null) return;
    _prefilled = true;
    final values = <String, String>{
      'fullName': _profileValue(profile, ['user', 'realName']) ??
          _profileValue(profile, ['user', 'fullName']) ??
          '',
      'credentialsNumber':
          _profileValue(profile, ['user', 'credentialsNumber']) ?? '',
      'mobile': _profileValue(profile, ['user', 'mobile']) ?? '',
      'email': _profileValue(profile, ['user', 'email']) ?? '',
      'address': _profileValue(profile, ['user', 'address']) ?? '',
    };
    for (final entry in values.entries) {
      if (entry.value.isNotEmpty) _controller(entry.key).text = entry.value;
    }
    setState(() {});
  }

  String? _profileValue(Map<String, dynamic> profile, List<String> path) {
    Object? current = profile;
    for (final part in path) {
      if (current is! Map<String, dynamic>) return null;
      current = current[part];
    }
    return current is String && current.trim().isNotEmpty
        ? current.trim()
        : null;
  }

  String? _required(AppLocalizations l10n, String? value) {
    return value == null || value.trim().isEmpty ? l10n.certificateRequired : null;
  }

  Future<void> _pickPhoto({required bool groupPhoto}) async {
    if (_submitting || _uploadingLicensePhoto || _uploadingGroupPhoto) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    final l10n = AppLocalizations.of(context);
    if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      _showMessage(l10n.certificateImageInvalid);
      return;
    }
    setState(() {
      if (groupPhoto) {
        _uploadingGroupPhoto = true;
      } else {
        _uploadingLicensePhoto = true;
      }
    });
    final url = await AsfcAuthService.instance.uploadCertificateImage(
      bytes: bytes,
      filename: file.name,
    );
    if (!mounted) return;
    setState(() {
      if (groupPhoto) {
        _uploadingGroupPhoto = false;
        _groupPhoto = url;
      } else {
        _uploadingLicensePhoto = false;
        _licensePhoto = url;
      }
    });
    if (url == null) {
      _showMessage(_errorText(l10n, AsfcAuthService.instance));
    }
  }

  String _errorText(AppLocalizations l10n, AsfcAuthService auth) {
    if (auth.errorMessage != null && auth.errorMessage!.trim().isNotEmpty) {
      return auth.errorMessage!;
    }
    switch (auth.errorCode) {
      case 'certificateNotSignedIn':
        return l10n.certificateNotSignedIn;
      case 'certificateImageInvalid':
        return l10n.certificateImageInvalid;
      case 'certificateImageUploadFailed':
        return l10n.certificateImageUploadFailed;
      case 'certificateFieldsRequired':
        return l10n.certificateRequired;
      case 'certificateApplicationFailed':
        return l10n.certificateApplicationFailed;
      default:
        return l10n.asfcConnectionFailed;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting ||
        !(_formKey.currentState?.validate() ?? false) ||
        _licensePhoto == null ||
        _groupPhoto == null) {
      if (_licensePhoto == null || _groupPhoto == null) {
        _showMessage(AppLocalizations.of(context).certificatePhotoRequired);
      }
      return;
    }
    setState(() => _submitting = true);
    final values = {
      for (final name in _fieldNames) name: _controller(name).text.trim(),
    };
    final success = await AsfcAuthService.instance.applyParagliderCertificate(
      licensePhoto: _licensePhoto!,
      fullName: values['fullName']!,
      sex: _sex,
      birthday: values['birthday']!,
      country: values['country']!,
      ethnicityCode: values['ethnicityCode']!,
      credentialsNumber: values['credentialsNumber']!,
      mobile: values['mobile']!,
      email: values['email']!,
      address: values['address']!,
      area: values['area']!,
      agencyName: values['agencyName']!,
      groupPhoto: _groupPhoto!,
      urgentContactName: values['urgentContactName']!,
      urgentContactPhone: values['urgentContactPhone']!,
      urgentBloodType: values['urgentBloodType']!,
      coachId: int.tryParse(values['coachId']!) ?? 0,
      auditTime: _dateString(DateTime.now()),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      _showMessage(AppLocalizations.of(context).certificateApplicationSuccess);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    } else {
      _showMessage(_errorText(AppLocalizations.of(context), AsfcAuthService.instance));
    }
  }

  String _dateString(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon));
  }

  Widget _textField(
    AppLocalizations l10n,
    String name,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? hintText,
    bool required = true,
  }) {
    return TextFormField(
      controller: _controller(name),
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: _decoration(label, icon).copyWith(hintText: hintText),
      validator: required ? (value) => _required(l10n, value) : null,
    );
  }

  Widget _photoTile({required bool groupPhoto}) {
    final l10n = AppLocalizations.of(context);
    final uploading = groupPhoto ? _uploadingGroupPhoto : _uploadingLicensePhoto;
    final uploaded = groupPhoto ? _groupPhoto != null : _licensePhoto != null;
    return OutlinedButton.icon(
      onPressed: uploading ? null : () => _pickPhoto(groupPhoto: groupPhoto),
      icon: uploading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(uploaded ? Icons.check_circle_outline : Icons.upload_file),
      label: Text(
        uploaded
            ? (groupPhoto ? l10n.groupPhotoUploaded : l10n.licensePhotoUploaded)
            : (groupPhoto ? l10n.groupPhoto : l10n.licensePhoto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(child: Text(l10n.certificateApplication, style: theme.textTheme.titleLarge)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  children: [
                    Text(l10n.certificateApplicationSubtitle, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    _textField(l10n, 'fullName', l10n.certificateFullName, Icons.person_outline),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _sex,
                      decoration: _decoration(l10n.certificateGender, Icons.wc_outlined),
                      items: [
                        DropdownMenuItem(value: 'MAN', child: Text(l10n.certificateMale)),
                        DropdownMenuItem(value: 'WOMAN', child: Text(l10n.certificateFemale)),
                      ],
                      onChanged: _submitting ? null : (value) => setState(() => _sex = value ?? 'MAN'),
                    ),
                    const SizedBox(height: 12),
                    _textField(l10n, 'birthday', l10n.certificateBirthday, Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD'),
                    const SizedBox(height: 12),
                    _textField(l10n, 'country', l10n.certificateCountry, Icons.flag_outlined),
                    const SizedBox(height: 12),
                    _textField(l10n, 'ethnicityCode', l10n.certificateEthnicity, Icons.groups_outlined),
                    const SizedBox(height: 12),
                    _textField(l10n, 'credentialsNumber', l10n.certificateIdNumber, Icons.badge_outlined, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _textField(l10n, 'mobile', l10n.certificateMobile, Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _textField(l10n, 'email', l10n.certificateEmail, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _textField(l10n, 'address', l10n.certificateAddress, Icons.home_outlined),
                    const SizedBox(height: 12),
                    _textField(l10n, 'area', l10n.certificateArea, Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    _textField(l10n, 'agencyName', l10n.certificateAgency, Icons.school_outlined),
                    const SizedBox(height: 12),
                    _textField(l10n, 'coachId', l10n.certificateCoachId, Icons.person_search_outlined, keyboardType: TextInputType.number, required: false),
                    const SizedBox(height: 20),
                    Text(l10n.certificateDocuments, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _photoTile(groupPhoto: false),
                    const SizedBox(height: 8),
                    _photoTile(groupPhoto: true),
                    const SizedBox(height: 20),
                    Text(l10n.certificateEmergencyContact, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _textField(l10n, 'urgentContactName', l10n.certificateContactName, Icons.contact_phone_outlined),
                    const SizedBox(height: 12),
                    _textField(l10n, 'urgentContactPhone', l10n.certificateContactPhone, Icons.phone_callback_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _textField(l10n, 'urgentBloodType', l10n.certificateBloodType, Icons.bloodtype_outlined),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _submitting || _uploadingLicensePhoto || _uploadingGroupPhoto ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_outlined),
                      label: Text(_submitting ? l10n.submitting : l10n.submitApplication),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
