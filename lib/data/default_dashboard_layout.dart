import 'package:flutter/material.dart';

import '../controls/control_catalog.dart';
import '../controls/dash_page.dart';
import '../controls/placed_control.dart';
import '../controls/control_settings.dart';
import '../l10n/app_localizations.dart';

/// Creates the starter dashboards shown on a fresh installation.
///
/// The presets only arrange existing flight-data controls; they do not provide
/// synthetic values or replace sensor/GPS validation.
class DefaultDashboardLayout {
  const DefaultDashboardLayout._();

  static List<DashPage> create({
    required Size viewport,
    required double gridSize,
    required AppLocalizations l10n,
  }) {
    final cols = (viewport.width / gridSize).round().clamp(1, 1000);
    final rows = (viewport.height / gridSize).round().clamp(1, 1000);
    final isPortrait = rows > cols;
    var sequence = 0;

    PlacedControl control(
      String typeId,
      int col,
      int row,
      int width,
      int height,
    ) {
      final type = ControlCatalog.byId(typeId);
      if (type == null) {
        throw StateError('Missing dashboard control type: $typeId');
      }
      return PlacedControl(
        instanceId: 'ctrl_${sequence++}',
        type: type,
        col: col,
        row: row,
        cols: width,
        rows: height,
        settings: defaultSettingsFor(typeId),
      );
    }

    PlacedControl status(int col, int row, int width) =>
        control('status_line', col, row, width, 1);

    final flightControls = isPortrait
        ? _portraitFlight(cols, rows, control, status)
        : _landscapeFlight(cols, rows, control, status);
    final navigationControls = isPortrait
        ? _portraitNavigation(cols, rows, control, status)
        : _landscapeNavigation(cols, rows, control, status);
    final conditionsControls = isPortrait
        ? _portraitConditions(cols, rows, control, status)
        : _landscapeConditions(cols, rows, control, status);

    return [
      DashPage(
        id: 'page_0',
        title: l10n.defaultDashboardFlight,
        icon: Icons.flight_takeoff,
        controls: flightControls,
      ),
      DashPage(
        id: 'page_1',
        title: l10n.defaultDashboardNavigation,
        icon: Icons.navigation_outlined,
        controls: navigationControls,
      ),
      DashPage(
        id: 'page_2',
        title: l10n.defaultDashboardConditions,
        icon: Icons.air,
        controls: conditionsControls,
      ),
    ];
  }

  static List<PlacedControl> _portraitFlight(
    int cols,
    int rows,
    PlacedControl Function(String, int, int, int, int) control,
    PlacedControl Function(int, int, int) status,
  ) {
    final contentRows = rows - 1;
    final heroHeight = (contentRows * 0.27).round().clamp(3, contentRows);
    final dataHeight = (contentRows * 0.16).round().clamp(2, 3);
    final graphHeight = ((contentRows - heroHeight - dataHeight * 2) * 0.75)
        .round()
        .clamp(2, contentRows);
    final graphRow = 1 + heroHeight + dataHeight * 2;
    final footerRow = graphRow + graphHeight;
    final footerHeight = rows - footerRow;
    final flightWidth = (cols * 0.36).round().clamp(1, cols - 2);
    final varioWidth = (cols * 0.28).round().clamp(1, cols - flightWidth - 1);
    final compassWidth = cols - flightWidth - varioWidth;
    final leftWidth = (cols * 0.64).round().clamp(1, cols - 1);
    final rightWidth = cols - leftWidth;
    final halfWidth = cols ~/ 2;

    return [
      status(0, 0, cols),
      control('flight_button', 0, 1, flightWidth, heroHeight.clamp(2, 3)),
      control('vario', flightWidth, 1, varioWidth, heroHeight),
      control(
        'compass_wind',
        flightWidth + varioWidth,
        1,
        compassWidth,
        heroHeight,
      ),
      control('altitude', 0, 1 + heroHeight, halfWidth, dataHeight),
      control(
        'vertical_speed',
        halfWidth,
        1 + heroHeight,
        cols - halfWidth,
        dataHeight,
      ),
      control(
        'ground_speed',
        0,
        1 + heroHeight + dataHeight,
        halfWidth,
        dataHeight,
      ),
      control(
        'heading',
        halfWidth,
        1 + heroHeight + dataHeight,
        cols - halfWidth,
        dataHeight,
      ),
      control('vertical_graph', 0, graphRow, leftWidth, graphHeight),
      control('climb_avg', leftWidth, graphRow, rightWidth, graphHeight),
      if (footerHeight > 0) ...[
        control('flight_time', 0, footerRow, halfWidth, footerHeight),
        control(
          'gps_accuracy',
          halfWidth,
          footerRow,
          cols - halfWidth,
          footerHeight,
        ),
      ],
    ];
  }

