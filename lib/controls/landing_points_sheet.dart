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
      gpsAccuracyM: data.gpsAccuracy,
      capturedAt: data.gpsTimestamp ?? data.timestamp,
    );
    if (point == null || !context.mounted) return;
    await _savePoint(context, point);
  }

  Future<void> _addFromMap(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final position = await showDialog<LatLng>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return AlertDialog(
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
                      showTrack: false,
                      showThermal: false,
                      showAirspace: false,
                      showWind: false,
                      showSun: false,
                      showBearing: false,
                      showTakeoffLine: false,
                      showTakeoffPoint: false,
                      showLandingPoints: false,
                      showDefaultLandingLine: false,
                      showLastLandingLine: false,
                      showScale: false,
                      showLegend: false,
                      showZoomLevel: false,
                      showAttribution: false,
                      showStatus: false,
                      onMapTap: (point) =>
                          Navigator.of(dialogContext).pop(point),
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
          ],
        );
      },
    );
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
                        final isLast = store.lastPoint?.id == point.id;
                        final detail = <String>[
                          '${point.latitude.toStringAsFixed(5)}, '
                              '${point.longitude.toStringAsFixed(5)}',
                          if (point.altitudeM != null)
                            '${l10n.landingPointAltitude}: '
                                '${point.altitudeM!.toStringAsFixed(0)} m',
                          if (isDefault) l10n.landingPointDefault,
                          if (isLast) l10n.landingPointLast,
                        ].join(' · ');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isDefault
                                ? Icons.favorite
                                : isLast
                                ? Icons.place
                                : Icons.location_on_outlined,
                            color: isDefault
                                ? Colors.red
                                : isLast
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
                          onTap: () => store.setLast(point.id),
                          trailing: PopupMenuButton<String>(
                            tooltip: l10n.landingPointActions,
                            onSelected: (value) async {
                              if (value == 'default') {
                                await store.setDefault(
                                  isDefault ? null : point.id,
                                );
                              } else if (value == 'last') {
                                await store.setLast(point.id);
                              } else if (value == 'delete') {
                                await store.remove(point.id);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'default',
                                child: Text(
                                  isDefault
                                      ? l10n.landingPointClearDefault
                                      : l10n.landingPointSetDefault,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'last',
                                child: Text(l10n.landingPointUseAsLast),
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
