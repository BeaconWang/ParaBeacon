import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../l10n/app_localizations.dart';

Future<void> showAsfcFlightRecordsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _AsfcFlightRecordsSheet(),
  );
}

class _AsfcFlightRecordsSheet extends StatefulWidget {
  const _AsfcFlightRecordsSheet();

  @override
  State<_AsfcFlightRecordsSheet> createState() => _AsfcFlightRecordsSheetState();
}

class _AsfcFlightRecordsSheetState extends State<_AsfcFlightRecordsSheet> {
  final _auth = AsfcAuthService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _auth.loadFlightRecords(force: true),
        _auth.loadAgencies(),
        _auth.loadCertificateCoaches(),
      ]);
      if (mounted) setState(() {});
    });
  }

  Future<void> _addRecord() async {
    final saved = await showAsfcFlightRecordForm(context);
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _editRecord(AsfcFlightRecord record) async {
    final saved = await showAsfcFlightRecordForm(context, record: record);
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _deleteRecord(AsfcFlightRecord record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.asfcFlightDeleteTitle),
        content: Text(l10n.asfcFlightDeleteConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await _auth.deleteFlightRecord(record.id);
    if (!mounted) return;
    _message(success ? l10n.asfcFlightDeleted : l10n.asfcFlightDeleteFailed);
    setState(() {});
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(child: Text(l10n.asfcFlightRecords, style: theme.textTheme.titleLarge)),
                  IconButton(
                    tooltip: l10n.refresh,
                    onPressed: _auth.isFlightRecordsLoading
                        ? null
                        : () => _auth.loadFlightRecords(force: true),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: l10n.asfcFlightSubmit,
                    onPressed: _auth.isFlightRecordSubmitting ? null : _addRecord,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_auth.isFlightRecordsLoading) const LinearProgressIndicator(),
            Expanded(
              child: records.isEmpty && !_auth.isFlightRecordsLoading
                  ? Center(child: Text(l10n.asfcFlightNoRecords))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.flight_takeoff, color: theme.colorScheme.onPrimaryContainer),
                          ),
                          title: Text(record.trainTime),
                          subtitle: Text(
                            '${record.address} · ${record.brandNo}\n${record.startTime} – ${record.endTime}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _editRecord(record);
                              if (value == 'delete') _deleteRecord(record);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                            ],
                          ),
                          onTap: () => _showDetails(record),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(AsfcFlightRecord record) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.asfcFlightDetails),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail(l10n.asfcFlightDate, record.trainTime),
              _detail(l10n.asfcFlightAddress, record.address),
              _detail(l10n.asfcFlightModel, record.brandNo),
              _detail(l10n.asfcFlightTask, record.taskName),
              _detail(l10n.asfcFlightTime, '${record.startTime} – ${record.endTime}'),
              _detail(l10n.asfcFlightSeatType, record.seatTypeName.isEmpty ? record.seatType : record.seatTypeName),
              _detail(l10n.asfcFlightTakeoffMode, record.takeoffMode),
              _detail(l10n.asfcFlightSortie, record.sortie),
              _detail(l10n.asfcFlightAgency, record.coachAgencyName),
              _detail(l10n.asfcFlightCoach, record.coachName),
              if (record.signinDescription.isNotEmpty) _detail(l10n.asfcFlightSignin, record.signinDescription),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))],
      ),
    );
  }

  Widget _detail(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: $value'),
    );
  }
}

Future<bool?> showAsfcFlightRecordForm(
  BuildContext context, {
  AsfcFlightRecord? record,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AsfcFlightRecordForm(record: record),
  );
}

class _AsfcFlightRecordForm extends StatefulWidget {
  const _AsfcFlightRecordForm({this.record});

  final AsfcFlightRecord? record;

  @override
  State<_AsfcFlightRecordForm> createState() => _AsfcFlightRecordFormState();
}

