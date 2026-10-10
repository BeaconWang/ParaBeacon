import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../l10n/app_localizations.dart';
import 'asfc_flight_records_sheet.dart';
import 'certificate_application_sheet.dart';

Future<void> showAsfcCertificateDetailsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _AsfcCertificateDetailsSheet(),
  );
}

Future<void> showAsfcCertificateSigninsSheet(
  BuildContext context, {
  required String sportCode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => _AsfcCertificateSigninsSheet(sportCode: sportCode),
  );
}

class _AsfcCertificateDetailsSheet extends StatelessWidget {
  const _AsfcCertificateDetailsSheet();

  String? _value(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return null;
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final auth = AsfcAuthService.instance;
    final certificate =
        auth.certificateApplication ?? const <String, dynamic>{};
    final status = auth.certificateStatus;
    final sportCode =
        status.sportCode ?? _value(certificate, ['sportCode']) ?? '—';
    final level = status.level ?? _value(certificate, ['level']) ?? '—';
    final photoUrl = auth.avatarUrl;
    final validity = [
      status.licenseValidStart ??
          _value(certificate, ['licenseValidStart', 'startTime']),
      status.licenseValidEnd ??
          _value(certificate, ['licenseValidEnd', 'endTime']),
    ].whereType<String>().toList();
    final details = <(String, String?)>[
      (
        l10n.certificateFullName,
        status.fullName ?? _value(certificate, ['fullName']),
      ),
      (
        l10n.certificateGender,
        status.sexName ?? _value(certificate, ['sexName', 'sex']),
      ),
      (
        l10n.certificateBirthday,
        status.birthday ?? _value(certificate, ['birthday']),
      ),
      (l10n.certificateCountry, _value(certificate, ['country'])),
      (
        l10n.certificateEthnicity,
        _value(certificate, ['ethnicityName', 'ethnicityCode', 'nation']),
      ),
      (
        l10n.certificateNumber,
        status.licenseNo ?? _value(certificate, ['licenseNo']),
      ),
      (
        l10n.certificateValidityStatus,
        status.licenseStatusName ?? _value(certificate, ['licenseStatusName']),
      ),
      (
        l10n.certificateValidity,
        validity.isEmpty ? null : validity.join(' – '),
      ),
      (
        l10n.certificateIssueDate,
        _value(certificate, ['auditTime', 'issueTime']),
      ),
      (l10n.certificateIdNumber, _value(certificate, ['credentialsNumber'])),
      (l10n.certificateMobile, _value(certificate, ['mobile'])),
      (l10n.certificateEmail, _value(certificate, ['email'])),
      (l10n.certificateAddress, _value(certificate, ['address'])),
      (l10n.certificateArea, _value(certificate, ['area', 'cityName'])),
      (l10n.certificateAgency, _value(certificate, ['agencyName'])),
      (l10n.certificateCoach, _value(certificate, ['coachName'])),
    ];
    final emergency = <(String, String?)>[
      (l10n.certificateContactName, _value(certificate, ['urgentContactName'])),
      (
        l10n.certificateContactPhone,
        _value(certificate, ['urgentContactPhone']),
      ),
      (l10n.certificateBloodType, _value(certificate, ['urgentBloodType'])),
    ];

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            _CertificateSheetHeader(title: l10n.certificateDetails),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  _CertificateDetailRow(
                    label: l10n.certificatePhoto,
                    value: '',
                    trailing: photoUrl == null
                        ? CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                        : CircleAvatar(backgroundImage: NetworkImage(photoUrl)),
                    height: 72,
                  ),
                  for (final row in details)
                    if (row.$2 != null)
                      _CertificateDetailRow(label: row.$1, value: row.$2!),
                  _CertificateDetailRow(
                    label: l10n.certificateLevel,
                    value: level,
                    trailing: Text('${l10n.certificateSportCode}: $sportCode'),
                  ),
                  if (_value(certificate, ['groupPhoto']) != null) ...[
                    _sectionTitle(context, l10n.certificateDocuments),
                    _CertificateDocumentRow(
                      label: l10n.groupPhoto,
                      imageUrl: _value(certificate, ['groupPhoto'])!,
                    ),
                  ],
                  if (emergency.any((row) => row.$2 != null)) ...[
                    _sectionTitle(context, l10n.certificateEmergencyContact),
                    for (final row in emergency)
                      if (row.$2 != null)
                        _CertificateDetailRow(label: row.$1, value: row.$2!),
                  ],
                  const SizedBox(height: 12),
                  _CertificateActionRow(
                    icon: Icons.flight_takeoff_outlined,
                    title: l10n.asfcFlightRecords,
                    onTap: () => showAsfcFlightRecordsSheet(context),
                  ),
                  _CertificateActionRow(
                    icon: Icons.upgrade,
                    title: l10n.certificateUpgrade,
                    onTap: () =>
                        showCertificateApplicationSheet(context, upgrade: true),
                  ),
                  _CertificateActionRow(
                    icon: Icons.list_alt_outlined,
                    title: l10n.certificateSignInList,
                    onTap: () => showAsfcCertificateSigninsSheet(
                      context,
                      sportCode: sportCode,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsfcCertificateSigninsSheet extends StatefulWidget {
  const _AsfcCertificateSigninsSheet({required this.sportCode});

  final String sportCode;

  @override
  State<_AsfcCertificateSigninsSheet> createState() =>
      _AsfcCertificateSigninsSheetState();
}

class _AsfcCertificateSigninsSheetState
    extends State<_AsfcCertificateSigninsSheet> {
  final _auth = AsfcAuthService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  Future<void> _loadRecords() async {
    final request = _auth.loadFlightRecords(force: true);
    if (mounted) setState(() {});
    await request;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final records = _auth.flightRecords;
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            _CertificateSheetHeader(
              title: l10n.certificateSignInList,
              action: IconButton(
                tooltip: l10n.refresh,
                onPressed: _auth.isFlightRecordsLoading ? null : _loadRecords,
                icon: const Icon(Icons.refresh),
              ),
            ),
            const Divider(height: 1),
            if (_auth.isFlightRecordsLoading) const LinearProgressIndicator(),
            if (records.isEmpty && !_auth.isFlightRecordsLoading)
              Expanded(child: Center(child: Text(l10n.certificateNoSignIns)))
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 560,
                    child: Column(
                      children: [
                        Container(
                          color: theme.colorScheme.primaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              _SignInCell(
                                l10n.certificateSportCode,
                                flex: 3,
                                header: true,
                              ),
                              _SignInCell(
                                l10n.certificateSignInDate,
                                flex: 3,
                                header: true,
                              ),
                              _SignInCell(
                                l10n.certificateCoach,
                                flex: 2,
                                header: true,
                              ),
                              _SignInCell(
                                l10n.certificateReviewUnit,
                                flex: 2,
                                header: true,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: records.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final record = records[index];
                              return SizedBox(
                                height: 52,
                                child: Row(
                                  children: [
                                    _SignInCell(widget.sportCode, flex: 3),
                                    _SignInCell(record.trainTime, flex: 3),
                                    _SignInCell(record.coachName, flex: 2),
                                    _SignInCell(
                                      record.reviewerName.isEmpty
                                          ? '—'
                                          : record.reviewerName,
                                      flex: 2,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CertificateSheetHeader extends StatelessWidget {
  const _CertificateSheetHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).close,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          ?action,
        ],
      ),
    );
  }
}

class _CertificateDetailRow extends StatelessWidget {
  const _CertificateDetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.height = 42,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

class _CertificateDocumentRow extends StatelessWidget {
  const _CertificateDocumentRow({required this.label, required this.imageUrl});

  final String label;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl);
    final image = uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
        ? Image.network(
            imageUrl,
            width: 48,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          )
        : const Icon(Icons.image_outlined, size: 36);
    return _CertificateDetailRow(
      label: label,
      value: '',
      height: 76,
      trailing: ClipRRect(borderRadius: BorderRadius.circular(4), child: image),
    );
  }
}

class _CertificateActionRow extends StatelessWidget {
  const _CertificateActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SignInCell extends StatelessWidget {
  const _SignInCell(this.value, {required this.flex, this.header = false});

  final String value;
  final int flex;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: header
              ? theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
