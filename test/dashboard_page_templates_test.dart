import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/dashboard_menu_content.dart';
import 'package:parabeacon/data/dashboard_page_templates.dart';
import 'package:parabeacon/controls/placed_control.dart';
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

  test('only the two imported page templates are available', () {
    expect(DashboardPageTemplates.all, [
      DashboardPageTemplate.defaultLayout,
      DashboardPageTemplate.goLanding,
    ]);
    final l10n = AppLocalizationsEn();
    expect(DashboardPageTemplate.defaultLayout.titleOf(l10n), 'Default');
    expect(DashboardPageTemplate.goLanding.titleOf(l10n), 'Land');
  });

  for (final template in DashboardPageTemplates.all) {
    for (final viewport in viewports) {
      for (final gridSize in gridSizes) {
        test('$template fits at $viewport with ${gridSize}px grid', () {
          final cols = (viewport.width / gridSize).round();
          final rows = (viewport.height / gridSize).round();
          var sequence = 0;
          final controls = DashboardPageTemplates.createControls(
            template: template,
            viewport: viewport,
            gridSize: gridSize,
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

  test('each template keeps its page controls, positions, and settings', () {
    final defaultControls = _createControls(
      DashboardPageTemplate.defaultLayout,
    );
    final landingControls = _createControls(DashboardPageTemplate.goLanding);
    final defaultByType = {
      for (final control in defaultControls) control.type.id: control,
    };
    final landingByType = {
      for (final control in landingControls) control.type.id: control,
    };

    expect(defaultControls, hasLength(21));
    expect(defaultByType['map']!.col, 0);
    expect(defaultByType['map']!.row, 0);
    expect(defaultByType['map']!.cols, 12);
    expect(defaultByType['map']!.rows, 8);
    expect(defaultByType['map']!.settings['tileSource'], 'amap-sat');
    expect(defaultByType['map']!.settings['showAirspace'], isTrue);
    expect(defaultByType['vario']!.settings['liquidGlass'], isTrue);
    expect(
      defaultByType['flight_button']!.settings['showRecordingStats'],
      isTrue,
    );

    expect(landingControls, hasLength(3));
    expect(
      landingByType.keys,
      containsAll([
        'default_landing_waypoint',
        'nearest_landing_waypoint',
        'map',
      ]),
    );
    expect(landingByType['default_landing_waypoint']!.row, 0);
    expect(landingByType['nearest_landing_waypoint']!.row, 8);
    expect(landingByType['map']!.row, 15);
    expect(landingByType['map']!.rows, 11);
    expect(landingByType['map']!.settings['tracklogMinutes'], 30.0);
    expect(landingByType['map']!.settings['showBearing'], isTrue);
  });

  testWidgets('edit menu offers and applies each imported page template', (
    tester,
  ) async {
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
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Land'), findsOneWidget);
    expect(find.text(l10n.defaultDashboardNavigation), findsNothing);
    await tester.tap(find.text('Land'));
    await tester.pumpAndSettle();

    expect(selectedTemplate, DashboardPageTemplate.goLanding);
  });
}

List<PlacedControl> _createControls(DashboardPageTemplate template) {
  var sequence = 0;
  return DashboardPageTemplates.createControls(
    template: template,
    viewport: const Size(384, 832),
    gridSize: 32,
    nextInstanceId: () => 'template_${sequence++}',
  );
}
