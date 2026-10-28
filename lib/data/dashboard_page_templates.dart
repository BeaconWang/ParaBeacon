import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controls/control_catalog.dart';
import '../controls/placed_control.dart';
import '../l10n/app_localizations.dart';

enum DashboardPageTemplate {
  flight,
  navigation,
  conditions,
  landing,
  instrumentConsole,
  takeoffCheck,
}

extension DashboardPageTemplateDetails on DashboardPageTemplate {
  IconData get icon => switch (this) {
    DashboardPageTemplate.flight => Icons.flight_takeoff,
    DashboardPageTemplate.navigation => Icons.map_outlined,
    DashboardPageTemplate.conditions => Icons.air,
    DashboardPageTemplate.landing => Icons.pin_drop_outlined,
    DashboardPageTemplate.instrumentConsole => Icons.sensors_outlined,
    DashboardPageTemplate.takeoffCheck => Icons.checklist_outlined,
  };

  String titleOf(AppLocalizations l10n) => switch (this) {
    DashboardPageTemplate.flight => l10n.defaultDashboardFlight,
    DashboardPageTemplate.navigation => l10n.defaultDashboardNavigation,
    DashboardPageTemplate.conditions => l10n.defaultDashboardConditions,
    DashboardPageTemplate.landing => l10n.dashboardTemplateLanding,
    DashboardPageTemplate.instrumentConsole =>
      l10n.dashboardTemplateInstrumentConsole,
    DashboardPageTemplate.takeoffCheck => l10n.dashboardTemplateTakeoffCheck,
  };

  String descriptionOf(AppLocalizations l10n) => switch (this) {
    DashboardPageTemplate.flight => l10n.dashboardTemplateFlightDescription,
    DashboardPageTemplate.navigation =>
      l10n.dashboardTemplateNavigationDescription,
    DashboardPageTemplate.conditions =>
      l10n.dashboardTemplateConditionsDescription,
    DashboardPageTemplate.landing => l10n.dashboardTemplateLandingDescription,
    DashboardPageTemplate.instrumentConsole =>
      l10n.dashboardTemplateInstrumentConsoleDescription,
    DashboardPageTemplate.takeoffCheck =>
      l10n.dashboardTemplateTakeoffCheckDescription,
  };
}

class DashboardPageTemplates {
  const DashboardPageTemplates._();

  static const List<DashboardPageTemplate> all = DashboardPageTemplate.values;

  static List<PlacedControl> createControls({
    required DashboardPageTemplate template,
    required Size viewport,
    required double gridSize,
    required AppLocalizations l10n,
    required String Function() nextInstanceId,
  }) {
    final canvas = _TemplateCanvas(viewport: viewport, gridSize: gridSize);
    final isPortrait = viewport.height > viewport.width;

    if (canvas.rows < 12 || canvas.cols < (isPortrait ? 6 : 12)) {
      _buildCompactLayout(canvas, template);
    } else if (isPortrait) {
      _buildPortraitLayout(canvas, template);
    } else {
      _buildLandscapeLayout(canvas, template);
    }

    return canvas.placements
        .map((placement) {
          final type = ControlCatalog.byId(placement.typeId);
          if (type == null) {
            throw StateError(
              'Missing dashboard control type: ${placement.typeId}',
            );
          }
          return PlacedControl(
            instanceId: nextInstanceId(),
            type: type,
            col: placement.col,
            row: placement.row,
            cols: placement.cols,
            rows: placement.rows,
          );
        })
        .toList(growable: false);
  }

