import 'package:flutter/material.dart';

import '../data/landing_point_store.dart';
import '../l10n/app_localizations.dart';

Future<LandingPoint?> showLandingPointEditorDialog(
  BuildContext context, {
  required double latitude,
  required double longitude,
  double? altitudeM,
  double? gpsAccuracyM,
  DateTime? capturedAt,
}) {
  return showDialog<LandingPoint>(
    context: context,
    builder: (context) => _LandingPointEditorDialog(
      latitude: latitude,
      longitude: longitude,
      altitudeM: altitudeM,
      gpsAccuracyM: gpsAccuracyM,
      capturedAt: capturedAt,
    ),
  );
}

class _LandingPointEditorDialog extends StatefulWidget {
  const _LandingPointEditorDialog({
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    this.gpsAccuracyM,
    this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double? altitudeM;
  final double? gpsAccuracyM;
  final DateTime? capturedAt;

  @override
  State<_LandingPointEditorDialog> createState() =>
      _LandingPointEditorDialogState();
}

class _LandingPointEditorDialogState extends State<_LandingPointEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  late final _altitudeController = TextEditingController(
    text: widget.altitudeM?.isFinite == true
        ? widget.altitudeM!.toStringAsFixed(1)
        : '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _altitudeController.dispose();
    super.dispose();
  }

  void _save(AppLocalizations l10n) {
    if (!_formKey.currentState!.validate()) return;
    final altitudeText = _altitudeController.text.trim();
    final point = LandingPoint.create(
      name: _nameController.text,
      latitude: widget.latitude,
      longitude: widget.longitude,
      altitudeM: altitudeText.isEmpty ? null : double.parse(altitudeText),
      gpsAccuracyM: widget.gpsAccuracyM,
      createdAt: widget.capturedAt,
      notes: _notesController.text,
    );
    if (point != null) Navigator.of(context).pop(point);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final capturedAt = widget.capturedAt;
    final gpsAccuracyM = widget.gpsAccuracyM;

    return AlertDialog(
      title: Text(l10n.landingPointAddTitle),
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
                '${widget.latitude.toStringAsFixed(6)}, '
                '${widget.longitude.toStringAsFixed(6)}',
              ),
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
              if (gpsAccuracyM != null && gpsAccuracyM.isFinite) ...[
                const SizedBox(height: 8),
                Text(
                  '${l10n.landingPointGpsAccuracy}: '
                  '${gpsAccuracyM.toStringAsFixed(0)} m',
                ),
              ],
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
