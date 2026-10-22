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
  final l10n = AppLocalizations.of(context);
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final altitudeController = TextEditingController(
    text: altitudeM?.isFinite == true ? altitudeM!.toStringAsFixed(1) : '',
  );

  return showDialog<LandingPoint>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.landingPointAddTitle),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
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
                '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: altitudeController,
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
                controller: notesController,
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
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final enteredAltitude = altitudeController.text.trim().isEmpty
                ? null
                : double.tryParse(altitudeController.text.trim());
            final point = LandingPoint.create(
              name: nameController.text,
              latitude: latitude,
              longitude: longitude,
              altitudeM: enteredAltitude,
              gpsAccuracyM: gpsAccuracyM,
              createdAt: capturedAt,
              notes: notesController.text,
            );
            if (point == null) return;
            Navigator.of(dialogContext).pop(point);
          },
          child: Text(l10n.landingPointSave),
        ),
      ],
    ),
  ).whenComplete(() {
    nameController.dispose();
    notesController.dispose();
    altitudeController.dispose();
  });
}
