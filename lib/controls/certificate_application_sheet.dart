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
  String _credentialsType = 'ID_CARD';
  String? _licensePhoto;
  String? _groupPhoto;
  List<AsfcCoach> _coaches = const [];
  AsfcCoach? _selectedCoach;
  int _certificateId = 0;
  String _licenseNo = '';
  String _auditTime = '';
  String _licenseValidStart = '';
  String _licenseValidEnd = '';
  String _areaCode = '';
  bool _uploadingLicensePhoto = false;
  bool _uploadingGroupPhoto = false;
  bool _loadingExistingData = true;
  bool _loadingCoaches = true;
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
      if (auth.isSignedIn) {
        await Future.wait([
          auth.loadProfile(),
          auth.loadCertificateApplication(),
          auth.loadCertificateCoaches(),
        ]);
      }
      if (!mounted) return;
      _prefillFromSources(
        profile: auth.profile,
        application: auth.certificateApplication,
      );
      setState(() {
        _coaches = auth.certificateCoaches;
        _loadingExistingData = false;
        _loadingCoaches = auth.isCertificateCoachesLoading;
        _selectCoachById();
      });
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

  void _prefillFromSources({
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? application,
  }) {
    if (_prefilled) return;
    _prefilled = true;

    String value(String key, {List<List<String>> profilePaths = const []}) {
      final applicationValue = _stringValue(application?[key]);
      if (applicationValue != null) return applicationValue;
      for (final path in profilePaths) {
        final profileValue = _profileValue(profile, path);
        if (profileValue != null) return profileValue;
      }
      return '';
    }

    final values = <String, String>{
      'fullName': value(
        'fullName',
        profilePaths: const [
          ['user', 'realName'],
          ['user', 'fullName'],
        ],
      ),
      'birthday': value('birthday', profilePaths: const [['user', 'birthday']]),
      'country': value('country', profilePaths: const [['user', 'country']]),
      'ethnicityCode': value(
        'ethnicityCode',
        profilePaths: const [['user', 'ethnicityCode'], ['user', 'nation']],
      ),
      'credentialsNumber': value(
        'credentialsNumber',
        profilePaths: const [['user', 'credentialsNumber'], ['user', 'idCard']],
      ),
      'mobile': value('mobile', profilePaths: const [['user', 'mobile']]),
      'email': value('email', profilePaths: const [['user', 'email']]),
      'address': value('address', profilePaths: const [['user', 'address']]),
      'area': value('area', profilePaths: const [['user', 'area']]),
      'agencyName': value(
        'agencyName',
        profilePaths: const [['user', 'agencyName']],
      ),
      'urgentContactName': value(
        'urgentContactName',
        profilePaths: const [['user', 'urgentContactName']],
      ),
      'urgentContactPhone': value(
        'urgentContactPhone',
        profilePaths: const [['user', 'urgentContactPhone']],
      ),
      'urgentBloodType': value(
        'urgentBloodType',
        profilePaths: const [['user', 'urgentBloodType']],
      ),
    };
    for (final entry in values.entries) {
      if (entry.value.isNotEmpty) _controller(entry.key).text = entry.value;
    }

    final sex = value(
      'sex',
      profilePaths: const [['user', 'gender'], ['user', 'sex']],
    );
    if (sex == 'MAN' || sex == '男') {
      _sex = 'MAN';
    } else if (sex == 'WOMAN' || sex == '女') {
      _sex = 'WOMAN';
    }
    _credentialsType = value('credentialsType');
    if (_credentialsType.isEmpty) _credentialsType = 'ID_CARD';
    _certificateId = int.tryParse(value('id')) ?? 0;
    _licenseNo = value('licenseNo');
    _auditTime = value('auditTime');
    _licenseValidStart = value('licenseValidStart');
    _licenseValidEnd = value('licenseValidEnd');
    _areaCode = value('areaCode');
    _licensePhoto = _safeImageValue(value('licensePhoto'));
    _groupPhoto = _safeImageValue(value('groupPhoto'));
    final coachId = int.tryParse(value('coachId')) ?? 0;
    if (coachId > 0) _selectedCoach = AsfcCoach(id: coachId, name: value('coachName'));
  }

  String? _profileValue(Map<String, dynamic>? profile, List<String> path) {
    Object? current = profile;
    for (final part in path) {
      if (current is! Map<String, dynamic>) return null;
      current = current[part];
    }
    return _stringValue(current);
  }

  String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return null;
  }

  String? _safeImageValue(String value) {
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (value.startsWith('/') ||
        (uri != null && uri.scheme == 'https' && uri.host == 'upload.57fly.com')) {
      return value;
    }
    return null;
  }

  void _selectCoachById() {
    final selectedId = _selectedCoach?.id;
    if (selectedId == null) return;
    for (final coach in _coaches) {
      if (coach.id == selectedId) {
        _selectedCoach = coach;
        return;
      }
    }
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
      licenseNo: _licenseNo,
      auditTime: _auditTime,
      licenseValidStart: _licenseValidStart,
      licenseValidEnd: _licenseValidEnd,
      areaCode: _areaCode,
      credentialsType: _credentialsType,
      parasailLicenseId: _certificateId,
      coachId: _selectedCoach?.id ?? 0,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      final l10n = AppLocalizations.of(context);
      await AsfcAuthService.instance.loadCertificateApplication(force: true);
      if (!mounted) return;
      _showMessage(l10n.certificateApplicationSuccess);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    } else {
      _showMessage(_errorText(AppLocalizations.of(context), AsfcAuthService.instance));
    }
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

  Widget _coachField(AppLocalizations l10n) {
    final selected = _selectedCoach;
    final coaches = [..._coaches];
    if (selected != null && !coaches.any((coach) => coach.id == selected.id)) {
      coaches.insert(0, selected);
    }
    return DropdownButtonFormField<AsfcCoach>(
      initialValue: selected,
      isExpanded: true,
      decoration: _decoration(l10n.certificateCoach, Icons.person_search_outlined),
      hint: Text(
        _loadingCoaches
            ? l10n.certificateCoachesLoading
            : l10n.certificateCoachSelect,
      ),
      items: coaches
          .map(
            (coach) => DropdownMenuItem<AsfcCoach>(
              value: coach,
              child: Text(_coachLabel(coach), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _submitting || _loadingCoaches
          ? null
          : (coach) => setState(() => _selectedCoach = coach),
    );
  }

  String _coachLabel(AsfcCoach coach) {
    final details = [
      if (coach.agencyName.isNotEmpty) coach.agencyName,
      if (coach.level.isNotEmpty) coach.level,
    ];
    return details.isEmpty ? coach.name : '${coach.name} · ${details.join(' / ')}';
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
                    if (_loadingExistingData || _loadingCoaches) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
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
                    _coachField(l10n),
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