  static void _buildCompactLayout(
    _TemplateCanvas canvas,
    DashboardPageTemplate template,
  ) {
    canvas.addFull('status_line', canvas.rowsFor(32));
    final controls = switch (template) {
      DashboardPageTemplate.flight => [
        'flight_button',
        'vario',
        'altitude',
        'vertical_speed',
        'compass_wind',
        'vertical_graph',
        'flight_time',
      ],
      DashboardPageTemplate.navigation => [
        'map',
        'nearest_landing_waypoint',
        'default_landing_waypoint',
        'takeoff_waypoint',
        'heading',
        'ground_speed',
        'gps_accuracy',
      ],
      DashboardPageTemplate.conditions => [
        'compass_wind',
        'wind_speed',
        'vertical_graph',
        'thermal_gain',
        'climb_avg',
        'wind_direction',
        'temperature',
      ],
      DashboardPageTemplate.landing => [
        'map',
        'nearest_landing_waypoint',
        'default_landing_waypoint',
        'takeoff_waypoint',
        'distance_to_takeoff',
        'heading',
        'gps_accuracy',
      ],
      DashboardPageTemplate.instrumentConsole => [
        'flight_button',
        'location',
        'data_monitor',
        'heart_rate',
        'sensor_battery',
        'phone_battery',
        'gps_accuracy',
        'flight_time',
      ],
      DashboardPageTemplate.takeoffCheck => [
        'flight_button',
        'compass_wind',
        'takeoff_waypoint',
        'wind_speed',
        'wind_direction',
        'gps_accuracy',
        'altitude',
      ],
    };
    final expandType = switch (template) {
      DashboardPageTemplate.flight => 'vertical_graph',
      DashboardPageTemplate.navigation ||
      DashboardPageTemplate.landing => 'map',
      DashboardPageTemplate.conditions => 'vertical_graph',
      DashboardPageTemplate.instrumentConsole => 'data_monitor',
      DashboardPageTemplate.takeoffCheck => 'compass_wind',
    };
    canvas.addCompactStack(controls, expandType: expandType);
  }

  static void _buildPortraitLayout(
    _TemplateCanvas canvas,
    DashboardPageTemplate template,
  ) {
    final statusRows = canvas.rowsFor(32);
    final readoutRows = canvas.rowsFor(64);
    final waypointRows = canvas.rowsFor(96);

    switch (template) {
      case DashboardPageTemplate.flight:
        canvas.addFull('status_line', statusRows);
        canvas.addFull('flight_button', canvas.rowsFor(80));
        canvas.addPair('altitude', 'vertical_speed', readoutRows);
        canvas.addPair('ground_speed', 'heading', readoutRows);
        canvas.addInstrumentPair(canvas.rowsFor(128));
        canvas.addFlexibleFull('vertical_graph', reserveRows: readoutRows);
        canvas.addPair('flight_time', 'gps_accuracy', readoutRows);
      case DashboardPageTemplate.navigation:
        canvas.addFull('status_line', statusRows);
        final reservedRows = waypointRows * 2 + readoutRows * 2;
        canvas.addFlexibleFull(
          'map',
          reserveRows: reservedRows,
          minimumRows: canvas.rowsFor(180),
        );
        canvas.addFull('nearest_landing_waypoint', waypointRows);
        canvas.addFull('takeoff_waypoint', waypointRows);
        canvas.addPair('heading', 'ground_speed', readoutRows);
        canvas.addFull('gps_accuracy', readoutRows);
      case DashboardPageTemplate.conditions:
        canvas.addFull('status_line', statusRows);
        canvas.addFull('compass_wind', canvas.rowsFor(128));
        canvas.addPair('wind_speed', 'wind_direction', readoutRows);
        canvas.addPair('temperature', 'pressure', readoutRows);
        canvas.addPair('thermal_gain', 'climb_avg', readoutRows);
        canvas.addFlexibleFull('vertical_graph');
      case DashboardPageTemplate.landing:
        canvas.addFull('status_line', statusRows);
        final reservedRows = waypointRows * 3 + readoutRows * 2;
        canvas.addFlexibleFull(
          'map',
          reserveRows: reservedRows,
          minimumRows: canvas.rowsFor(160),
        );
        canvas.addFull('nearest_landing_waypoint', waypointRows);
        canvas.addFull('default_landing_waypoint', waypointRows);
        canvas.addFull('takeoff_waypoint', waypointRows);
        canvas.addPair('distance_to_takeoff', 'heading', readoutRows);
        canvas.addFull('gps_accuracy', readoutRows);
      case DashboardPageTemplate.instrumentConsole:
        canvas.addFull('status_line', statusRows);
        canvas.addFull('flight_button', canvas.rowsFor(80));
        canvas.addFull('location', canvas.rowsFor(72));
        final pairRows = readoutRows * 4;
        canvas.addFlexibleFull(
          'data_monitor',
          reserveRows: pairRows,
          minimumRows: canvas.rowsFor(160),
        );
        canvas.addPair('heart_rate', 'sensor_battery', readoutRows);
        canvas.addPair('phone_battery', 'gps_accuracy', readoutRows);
        canvas.addPair('clock', 'flight_time', readoutRows);
        canvas.addPair('air_time', 'heading', readoutRows);
      case DashboardPageTemplate.takeoffCheck:
        canvas.addFull('status_line', statusRows);
        canvas.addFull('flight_button', canvas.rowsFor(80));
        canvas.addFull('compass_wind', canvas.rowsFor(128));
        canvas.addFull('takeoff_waypoint', waypointRows);
        canvas.addPair('wind_speed', 'wind_direction', readoutRows);
        canvas.addPair('gps_accuracy', 'altitude', readoutRows);
        canvas.addFlexibleFull('map', minimumRows: canvas.rowsFor(160));
    }
  }

