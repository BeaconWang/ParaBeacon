import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/control_catalog.dart';
import 'package:parabeacon/controls/dash_page.dart';
import 'package:parabeacon/controls/placed_control.dart';
import 'package:parabeacon/data/layout_config_io.dart';
import 'package:parabeacon/data/layout_store.dart';

void main() {
  final io = LayoutConfigIO.instance;

  test('dashboard configuration round-trips pages, controls and settings', () {
    final altitude = ControlCatalog.byId('altitude')!;
    final layout = SavedLayout(
      pages: [
        DashPage(
          id: 'page_0',
          title: 'Flight',
          controls: [
            PlacedControl(
              instanceId: 'ctrl_8',
              type: altitude,
              col: 2,
              row: 3,
              cols: 5,
              rows: 4,
              settings: {'showTitle': false, 'customLabel': 'Altitude'},
            ),
          ],
        ),
        DashPage(id: 'page_3', title: 'Map'),
      ],
      gridSize: 40,
      currentPage: 1,
    );

    final restored = io.parseBundle(utf8.encode(io.buildBundle(layout)));

    expect(restored.pages, hasLength(2));
    expect(restored.pages.first.title, 'Flight');
    expect(restored.pages.first.controls, hasLength(1));
    expect(restored.pages.first.controls.single.instanceId, 'ctrl_8');
    expect(restored.pages.first.controls.single.settings['showTitle'], isFalse);
    expect(
      restored.pages.first.controls.single.settings['customLabel'],
      'Altitude',
    );
    expect(restored.pages.last.title, 'Map');
    expect(restored.gridSize, 40);
    expect(restored.currentPage, 1);
  });

  test('rejects unsupported versions and malformed layouts', () {
    expect(
      () => io.parseBundle(
        utf8.encode(
          jsonEncode({'format': 'parabeacon.dashboard', 'version': 2}),
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => io.parseBundle(
        utf8.encode(
          jsonEncode({
            'format': 'parabeacon.dashboard',
            'version': 1,
            'gridSize': 32,
            'pages': [],
          }),
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejects nested control-setting data', () {
    final bundle = {
      'format': 'parabeacon.dashboard',
      'version': 1,
      'gridSize': 32,
      'pages': [
        {
          'id': 'page_0',
          'controls': [
            {
              'instanceId': 'ctrl_0',
              'typeId': 'altitude',
              'settings': {
                'unexpected': <String>['nested'],
              },
            },
          ],
        },
      ],
    };

    expect(
      () => io.parseBundle(utf8.encode(jsonEncode(bundle))),
      throwsFormatException,
    );
  });
}