  static List<PlacedControl> _landscapeFlight(
    int cols,
    int rows,
    PlacedControl Function(String, int, int, int, int) control,
    PlacedControl Function(int, int, int) status,
  ) {
    final bodyHeight = rows - 1;
    final leftWidth = (cols * 0.58).round().clamp(1, cols - 2);
    final rightWidth = cols - leftWidth;
    final varioWidth = (leftWidth * 0.28).round().clamp(1, leftWidth - 1);
    final graphWidth = leftWidth - varioWidth;
    final firstWidth = rightWidth ~/ 2;
    final secondWidth = rightWidth - firstWidth;
    final heroHeight = (bodyHeight * 0.38).round().clamp(2, bodyHeight);
    final dataHeight = ((bodyHeight - heroHeight) ~/ 2).clamp(1, bodyHeight);
    final secondRow = 1 + heroHeight + dataHeight;

    return [
      status(0, 0, cols),
      control('vario', 0, 1, varioWidth, bodyHeight),
      control('vertical_graph', varioWidth, 1, graphWidth, bodyHeight),
      control('flight_button', leftWidth, 1, firstWidth, heroHeight),
      control(
        'compass_wind',
        leftWidth + firstWidth,
        1,
        secondWidth,
        heroHeight,
      ),
      control('altitude', leftWidth, 1 + heroHeight, firstWidth, dataHeight),
      control(
        'vertical_speed',
        leftWidth + firstWidth,
        1 + heroHeight,
        secondWidth,
        dataHeight,
      ),
      control('ground_speed', leftWidth, secondRow, firstWidth, dataHeight),
      control(
        'heading',
        leftWidth + firstWidth,
        secondRow,
        secondWidth,
        dataHeight,
      ),
    ];
  }

  static List<PlacedControl> _portraitNavigation(
    int cols,
    int rows,
    PlacedControl Function(String, int, int, int, int) control,
    PlacedControl Function(int, int, int) status,
  ) {
    final mapHeight = (rows - 8).clamp(3, rows - 1);
    final landingRow = 1 + mapHeight;
    final landingHeight = 3;
    final takeoffRow = landingRow + landingHeight;
    final statsRow = takeoffRow + 2;
    final halfWidth = cols ~/ 2;

    return [
      status(0, 0, cols),
      control('map', 0, 1, cols, mapHeight),
      control('nearest_landing_waypoint', 0, landingRow, cols, landingHeight),
      control('takeoff_waypoint', 0, takeoffRow, cols, 2),
      control('heading', 0, statsRow, halfWidth, 2),
      control('ground_speed', halfWidth, statsRow, cols - halfWidth, 2),
    ];
  }