  static void _buildLandscapeLayout(
    _TemplateCanvas canvas,
    DashboardPageTemplate template,
  ) {
    final statusRows = canvas.rowsFor(32);
    canvas.addFull('status_line', statusRows);
    final bodyTop = canvas.cursorRow;
    final bodyRows = canvas.rows - bodyTop;
    final readoutRows = canvas.rowsFor(64);
    final waypointRows = canvas.rowsFor(96);

    switch (template) {
      case DashboardPageTemplate.flight:
        final leftWidth = (canvas.cols * 0.20).round();
        final centerWidth = (canvas.cols * 0.32).round();
        final railWidth = canvas.cols - leftWidth - centerWidth;
        canvas.addAt('vario', 0, bodyTop, leftWidth, bodyRows);
        canvas.addAt(
          'vertical_graph',
          leftWidth,
          bodyTop,
          centerWidth,
          bodyRows,
        );
        var railRow = bodyTop;
        final buttonRows = canvas.rowsFor(80);
        canvas.addAt(
          'flight_button',
          leftWidth + centerWidth,
          railRow,
          railWidth,
          buttonRows,
        );
        railRow += buttonRows;
        final compassRows = canvas.rowsFor(128);
        canvas.addAt(
          'compass_wind',
          leftWidth + centerWidth,
          railRow,
          railWidth,
          compassRows,
        );
        railRow += compassRows;
        for (final pair in const [
          ('altitude', 'vertical_speed'),
          ('ground_speed', 'heading'),
          ('flight_time', 'gps_accuracy'),
        ]) {
          canvas.addPairAt(
            pair.$1,
            pair.$2,
            leftWidth + centerWidth,
            railRow,
            railWidth,
            readoutRows,
          );
          railRow += readoutRows;
        }
      case DashboardPageTemplate.navigation:
        final mapWidth = (canvas.cols * 0.60).round();
        final railWidth = canvas.cols - mapWidth;
        canvas.addAt('map', 0, bodyTop, mapWidth, bodyRows);
        var railRow = bodyTop;
        for (final typeId in const [
          'nearest_landing_waypoint',
          'default_landing_waypoint',
          'takeoff_waypoint',
        ]) {
          canvas.addAt(typeId, mapWidth, railRow, railWidth, waypointRows);
          railRow += waypointRows;
        }
        canvas.addPairAt(
          'heading',
          'ground_speed',
          mapWidth,
          railRow,
          railWidth,
          readoutRows,
        );
        railRow += readoutRows;
        canvas.addAt('gps_accuracy', mapWidth, railRow, railWidth, readoutRows);
      case DashboardPageTemplate.conditions:
        final graphWidth = (canvas.cols * 0.52).round();
        final railWidth = canvas.cols - graphWidth;
        canvas.addAt('vertical_graph', 0, bodyTop, graphWidth, bodyRows);
        var railRow = bodyTop;
        final compassRows = canvas.rowsFor(128);
        canvas.addAt(
          'compass_wind',
          graphWidth,
          railRow,
          railWidth,
          compassRows,
        );
        railRow += compassRows;
        for (final pair in const [
          ('wind_speed', 'wind_direction'),
          ('temperature', 'pressure'),
          ('thermal_gain', 'climb_avg'),
          ('heading', 'vertical_speed'),
        ]) {
          canvas.addPairAt(
            pair.$1,
            pair.$2,
            graphWidth,
            railRow,
            railWidth,
            readoutRows,
          );
          railRow += readoutRows;
        }
      case DashboardPageTemplate.landing:
        final mapWidth = (canvas.cols * 0.52).round();
        final railWidth = canvas.cols - mapWidth;
        canvas.addAt('map', 0, bodyTop, mapWidth, bodyRows);
        var railRow = bodyTop;
        for (final typeId in const [
          'nearest_landing_waypoint',
          'default_landing_waypoint',
          'takeoff_waypoint',
        ]) {
          canvas.addAt(typeId, mapWidth, railRow, railWidth, waypointRows);
          railRow += waypointRows;
        }
        canvas.addPairAt(
          'distance_to_takeoff',
          'heading',
          mapWidth,
          railRow,
          railWidth,
          readoutRows,
        );
        railRow += readoutRows;
        canvas.addAt('gps_accuracy', mapWidth, railRow, railWidth, readoutRows);
      case DashboardPageTemplate.instrumentConsole:
        final monitorWidth = (canvas.cols * 0.56).round();
        final railWidth = canvas.cols - monitorWidth;
        canvas.addAt('data_monitor', 0, bodyTop, monitorWidth, bodyRows);
        var railRow = bodyTop;
        final buttonRows = canvas.rowsFor(80);
        canvas.addAt(
          'flight_button',
          monitorWidth,
          railRow,
          railWidth,
          buttonRows,
        );
        railRow += buttonRows;
        final locationRows = canvas.rowsFor(72);
        canvas.addAt(
          'location',
          monitorWidth,
          railRow,
          railWidth,
          locationRows,
        );
        railRow += locationRows;
        for (final pair in const [
          ('heart_rate', 'sensor_battery'),
          ('phone_battery', 'gps_accuracy'),
          ('clock', 'flight_time'),
          ('air_time', 'heading'),
        ]) {
          canvas.addPairAt(
            pair.$1,
            pair.$2,
            monitorWidth,
            railRow,
            railWidth,
            readoutRows,
          );
          railRow += readoutRows;
        }
      case DashboardPageTemplate.takeoffCheck:
        final mapWidth = (canvas.cols * 0.55).round();
        final railWidth = canvas.cols - mapWidth;
        canvas.addAt('map', 0, bodyTop, mapWidth, bodyRows);
        var railRow = bodyTop;
        final buttonRows = canvas.rowsFor(80);
        canvas.addAt('flight_button', mapWidth, railRow, railWidth, buttonRows);
        railRow += buttonRows;
        final compassRows = canvas.rowsFor(128);
        canvas.addAt('compass_wind', mapWidth, railRow, railWidth, compassRows);
        railRow += compassRows;
        final waypointHeight = canvas.rowsFor(96);
        canvas.addAt(
          'takeoff_waypoint',
          mapWidth,
          railRow,
          railWidth,
          waypointHeight,
        );
        railRow += waypointHeight;
        canvas.addPairAt(
          'wind_speed',
          'wind_direction',
          mapWidth,
          railRow,
          railWidth,
          readoutRows,
        );
        railRow += readoutRows;
        canvas.addPairAt(
          'gps_accuracy',
          'altitude',
          mapWidth,
          railRow,
          railWidth,
          readoutRows,
        );
    }
  }
}

