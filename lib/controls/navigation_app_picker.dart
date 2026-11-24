import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';

import '../l10n/app_localizations.dart';
import 'app_notice.dart';

typedef NavigationMapsLoader =
    Future<List<SupportedMap>> Function(double latitude, double longitude);

const supportedNavigationApps = <MapApp>[
  MapApp.airnavPro,
  MapApp.amap,
  MapApp.apple,
  MapApp.baidu,
  MapApp.citymapper,
  MapApp.copilot,
  MapApp.doubleGis,
  MapApp.flitsmeister,
  MapApp.google,
  MapApp.googleGo,
  MapApp.here,
  MapApp.kakao,
  MapApp.magicEarth,
  MapApp.mappls,
  MapApp.mapswithme,
  MapApp.mapyCz,
  MapApp.moovit,
  MapApp.naver,
  MapApp.neshan,
  MapApp.osmand,
  MapApp.osmandplus,
  MapApp.petal,
  MapApp.sygicTruck,
  MapApp.tencent,
  MapApp.tmap,
  MapApp.tomtomgo,
  MapApp.tomtomgofleet,
  MapApp.waze,
  MapApp.yandexMaps,
  MapApp.yandexNavi,
];

Future<List<SupportedMap>> loadNavigationApps(
  double latitude,
  double longitude,
) {
  if (!latitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      !longitude.isFinite ||
      longitude < -180 ||
      longitude > 180) {
    return Future<List<SupportedMap>>.value(const []);
  }
  final request = MapLauncher.directions(Location.coords(latitude, longitude));
  return request.getSupportedMaps(supportedNavigationApps);
}

Future<void> showNavigationAppPicker(
  BuildContext context, {
  required double latitude,
  required double longitude,
  NavigationMapsLoader? loadMaps,
}) async {
  final l10n = AppLocalizations.of(context);
  if (!latitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      !longitude.isFinite ||
      longitude < -180 ||
      longitude > 180) {
    return;
  }

  try {
    final available = await (loadMaps ?? loadNavigationApps)(
      latitude,
      longitude,
    );
    if (!context.mounted) return;
    final maps = available
        .where((map) => map.isInstalled || _supportsBrowserLaunch)
        .toList();
    if (maps.isEmpty) {
      _showMessage(context, l10n.chatNoNavigationApps);
      return;
    }

    final selected = await showModalBottomSheet<SupportedMap>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.chatNavigateWith,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: maps.length,
                itemBuilder: (context, index) {
                  final map = maps[index];
                  return ListTile(
                    key: ValueKey('navigation-app-${map.map.id}'),
                    leading: Image.memory(
                      map.iconBytes,
                      width: 32,
                      height: 32,
                      errorBuilder: (_, _, _) => const Icon(Icons.map_outlined),
                    ),
                    title: Text(map.name),
                    onTap: () => Navigator.of(sheetContext).pop(map),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null || !context.mounted) return;
    try {
      await selected.show();
    } on Object {
      if (context.mounted) {
        _showMessage(context, l10n.chatNavigationLaunchFailed);
      }
    }
  } on Object {
    if (context.mounted) _showMessage(context, l10n.chatNavigationLaunchFailed);
  }
}

bool get _supportsBrowserLaunch =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;

void _showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  AppNotice.show(message);
}
