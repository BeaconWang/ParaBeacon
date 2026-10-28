import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';
import '../data/landing_point_store.dart';
import '../data/landing_points_config_io.dart';
import '../l10n/app_localizations.dart';
import 'landing_point_editor.dart';
import 'map_control.dart';

Future<void> showLandingPointsSheet(BuildContext context) async {
  await LandingPointStore.instance.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const _LandingPointsSheet(),
  );
}

class _LandingPointsSheet extends StatelessWidget {
  const _LandingPointsSheet();

  Future<void> _addCurrent(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final data = FlightDataProvider.of(context);
    if (!_hasValidFix(data)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.landingPointNoGpsFix)));
      return;
    }
    final point = await showLandingPointEditorDialog(
      context,
      latitude: data.latitude,
      longitude: data.longitude,
      altitudeM: data.gpsAltitude ?? data.baroAltitude,
      capturedAt: data.gpsTimestamp ?? data.timestamp,
    );
    if (point == null || !context.mounted) return;
    await _savePoint(context, point);
  }

  Future<LatLng?> _pickMapLocation(
    BuildContext context,
    LatLng initialPosition,
  ) {
    final l10n = AppLocalizations.of(context);
    var selectedPosition = initialPosition;
    return showDialog<LatLng>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l10n.landingPointPickMapTitle),
            content: SizedBox(
              width: size.width * 0.8,
              height: size.height * 0.58,
              child: Column(
                children: [
                  Text(l10n.landingPointPickPrompt),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MapControl(
                        active: true,
                        follow: false,
                        initialZoom: 13,
                        initialCenter: initialPosition,
                        selectionMarker: selectedPosition,
                        showTrack: false,
                        showThermal: false,
                        showAirspace: false,
                        showWind: false,
                        showSun: false,
                        showBearing: false,
                        showTakeoffLine: false,
                        showTakeoffPoint: false,
                        showDefaultLandingPoint: false,
                        showNearestLandingPoint: false,
                        showDefaultLandingLine: false,
                        showNearestLandingLine: false,
                        showScale: false,
                        showLegend: false,
                        showZoomLevel: false,
                        showAttribution: false,
                        showStatus: false,
                        onMapTap: (point) =>
                            setDialogState(() => selectedPosition = point),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(selectedPosition),
                child: Text(l10n.landingPointApply),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addFromMap(BuildContext context) async {
    final data = FlightDataProvider.of(context);
    final initialPosition = _hasValidFix(data)
        ? LatLng(data.latitude, data.longitude)
        : const LatLng(46.5197, 6.6323);
    final position = await _pickMapLocation(context, initialPosition);
    if (position == null || !context.mounted) return;
    final point = await showLandingPointEditorDialog(
      context,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (point == null || !context.mounted) return;
    await _savePoint(context, point);
  }

  Future<void> _savePoint(BuildContext context, LandingPoint point) async {
    await LandingPointStore.instance.add(point);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${point.name} · ${AppLocalizations.of(context).landingPointSaved}',
        ),
      ),
    );
  }

  Future<void> _editPoint(BuildContext context, LandingPoint point) async {
    final edited = await showLandingPointEditorDialog(
      context,
      latitude: point.latitude,
      longitude: point.longitude,
      altitudeM: point.altitudeM,
      capturedAt: point.createdAt,
      point: point,
      onPickLocation: (_, initialPosition) =>
          _pickMapLocation(context, initialPosition),
    );
    if (edited == null || !context.mounted) return;
    final saved = await LandingPointStore.instance.update(edited);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? '${edited.name} · ${l10n.landingPointUpdated}'
              : l10n.landingPointUpdateFailed,
        ),
      ),
    );
  }

  Future<bool?> _chooseExportDestination(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) return Future.value(false);
    return showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.flightsExportDestinationTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.flightsExportDestinationDownloads),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.flightsExportDestinationShare),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLandingPoints(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final saveToDownloads = await _chooseExportDestination(context, l10n);
      if (!context.mounted || saveToDownloads == null) return;
      final store = LandingPointStore.instance;
      final exported = await LandingPointsConfigIO.instance.exportAndShare(
        store.points,
        defaultId: store.defaultPoint?.id,
        saveToDownloads: saveToDownloads,
      );
      if (!context.mounted || !exported) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveToDownloads
                ? l10n.flightsExportSavedToDownloads
                : l10n.landingPointsExported,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.landingPointsExportFailed)));
    }
  }

  Future<void> _importLandingPoints(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.landingPointsImport,
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid ? null : [LandingPointsConfigIO.extension],
        withData: true,
      );
      if (!context.mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size <= 0 || file.size > LandingPointsConfigIO.maxFileBytes) {
        throw const FormatException();
      }
      final bytes = file.bytes;
      final path = file.path;
      if (bytes == null && path == null) throw const FormatException();
      final imported = bytes != null
          ? LandingPointsConfigIO.instance.parseBundle(bytes)
          : await LandingPointsConfigIO.instance.importFile(path!);
      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.landingPointsImportTitle),
          content: Text(l10n.landingPointsImportConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.landingPointsImport),
            ),
          ],
        ),
      );
      if (!context.mounted || confirmed != true) return;

      await LandingPointStore.instance.replaceAll(
        imported.points,
        defaultId: imported.defaultId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.landingPointsImported)));
    } catch (_) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.landingPointsImport),
          content: Text(l10n.landingPointsImportFailed),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
    }
  }

  bool _hasValidFix(FlightData data) =>
      data.hasFix &&
      data.latitude.isFinite &&
      data.longitude.isFinite &&
      data.latitude >= -90 &&
      data.latitude <= 90 &&
      data.longitude >= -180 &&
      data.longitude <= 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final data = FlightDataProvider.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.landingPointsTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addCurrent(context),
                  icon: const Icon(Icons.my_location),
                  label: Text(l10n.landingPointAddCurrent),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addFromMap(context),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l10n.landingPointPickMapTitle),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _importLandingPoints(context),
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(l10n.landingPointsImport),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportLandingPoints(context),
                      icon: const Icon(Icons.file_upload_outlined),
                      label: Text(l10n.landingPointsExport),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedBuilder(
                  animation: LandingPointStore.instance,
                  builder: (context, _) {
                    final store = LandingPointStore.instance;
                    final nearest = _hasValidFix(data)
                        ? store.nearestPointTo(data.latitude, data.longitude)
                        : null;
                    if (store.points.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.landingPointsEmpty,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: store.points.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final point = store.points[index];
                        final isDefault = store.defaultPoint?.id == point.id;
                        final isNearest = nearest?.id == point.id;
                        final detail = <String>[
                          '${point.latitude.toStringAsFixed(5)}, '
                              '${point.longitude.toStringAsFixed(5)}',
                          if (point.altitudeM != null)
                            '${l10n.landingPointAltitude}: '
                                '${point.altitudeM!.toStringAsFixed(0)} m',
                          if (isDefault) l10n.landingPointDefault,
                          if (isNearest) l10n.landingPointLast,
                        ].join(' · ');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isDefault
                                ? Icons.favorite
                                : isNearest
                                ? Icons.place
                                : Icons.location_on_outlined,
                            color: isDefault
                                ? Colors.red
                                : isNearest
                                ? Colors.deepPurple
                                : theme.colorScheme.primary,
                          ),
                          title: Text(point.name),
                          subtitle: Text(
                            point.notes.isEmpty
                                ? detail
                                : '$detail\n${point.notes}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: l10n.landingPointActions,
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editPoint(context, point);
                              } else if (value == 'default') {
                                await store.setDefault(
                                  isDefault ? null : point.id,
                                );
                              } else if (value == 'delete') {
                                await store.remove(point.id);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(l10n.edit),
                              ),
                              PopupMenuItem(
                                value: 'default',
                                child: Text(
                                  isDefault
                                      ? l10n.landingPointClearDefault
                                      : l10n.landingPointSetDefault,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(l10n.landingPointDelete),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