class _TemplateCanvas {
  _TemplateCanvas({required Size viewport, required double gridSize})
    : cols = (viewport.width / gridSize).round().clamp(1, 1000),
      rows = (viewport.height / gridSize).round().clamp(1, 1000),
      cellWidth =
          viewport.width / (viewport.width / gridSize).round().clamp(1, 1000),
      cellHeight =
          viewport.height / (viewport.height / gridSize).round().clamp(1, 1000);

  final int cols;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final List<_ControlPlacement> placements = [];
  int cursorRow = 0;

  int rowsFor(double pixels) => (pixels / cellHeight).ceil().clamp(1, rows);

  int colsFor(double pixels) => (pixels / cellWidth).ceil().clamp(1, cols);

  void addFull(String typeId, int height) {
    if (cursorRow >= rows) return;
    final fittedHeight = height.clamp(1, rows - cursorRow);
    addAt(typeId, 0, cursorRow, cols, fittedHeight);
    cursorRow += fittedHeight;
  }

  void addPair(String firstTypeId, String secondTypeId, int height) {
    if (cols < 6) {
      addFull(firstTypeId, height);
      addFull(secondTypeId, height);
      return;
    }
    if (cursorRow >= rows) return;
    final leftWidth = cols ~/ 2;
    final fittedHeight = height.clamp(1, rows - cursorRow);
    addAt(firstTypeId, 0, cursorRow, leftWidth, fittedHeight);
    addAt(secondTypeId, leftWidth, cursorRow, cols - leftWidth, fittedHeight);
    cursorRow += fittedHeight;
  }

