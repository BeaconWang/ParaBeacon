import 'package:flutter/material.dart';

import '../data/auto_flight_detector.dart';
import '../data/flight_state.dart';
import '../l10n/app_localizations.dart';

Future<void> showAutoFlightSettingsSheet(BuildContext context) async {
  final flight = FlightState.instance;
  var takeoffSpeed = flight.takeoffSpeedKph;
  var minimumLandingSeconds = flight.minimumLandingFlightSeconds.toDouble();
  var landingSpeedSensitivity = flight.landingSpeedSensitivity;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (context, setSheetState) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final modes = <(LandingDetectionMode, String, String)>[
          (
            LandingDetectionMode.automatic,
            l10n.flightLandingAutomatic,
            l10n.flightLandingAutomaticDescription,
          ),
          (
            LandingDetectionMode.manual,
            l10n.flightLandingManual,
            l10n.flightLandingManualDescription,
          ),
          (
            LandingDetectionMode.noDetection,
            l10n.flightLandingNoDetection,
            l10n.flightLandingNoDetectionDescription,
          ),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.flightAutoSettingsTitle,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            flight.resetAutoDetectionSettings();
                            setSheetState(() {
                              takeoffSpeed = flight.takeoffSpeedKph;
                              minimumLandingSeconds = flight
                                  .minimumLandingFlightSeconds
                                  .toDouble();
                              landingSpeedSensitivity =
                                  flight.landingSpeedSensitivity;
                            });
                          },
                          icon: const Icon(Icons.restart_alt),
                          label: Text(l10n.resetToDefaults),
                        ),
                      ],
                    ),
                  ),
                  for (final (mode, title, description) in modes)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(
                        flight.landingMode == mode
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(title),
                      subtitle: Text(description),
                      onTap: () {
                        flight.setLandingMode(mode);
                        setSheetState(() {});
                      },
                    ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${l10n.flightAutoTakeoffSpeed}: '
                      '${takeoffSpeed.toStringAsFixed(0)} km/h',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Slider(
                    min: 1,
                    max: 20,
                    divisions: 19,
                    value: takeoffSpeed,
                    label: '${takeoffSpeed.toStringAsFixed(0)} km/h',
                    onChanged: (value) => setSheetState(() {
                      takeoffSpeed = value;
                    }),
                    onChangeEnd: flight.setTakeoffSpeedKph,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${l10n.flightAutoLandingMinimumFlight}: '
                      '${minimumLandingSeconds.round()} s',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Slider(
                    min: 15,
                    max: 120,
                    divisions: 7,
                    value: minimumLandingSeconds,
                    label: '${minimumLandingSeconds.round()} s',
                    onChanged: (value) => setSheetState(() {
                      minimumLandingSeconds = value;
                    }),
                    onChangeEnd: (value) =>
                        flight.setMinimumLandingFlightSeconds(value.round()),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${l10n.flightAutoLandingSpeedSensitivity}: '
                      '${(landingSpeedSensitivity * 100).round()}%',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Slider(
                    min: 0.5,
                    max: 1.5,
                    divisions: 20,
                    value: landingSpeedSensitivity,
                    label: '${(landingSpeedSensitivity * 100).round()}%',
                    onChanged: (value) => setSheetState(() {
                      landingSpeedSensitivity = value;
                    }),
                    onChangeEnd: flight.setLandingSpeedSensitivity,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
