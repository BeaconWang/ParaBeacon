import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/dashboard_menu_content.dart';
import 'package:parabeacon/data/dashboard_page_templates.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:parabeacon/l10n/app_localizations_en.dart';

void main() {
  final viewports = [
    const Size(360, 800),
    const Size(390, 844),
    const Size(360, 640),
    const Size(800, 480),
    const Size(844, 390),
  ];
  const gridSizes = [16.0, 24.0, 32.0, 40.0, 48.0, 64.0, 80.0, 96.0, 120.0];

  for (final viewport in viewports) {
    for (final gridSize in gridSizes) {
      for (final template in DashboardPageTemplates.all) {
        test('$template fits at $viewport with ${gridSize}px grid', () {
          final cols = (viewport.width / gridSize).round();
          final rows = (viewport.height / gridSize).round();
          final cellHeight = viewport.height / rows;
          var sequence = 0;
          final controls = DashboardPageTemplates.createControls(
            template: template,
            viewport: viewport,
            gridSize: gridSize,
            l10n: AppLocalizationsEn(),
            nextInstanceId: () => 'template_${sequence++}',
          );

          expect(controls, isNotEmpty);
          expect(
            controls.map((control) => control.instanceId).toSet().length,
            controls.length,
          );

          for (var i = 0; i < controls.length; i++) {
            final control = controls[i];
            expect(control.col, greaterThanOrEqualTo(0));
            expect(control.row, greaterThanOrEqualTo(0));
            expect(control.col + control.cols, lessThanOrEqualTo(cols));
            expect(control.row + control.rows, lessThanOrEqualTo(rows));

            if (control.type.id == 'status_line') {
              expect(control.rows * cellHeight, greaterThanOrEqualTo(31));
            }

            for (var j = i + 1; j < controls.length; j++) {
              final other = controls[j];
              final overlapsX =
                  control.col < other.col + other.cols &&
                  control.col + control.cols > other.col;
              final overlapsY =
                  control.row < other.row + other.rows &&
                  control.row + control.rows > other.row;
              expect(
                overlapsX && overlapsY,
                isFalse,
                reason: '${control.type.id} overlaps ${other.type.id}',
              );
            }
          }
        });
      }
    }
  }

  test('portrait templates include their key flight controls', () {
    const viewport = Size(360, 800);
    const gridSize = 32.0;
    const requiredControls = {
      DashboardPageTemplate.flight: [
        'flight_button',
        'vario',
        'compass_wind',
        'vertical_graph',
      ],
      DashboardPageTemplate.navigation: [
        'map',
        'nearest_landing_waypoint',
        'takeoff_waypoint',
      ],
      DashboardPageTemplate.conditions: [
        'compass_wind',
        'wind_speed',
        'vertical_graph',
      ],
      DashboardPageTemplate.landing: [
        'map',
        'nearest_landing_waypoint',
        'default_landing_waypoint',
        'takeoff_waypoint',
      ],
      DashboardPageTemplate.instrumentConsole: [
        'flight_button',
        'location',
        'data_monitor',
        'heart_rate',
      ],
      DashboardPageTemplate.takeoffCheck: [
        'flight_button',
        'compass_wind',
        'takeoff_waypoint',
        'map',
      ],
    };

    for (final entry in requiredControls.entries) {
      var sequence = 0;
      final controls = DashboardPageTemplates.createControls(
        template: entry.key,
        viewport: viewport,
        gridSize: gridSize,
        l10n: AppLocalizationsEn(),
        nextInstanceId: () => 'portrait_${sequence++}',
      );
      final controlIds = controls.map((control) => control.type.id).toSet();
      expect(controlIds, containsAll(entry.value), reason: '${entry.key}');

      final flightButton = controls.where(
        (control) => control.type.id == 'flight_button',
      );
      if (flightButton.isNotEmpty) {
        expect(flightButton.single.rows * 32, greaterThanOrEqualTo(80));
      }
      final waypoint = controls.where(
        (control) => control.type.id == 'nearest_landing_waypoint',
      );
      if (waypoint.isNotEmpty) {
        expect(waypoint.single.rows * 32, greaterThanOrEqualTo(90));
        expect(
          waypoint.single.cols * (viewport.width / 11),
          greaterThanOrEqualTo(144),
        );
      }
    }
  });

  testWidgets('edit menu lets the user select a page template', (tester) async {
    DashboardPageTemplate? selectedTemplate;
    final l10n = AppLocalizationsEn();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DashboardMenuContent(
            isEditMode: true,
            pageIndex: 0,
            pageCount: 1,
            gridSize: 32,
            controlCount: 0,
            onGridSizeChanged: (_) {},
            onToggleEditMode: () {},
            onAddControl: () {},
            onApplyPageTemplate: (template) => selectedTemplate = template,
            onAddPage: () {},
            onDeletePage: () {},
            onClearAll: () {},
            onOpenPreferences: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<DashboardPageTemplate>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.defaultDashboardNavigation));
    await tester.pumpAndSettle();

    expect(selectedTemplate, DashboardPageTemplate.navigation);
  });
}
