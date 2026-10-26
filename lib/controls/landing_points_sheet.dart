import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';
import '../data/landing_point_store.dart';
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
                        showLastLandingLine: false,
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
