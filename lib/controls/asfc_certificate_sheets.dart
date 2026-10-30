import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../data/user_agent_settings.dart';
import '../l10n/app_localizations.dart';
import 'certificate_application_sheet.dart';
import 'pilot_training_records_sheet.dart';
import 'desktop_scrolling.dart';

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

class _AsfcCertificateDetailsSheet extends StatefulWidget {
  const _AsfcCertificateDetailsSheet();

  @override
  State<_AsfcCertificateDetailsSheet> createState() =>
      _AsfcCertificateDetailsSheetState();
}

class _AsfcCertificateDetailsSheetState
    extends State<_AsfcCertificateDetailsSheet> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

  Widget _buildModeSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _buildModeButton(
            title: l10n.certificateDetailsView,
            icon: Icons.list_alt_outlined,
            index: 0,
          ),
          const SizedBox(width: 8),
          _buildModeButton(
            title: l10n.certificateCardView,
            icon: Icons.badge_outlined,
            index: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final theme = Theme.of(context);
    final selected = _page == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: Material(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
            ),
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      (l10n.certificateArea, _value(certificate, ['cityName'])),
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
            _buildModeSelector(l10n),
            const Divider(height: 1),
            Expanded(
              child: ScrollConfiguration(
                behavior: const MouseDragScrollBehavior(),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _page = index),
                  children: [
                    ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        _CertificateDetailRow(
                          label: l10n.certificatePhoto,
                          value: '',
                          trailing: photoUrl == null
                              ? CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.person,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    photoUrl,
                                    headers: UserAgentSettings
                                        .instance
                                        .requestHeaders,
                                  ),
                                ),
                          height: 72,
                        ),
                        for (final row in details)
                          if (row.$2 != null)
                            _CertificateDetailRow(
                              label: row.$1,
                              value: row.$2!,
                            ),
                        _CertificateDetailRow(
                          label: l10n.certificateLevel,
                          value: level,
                          trailing: Text(
                            '${l10n.certificateSportCode}: $sportCode',
                          ),
                        ),
                        if (_value(certificate, ['groupPhoto']) != null) ...[
                          _sectionTitle(context, l10n.certificateDocuments),
                          _CertificateDocumentRow(
                            label: l10n.certificateGroupPhotoWithCoach,
                            imageUrl: _value(certificate, ['groupPhoto'])!,
                          ),
                        ],
                        if (emergency.any((row) => row.$2 != null)) ...[
                          _sectionTitle(
                            context,
                            l10n.certificateEmergencyContact,
                          ),
                          for (final row in emergency)
                            if (row.$2 != null)
                              _CertificateDetailRow(
                                label: row.$1,
                                value: row.$2!,
                              ),
                        ],
                        const SizedBox(height: 12),
                        _CertificateActionRow(
                          icon: Icons.school_outlined,
                          title: l10n.pilotTrainingRecords,
                          onTap: () => showPilotTrainingRecordsSheet(context),
                        ),
                        _CertificateActionRow(
                          icon: Icons.upgrade,
                          title: l10n.certificateUpgrade,
                          onTap: () => showCertificateApplicationSheet(
                            context,
                            upgrade: true,
                          ),
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: _CertificateCardPreview(
                                photoUrl: photoUrl,
                                area: _value(certificate, ['cityName']),
                                title: l10n.certificateCardTitle,
                                fullName:
                                    status.fullName ??
                                    _value(certificate, ['fullName']),
                                gender:
                                    status.sexName ??
                                    _value(certificate, ['sexName', 'sex']),
                                birthday:
                                    status.birthday ??
                                    _value(certificate, ['birthday']),
                                country: _value(certificate, ['country']),
                                licenseNo:
                                    status.licenseNo ??
                                    _value(certificate, ['licenseNo']),
                                validityStatus:
                                    status.licenseStatusName ??
                                    _value(certificate, ['licenseStatusName']),
                                level: level,
                                sportCode: sportCode,
                                l10n: l10n,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l10n.certificateSwipeHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _AsfcLogoMark extends StatelessWidget {
  const _AsfcLogoMark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 1.92,
      height: height,
      child: CustomPaint(painter: _AsfcLogoPainter(const Color(0xFF168BC7))),
    );
  }
}

class _AsfcLogoPainter extends CustomPainter {
  const _AsfcLogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 60);
    final paint = Paint()..color = color;
    final mark = Path()
      ..moveTo(60, 2)
      ..cubicTo(64, 17, 69, 21, 80, 22)
      ..lineTo(118, 22)
      ..lineTo(108, 31)
      ..lineTo(81, 31)
      ..cubicTo(72, 31, 65, 37, 60, 53)
      ..cubicTo(55, 37, 48, 31, 39, 31)
      ..lineTo(12, 31)
      ..lineTo(2, 22)
      ..lineTo(40, 22)
      ..cubicTo(51, 21, 56, 17, 60, 2)
      ..close();
    canvas.drawPath(mark, paint);
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final stripe = Path()
      ..moveTo(13, 26)
      ..lineTo(39, 26)
      ..cubicTo(48, 26, 55, 29, 60, 38)
      ..cubicTo(65, 29, 72, 26, 81, 26)
      ..lineTo(107, 26);
    canvas.drawPath(stripe, stripePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AsfcLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CertificateCardPreview extends StatelessWidget {
  const _CertificateCardPreview({
    required this.photoUrl,
    required this.area,
    required this.title,
    required this.fullName,
    required this.gender,
    required this.birthday,
    required this.country,
    required this.licenseNo,
    required this.validityStatus,
    required this.level,
    required this.sportCode,
    required this.l10n,
  });

  final String? photoUrl;
  final String? area;
  final String title;
  final String? fullName;
  final String? gender;
  final String? birthday;
  final String? country;
  final String? licenseNo;
  final String? validityStatus;
  final String level;
  final String sportCode;
  final AppLocalizations l10n;

  Widget _field(
    String label,
    String? value,
    double labelFontSize,
    double valueFontSize, {
    bool emphasized = false,
    bool scaleToFit = false,
  }) {
    final field = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: TextStyle(
              color: const Color(0xFF737B83),
              fontSize: labelFontSize,
            ),
          ),
          TextSpan(
            text: value?.isNotEmpty == true ? value : '—',
            style: TextStyle(
              color: const Color(0xFF30363B),
              fontSize: valueFontSize,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      overflow: scaleToFit ? TextOverflow.visible : TextOverflow.ellipsis,
    );
    if (!scaleToFit) return field;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: field,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pad = width * 0.032;
        final labelFontSize = (width * 0.024).clamp(9.0, 22.0).toDouble();
        final valueFontSize = (width * 0.032).clamp(11.0, 29.0).toDouble();
        final portraitWidth = width * 0.16;
        final portraitHeight = width / 2.02 * 0.46;
        final imageUri = Uri.tryParse(photoUrl ?? '');
        final portrait =
            imageUri != null &&
                (imageUri.scheme == 'http' || imageUri.scheme == 'https')
            ? Image.network(
                photoUrl!,
                headers: UserAgentSettings.instance.requestHeaders,
                width: portraitWidth,
                height: portraitHeight,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
              )
            : const Center(child: Icon(Icons.person_outline));
        final status = validityStatus?.trim();

        return AspectRatio(
          aspectRatio: 2.02,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: LayoutBuilder(
                builder: (context, cardConstraints) {
                  final cardWidth = cardConstraints.maxWidth;
                  final cardHeight = cardConstraints.maxHeight;
                  return Stack(
                    children: [
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Color(0xFFF5FAFC)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: cardWidth * 0.1,
                        top: cardHeight * 0.29,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.055,
                            child: _AsfcLogoMark(height: cardHeight * 0.34),
                          ),
                        ),
                      ),
                      Positioned(
                        right: cardWidth * 0.17,
                        top: cardHeight * 0.59,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.055,
                            child: Text(
                              'ASFC',
                              style: TextStyle(
                                color: const Color(0xFF168BC7),
                                fontSize: cardHeight * 0.19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          pad,
                          pad * 0.7,
                          pad,
                          cardHeight * 0.19 + pad * 0.35,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: cardHeight * 0.26,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: cardWidth * 0.16,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _AsfcLogoMark(
                                          height: cardHeight * 0.105,
                                        ),
                                        Text(
                                          'ASFC',
                                          style: TextStyle(
                                            color: const Color(0xFF176CA8),
                                            fontSize: cardHeight * 0.044,
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                          ),
                                        ),
                                        Text(
                                          'AERO SPORTS FEDERATION OF CHINA',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: const Color(0xFF4282A9),
                                            fontSize: (cardHeight * 0.013)
                                                .clamp(5.0, 8.0),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: pad * 0.7),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFF176CA8),
                                          fontSize: (width * 0.037)
                                              .clamp(12.0, 36.0)
                                              .toDouble(),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (status != null && status.isNotEmpty) ...[
                                    SizedBox(width: pad * 0.7),
                                    Text(
                                      status,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: const Color(0xFF168BC7),
                                        fontSize: labelFontSize,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: cardWidth * 0.16,
                                    height: cardHeight * 0.46,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6EEF2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: portrait,
                                  ),
                                  SizedBox(width: pad * 0.7),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _field(
                                          l10n.certificateFullName,
                                          fullName,
                                          labelFontSize,
                                          valueFontSize,
                                          emphasized: true,
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _field(
                                                l10n.certificateGender,
                                                gender,
                                                labelFontSize,
                                                valueFontSize,
                                              ),
                                            ),
                                            SizedBox(width: pad * 0.4),
                                            Expanded(
                                              child: _field(
                                                l10n.certificateCountry,
                                                country,
                                                labelFontSize,
                                                valueFontSize,
                                              ),
                                            ),
                                          ],
                                        ),
                                        _field(
                                          l10n.certificateBirthday,
                                          birthday,
                                          labelFontSize,
                                          valueFontSize,
                                        ),
                                        _field(
                                          l10n.certificateNumber,
                                          licenseNo,
                                          labelFontSize,
                                          valueFontSize,
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _field(
                                                l10n.certificateSportCode,
                                                sportCode,
                                                labelFontSize,
                                                valueFontSize,
                                              ),
                                            ),
                                            SizedBox(width: pad * 0.4),
                                            Expanded(
                                              child: _field(
                                                l10n.certificateArea,
                                                area,
                                                labelFontSize,
                                                valueFontSize,
                                                scaleToFit: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: pad * 0.6),
                                  SizedBox(
                                    width: cardWidth * 0.12,
                                    child: FittedBox(
                                      child: Icon(
                                        Icons.qr_code_2,
                                        color: const Color(0xFF374047),
                                        size: cardHeight * 0.43,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: cardHeight * 0.19,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: pad),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF50C6E9), Color(0xFF348FEA)],
                            ),
                            border: Border(
                              top: BorderSide(
                                color: Color(0xFF8AE3F0),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${l10n.certificateLevel}: $level',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: valueFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
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

  String? get _resolvedImageUrl {
    final value = imageUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) {
      if (uri.scheme != 'https' ||
          uri.host != 'upload.57fly.com' ||
          uri.port != 443 ||
          uri.userInfo.isNotEmpty) {
        return null;
      }
      return uri.toString();
    }
    if (!value.startsWith('/') || value.startsWith('//')) return null;
    return Uri.parse('https://upload.57fly.com').resolve(value).toString();
  }

  Future<void> _showImagePreview(BuildContext context, String imageUrl) {
    final screenSize = MediaQuery.sizeOf(context);
    final l10n = AppLocalizations.of(context);
    final dialogWidth = (screenSize.width - 40).clamp(0.0, 1100.0).toDouble();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xF20B1018),
        insetPadding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 1100),
        child: SizedBox(
          width: dialogWidth,
          height: screenSize.height * 0.82,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.network(
                  imageUrl,
                  headers: UserAgentSettings.instance.requestHeaders,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    final expectedBytes = loadingProgress.expectedTotalBytes;
                    return Center(
                      child: CircularProgressIndicator(
                        value: expectedBytes == null
                            ? null
                            : loadingProgress.cumulativeBytesLoaded /
                                  expectedBytes,
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = _resolvedImageUrl;
    final isNetworkImage = resolvedImageUrl != null;
    final imageWidth = (MediaQuery.sizeOf(context).width * 0.4)
        .clamp(96.0, 180.0)
        .toDouble();
    final imageHeight = imageWidth * 0.7;
    final image = isNetworkImage
        ? Image.network(
            resolvedImageUrl,
            headers: UserAgentSettings.instance.requestHeaders,
            width: imageWidth,
            height: imageHeight,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: imageWidth,
                height: imageHeight,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          )
        : const Icon(Icons.image_outlined, size: 36);
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: imageWidth,
        height: imageHeight,
        child: ColoredBox(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: Center(child: image),
        ),
      ),
    );
    return _CertificateDetailRow(
      label: label,
      value: '',
      height: imageHeight + 16,
      trailing: isNetworkImage
          ? Tooltip(
              message: AppLocalizations.of(context).certificateImagePreview,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _showImagePreview(context, resolvedImageUrl),
                child: thumbnail,
              ),
            )
          : thumbnail,
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