  static List<PlacedControl> _landscapeNavigation(
    int cols,
    int rows,
    PlacedControl Function(String, int, int, int, int) control,
    PlacedControl Function(int, int, int) status,
  ) {
    final bodyHeight = rows - 1;
    final mapWidth = (cols * 0.60).round().clamp(1, cols - 2);
    final rightWidth = cols - mapWidth;
    final firstHeight = (bodyHeight * 0.38).round().clamp(1, bodyHeight);
    final secondHeight = (bodyHeight * 0.30).round().clamp(1, bodyHeight);
    final finalRow = 1 + firstHeight + secondHeight;
    final finalHeight = rows - finalRow;
    final halfWidth = rightWidth ~/ 2;

    return [
      status(0, 0, cols),
      control('map', 0, 1, mapWidth, bodyHeight),
      control('nearest_landing_waypoint', mapWidth, 1, rightWidth, firstHeight),
      control(
        'takeoff_waypoint',
        mapWidth,
        1 + firstHeight,
        rightWidth,
        secondHeight,
      ),
      if (finalHeight > 0) ...[
        control('heading', mapWidth, finalRow, halfWidth, finalHeight),
        control(
          'ground_speed',
          mapWidth + halfWidth,
          finalRow,
          rightWidth - halfWidth,
          finalHeight,
        ),
      ],
    ];
  }

  static List<PlacedControl> _portraitConditions(
    int cols,
    int rows,
    PlacedControl Function(String, int, int, int, int) control,
    PlacedControl Function(int, int, int) status,
  ) {
    final contentRows = rows - 1;
    final heroHeight = (contentRows * 0.27).round().clamp(3, contentRows);
    final compassWidth = (cols * 0.45).round().clamp(1, cols - 1);
    final detailWidth = cols - compassWidth;
    final halfWidth = cols ~/ 2;
    final weatherRow = 1 + heroHeight;
    final thermalRow = weatherRow + 2;
    final summaryRow = thermalRow + 2;
    final graphRow = summaryRow + 2;
    final graphHeight = rows - graphRow;

    return [
      status(0, 0, cols),
      control('compass_wind', 0, 1, compassWidth, heroHeight),
      control('wind_speed', compassWidth, 1, detailWidth, 2),
      control('wind_direction', compassWidth, 3, detailWidth, 2),
      control('temperature', 0, weatherRow, halfWidth, 2),
      control('pressure', halfWidth, weatherRow, cols - halfWidth, 2),
      control('thermal_gain', 0, thermalRow, halfWidth, 2),
      control('climb_avg', halfWidth, thermalRow, cols - halfWidth, 2),
      control('max_altitude', 0, summaryRow, halfWidth, 2),
      control('gps_accuracy', halfWidth, summaryRow, cols - halfWidth, 2),
      if (graphHeight > 0)
        control('vertical_graph', 0, graphRow, cols, graphHeight),
    ];
  }

  static List<PlacedControl> _landscapeConditions(
    int cols,
    int rows,
    PlacedControl Function(String, int, int, int, int) control,
    PlacedControl Function(int, int, int) status,
  ) {
    final bodyHeight = rows - 1;
    final graphWidth = (cols * 0.52).round().clamp(1, cols - 2);
    final rightWidth = cols - graphWidth;
    final firstHeight = (bodyHeight * 0.40).round().clamp(1, bodyHeight);
    final rowHeight = ((bodyHeight - firstHeight) ~/ 2).clamp(1, bodyHeight);
    final secondRow = 1 + firstHeight;
    final thirdRow = secondRow + rowHeight;
    final leftWidth = rightWidth ~/ 2;

    return [
      status(0, 0, cols),
      control('vertical_graph', 0, 1, graphWidth, bodyHeight),
      control('compass_wind', graphWidth, 1, rightWidth, firstHeight),
      control('wind_speed', graphWidth, secondRow, leftWidth, rowHeight),
      control(
        'wind_direction',
        graphWidth + leftWidth,
        secondRow,
        rightWidth - leftWidth,
        rowHeight,
      ),
      control('temperature', graphWidth, thirdRow, leftWidth, rowHeight),
      control(
        'pressure',
        graphWidth + leftWidth,
        thirdRow,
        rightWidth - leftWidth,
        rowHeight,
      ),
    ];
  }
}