class _AsfcFlightRecordFormState extends State<_AsfcFlightRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _auth = AsfcAuthService.instance;
  AsfcAgency? _agency;
  AsfcCoach? _coach;
  String _seatType = 'FRONT';
  String _takeoffMode = '';

  static const _fields = [
    'trainTime',
    'address',
    'brandNo',
    'taskName',
    'startTime',
    'endTime',
    'sortie',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    final values = <String, String>{
      'trainTime': r?.trainTime ?? _date(DateTime.now()),
      'address': r?.address ?? '',
      'brandNo': r?.brandNo ?? '',
      'taskName': r?.taskName ?? '',
      'startTime': r?.startTime ?? '',
      'endTime': r?.endTime ?? '',
      'sortie': r?.sortie ?? '',
    };
    for (final field in _fields) {
      _controllers[field] = TextEditingController(text: values[field]);
    }
    _seatType = r?.seatType.isNotEmpty == true ? r!.seatType : 'FRONT';
    _takeoffMode = r?.takeoffMode ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveSelections());
  }

  void _resolveSelections() {
    final r = widget.record;
    if (r == null) return;
    final agencies = _auth.agencies;
    final coaches = _auth.certificateCoaches;
    if (mounted) {
      setState(() {
        for (final agency in agencies) {
          if (agency.id == r.coachAgencyId || agency.name == r.coachAgencyName) {
            _agency = agency;
            break;
          }
        }
        for (final coach in coaches) {
          if (coach.id == r.coachId) {
            _coach = coach;
            break;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  TextEditingController _controller(String field) => _controllers[field]!;

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? AppLocalizations.of(context).asfcFlightRequired
      : null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    if (_agency == null || _coach == null || _takeoffMode.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.asfcFlightSelectionRequired)));
      return;
    }
    final success = await _auth.saveFlightRecord(
      id: widget.record?.id,
      trainTime: _controller('trainTime').text,
      address: _controller('address').text,
      brandNo: _controller('brandNo').text,
      taskName: _controller('taskName').text,
      startTime: _controller('startTime').text,
      endTime: _controller('endTime').text,
      seatType: _seatType,
      takeoffMode: _takeoffMode,
      sortie: _controller('sortie').text,
      coachAgencyId: _agency!.id,
      coachId: _coach!.id,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_auth.errorMessage ?? l10n.asfcFlightSaveFailed)),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      );

  Widget _field(String name, String label, IconData icon, {TextInputType? type}) {
    return TextFormField(
      controller: _controller(name),
      keyboardType: type,
      decoration: _decoration(label, icon),
      validator: _required,
      textInputAction: TextInputAction.next,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final coaches = _auth.certificateCoaches
        .where((coach) => _agency == null || coach.agencyId == 0 || coach.agencyId == _agency!.id || coach.agencyName == _agency!.name)
        .toList();
    if (_coach != null && !coaches.any((coach) => coach.id == _coach!.id)) coaches.insert(0, _coach!);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.record == null ? l10n.asfcFlightSubmit : l10n.asfcFlightEdit, style: theme.textTheme.titleLarge)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              _field('trainTime', l10n.asfcFlightDate, Icons.calendar_today_outlined),
              const SizedBox(height: 12),
              _field('address', l10n.asfcFlightAddress, Icons.location_on_outlined),
              const SizedBox(height: 12),
              _field('brandNo', l10n.asfcFlightModel, Icons.flight_outlined),
              const SizedBox(height: 12),
              _field('taskName', l10n.asfcFlightTask, Icons.assignment_outlined),
              const SizedBox(height: 12),
              _field('startTime', l10n.asfcFlightStartTime, Icons.play_arrow_outlined),
              const SizedBox(height: 12),
              _field('endTime', l10n.asfcFlightEndTime, Icons.stop_outlined),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _seatType,
                decoration: _decoration(l10n.asfcFlightSeatType, Icons.event_seat_outlined),
                items: [
                  DropdownMenuItem(value: 'FRONT', child: Text(l10n.asfcFlightFrontSeat)),
                  DropdownMenuItem(value: 'BACK', child: Text(l10n.asfcFlightBackSeat)),
                ],
                onChanged: (value) => setState(() => _seatType = value ?? 'FRONT'),
              ),
              const SizedBox(height: 12),
              _field('sortie', l10n.asfcFlightSortie, Icons.repeat_outlined, type: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _takeoffMode.isEmpty ? null : _takeoffMode,
                decoration: _decoration(l10n.asfcFlightTakeoffMode, Icons.flight_takeoff_outlined),
                items: ['FOOT', 'CAR', 'OTHER']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                validator: (value) => _required(value),
                onChanged: (value) => setState(() => _takeoffMode = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AsfcAgency>(
                initialValue: _agency,
                decoration: _decoration(l10n.asfcFlightAgency, Icons.school_outlined),
                hint: Text(_auth.isAgenciesLoading ? l10n.asfcFlightLoading : l10n.asfcFlightSelectAgency),
                items: _auth.agencies.map((agency) => DropdownMenuItem(value: agency, child: Text(agency.name))).toList(),
                validator: (_) => _agency == null ? l10n.asfcFlightRequired : null,
                onChanged: (value) => setState(() {
                  _agency = value;
                  _coach = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AsfcCoach>(
                initialValue: coaches.any((coach) => coach.id == _coach?.id) ? _coach : null,
                decoration: _decoration(l10n.asfcFlightCoach, Icons.person_search_outlined),
                hint: Text(_auth.isCertificateCoachesLoading ? l10n.asfcFlightLoading : l10n.asfcFlightSelectCoach),
                items: coaches.map((coach) => DropdownMenuItem(value: coach, child: Text(coach.name))).toList(),
                validator: (_) => _coach == null ? l10n.asfcFlightRequired : null,
                onChanged: (value) => setState(() => _coach = value),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _auth.isFlightRecordSubmitting ? null : _submit,
                icon: _auth.isFlightRecordSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(l10n.submit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
