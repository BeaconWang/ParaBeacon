import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/landing_point_store.dart';
import '../l10n/app_localizations.dart';

typedef LandingPointLocationPicker =
    Future<LatLng?> Function(BuildContext context, LatLng initialPosition);

Future<LandingPoint?> showLandingPointEditorDialog(
  BuildContext context, {
  required double latitude,
  required double longitude,
  double? altitudeM,
  DateTime? capturedAt,
  LandingPoint? point,
  LandingPointLocationPicker? onPickLocation,
}) {
  return showDialog<LandingPoint>(
    context: context,
    builder: (context) => _LandingPointEditorDialog(
      latitude: latitude,
      longitude: longitude,
      altitudeM: altitudeM,
      capturedAt: capturedAt,
      point: point,
      onPickLocation: onPickLocation,
    ),
  );
}

class _LandingPointEditorDialog extends StatefulWidget {
  const _LandingPointEditorDialog({
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    this.capturedAt,
    this.point,
    this.onPickLocation,
  });

  final double latitude;
  final double longitude;
  final double? altitudeM;
  final DateTime? capturedAt;
  final LandingPoint? point;
  final LandingPointLocationPicker? onPickLocation;

  @override
  State<_LandingPointEditorDialog> createState() =>
      _LandingPointEditorDialogState();
}

class _LandingPointEditorDialogState extends State<_LandingPointEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.point?.name ?? '',
  );
  late double _latitude = widget.point?.latitude ?? widget.latitude;
  late double _longitude = widget.point?.longitude ?? widget.longitude;
  late final _notesController = TextEditingController(
    text: widget.point?.notes ?? '',
  );
  late final _altitudeController = TextEditingController(
    text: (widget.point?.altitudeM ?? widget.altitudeM)?.toString() ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _altitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picker = widget.onPickLocation;
    if (picker == null) return;
    final selected = await picker(context, LatLng(_latitude, _longitude));
    if (selected == null || !mounted) return;
    setState(() {
      _latitude = selected.latitude;
      _longitude = selected.longitude;
    });
  }

  void _save(AppLocalizations l10n) {
    if (!_formKey.currentState!.validate()) return;
    final altitudeText = _altitudeController.text.trim();
    final editedPoint = widget.point;
    final candidate = LandingPoint.create(
      name: _nameController.text,
      latitude: _latitude,
      longitude: _longitude,
      altitudeM: altitudeText.isEmpty ? null : double.parse(altitudeText),
      createdAt: editedPoint?.createdAt ?? widget.capturedAt,
      notes: _notesController.text,
    );
    if (candidate == null) return;
    final result = editedPoint == null
        ? candidate
        : LandingPoint(
            id: editedPoint.id,
            name: candidate.name,
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            altitudeM: candidate.altitudeM,
            createdAt: editedPoint.createdAt,
            notes: candidate.notes,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final point = widget.point;
    final capturedAt = point?.createdAt ?? widget.capturedAt;

    return AlertDialog(
      title: Text(
        point == null ? l10n.landingPointAddTitle : l10n.landingPointEditTitle,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: LandingPoint.maxNameLength,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.landingPointNameRequired
                    : null,
                decoration: InputDecoration(
                  labelText: l10n.landingPointName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n.landingPointCoordinates}: '
                '${_latitude.toStringAsFixed(6)}, '
                '${_longitude.toStringAsFixed(6)}',
              ),
              if (point != null && widget.onPickLocation != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l10n.landingPointChangeLocation),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _altitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final parsed = double.tryParse(text);
                  if (parsed == null ||
                      !parsed.isFinite ||
                      parsed < -12000 ||
                      parsed > 100000) {
                    return l10n.landingPointAltitudeInvalid;
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: l10n.landingPointAltitude,
                  suffixText: 'm',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (capturedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.landingPointCapturedAt}: '
                  '${MaterialLocalizations.of(context).formatShortDate(capturedAt)} '
                  '${TimeOfDay.fromDateTime(capturedAt).format(context)}',
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLength: LandingPoint.maxNotesLength,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.landingPointNotes,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _save(l10n),
          child: Text(l10n.landingPointSave),
        ),
      ],
    );
  }
}