  void addInstrumentPair(int height) {
    if (colsFor(100) + colsFor(128) > cols) {
      addFull('vario', height);
      addFull('compass_wind', height);
      return;
    }
    if (cursorRow >= rows) return;
    final varioWidth = colsFor(100).clamp(1, cols - 1);
    final fittedHeight = height.clamp(1, rows - cursorRow);
    addAt('vario', 0, cursorRow, varioWidth, fittedHeight);
    addAt(
      'compass_wind',
      varioWidth,
      cursorRow,
      cols - varioWidth,
      fittedHeight,
    );
    cursorRow += fittedHeight;
  }

  void addFlexibleFull(
    String typeId, {
    int reserveRows = 0,
    int minimumRows = 1,
  }) {
    if (cursorRow >= rows) return;
    final availableRows = rows - cursorRow;
    final maxRows = (availableRows - reserveRows).clamp(1, availableRows);
    addFull(typeId, math.max(minimumRows, maxRows).clamp(1, availableRows));
  }

  void addCompactStack(List<String> typeIds, {required String expandType}) {
    final remainingRows = rows - cursorRow;
    if (remainingRows <= 0) return;
    final visibleTypes = typeIds.take(remainingRows).toList();
    if (visibleTypes.isEmpty) return;
    final extraRows = remainingRows - visibleTypes.length;
    var expandIndex = visibleTypes.indexOf(expandType);
    if (expandIndex < 0) expandIndex = visibleTypes.length - 1;
    final heights = List<int>.filled(visibleTypes.length, 1);
    heights[expandIndex] += extraRows;
    for (var index = 0; index < visibleTypes.length; index++) {
      addFull(visibleTypes[index], heights[index]);
    }
  }

  void addPairAt(
    String firstTypeId,
    String secondTypeId,
    int col,
    int row,
    int width,
    int height,
  ) {
    if (row >= rows || col >= cols || width <= 0) return;
    final fittedHeight = height.clamp(1, rows - row);
    final firstWidth = width ~/ 2;
    if (firstWidth <= 0 || width - firstWidth <= 0) return;
    addAt(firstTypeId, col, row, firstWidth, fittedHeight);
    addAt(
      secondTypeId,
      col + firstWidth,
      row,
      width - firstWidth,
      fittedHeight,
    );
  }

  void addAt(String typeId, int col, int row, int width, int height) {
    if (row < 0 || col < 0 || row >= rows || col >= cols) return;
    final fittedWidth = width.clamp(1, cols - col);
    final fittedHeight = height.clamp(1, rows - row);
    placements.add(
      _ControlPlacement(
        typeId: typeId,
        col: col,
        row: row,
        cols: fittedWidth,
        rows: fittedHeight,
      ),
    );
  }
}

class _ControlPlacement {
  const _ControlPlacement({
    required this.typeId,
    required this.col,
    required this.row,
    required this.cols,
    required this.rows,
  });

  final String typeId;
  final int col;
  final int row;
  final int cols;
  final int rows;
}
