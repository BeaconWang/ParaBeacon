import 'dart:convert';

import 'package:flutter/material.dart';

import '../controls/placed_control.dart';
import '../l10n/app_localizations.dart';
import 'imported_page_template_data.dart';

enum DashboardPageTemplate { defaultLayout, goLanding }

extension DashboardPageTemplateDetails on DashboardPageTemplate {
  IconData get icon => switch (this) {
    DashboardPageTemplate.defaultLayout => Icons.dashboard_outlined,
    DashboardPageTemplate.goLanding => Icons.flight_land,
  };

  String titleOf(AppLocalizations _) => switch (this) {
    DashboardPageTemplate.defaultLayout => 'Default',
    DashboardPageTemplate.goLanding => 'Land',
  };

  String descriptionOf(AppLocalizations l10n) => switch (this) {
    DashboardPageTemplate.defaultLayout =>
      l10n.dashboardTemplateFlightDescription,
    DashboardPageTemplate.goLanding => l10n.dashboardTemplateLandingDescription,
  };
}

class DashboardPageTemplates {
  const DashboardPageTemplates._();

  static const List<DashboardPageTemplate> all = DashboardPageTemplate.values;

  static final Map<DashboardPageTemplate, List<PlacedControl>> _sourceControls =
      {
        for (final template in all)
          template: _loadSourceControls(_templateJson(template)),
      };

  static String _templateJson(DashboardPageTemplate template) =>
      switch (template) {
        DashboardPageTemplate.defaultLayout => defaultTemplateJson,
        DashboardPageTemplate.goLanding => goLandingTemplateJson,
      };

  static List<PlacedControl> _loadSourceControls(String json) {
    final bundle = jsonDecode(json) as Map<String, dynamic>;
    final pages = bundle['pages'] as List<dynamic>;
    final page = pages.single as Map<String, dynamic>;
    final controls = page['controls'] as List<dynamic>;
    return controls
        .map(
          (control) =>
              PlacedControl.fromJson(Map<String, dynamic>.from(control as Map)),
        )
        .whereType<PlacedControl>()
        .toList(growable: false);
  }

  static List<PlacedControl> createControls({
    required DashboardPageTemplate template,
    required Size viewport,
    required double gridSize,
    required String Function() nextInstanceId,
  }) {
    final sourceControls = _sourceControls[template]!;
    final cols = (viewport.width / gridSize).round().clamp(1, 1000);
    final rows = (viewport.height / gridSize).round().clamp(1, 1000);
    final columnEdges = _edgesFor(
      sourceControls,
      (control) => [control.col, control.col + control.cols],
    );
    final rowEdges = _edgesFor(
      sourceControls,
      (control) => [control.row, control.row + control.rows],
    );
    final mappedColumns = _mapEdges(columnEdges, cols);
    final mappedRows = _mapEdges(rowEdges, rows);

    if (mappedColumns == null || mappedRows == null) {
      return _createCompactControls(
        template: template,
        sourceControls: sourceControls,
        cols: cols,
        rows: rows,
        nextInstanceId: nextInstanceId,
      );
    }

    return sourceControls
        .map(
          (source) => _copyControl(
            source,
            instanceId: nextInstanceId(),
            col: mappedColumns[source.col]!,
            row: mappedRows[source.row]!,
            cols:
                mappedColumns[source.col + source.cols]! -
                mappedColumns[source.col]!,
            rows:
                mappedRows[source.row + source.rows]! - mappedRows[source.row]!,
          ),
        )
        .toList(growable: false);
  }

  static List<int> _edgesFor(
    List<PlacedControl> controls,
    List<int> Function(PlacedControl) edgesForControl,
  ) {
    final edges = <int>{};
    for (final control in controls) {
      edges.addAll(edgesForControl(control));
    }
    return edges.toList()..sort();
  }

  static Map<int, int>? _mapEdges(List<int> edges, int targetExtent) {
    if (edges.length < 2 || targetExtent < edges.length - 1) return null;
    final sourceExtent = edges.last;
    if (sourceExtent <= 0) return null;

    final mapped = <int, int>{};
    for (var index = 0; index < edges.length; index++) {
      final edge = edges[index];
      final minValue = index == 0 ? 0 : mapped[edges[index - 1]]! + 1;
      final maxValue = targetExtent - (edges.length - index - 1);
      final preferred = (edge * targetExtent / sourceExtent).round();
      mapped[edge] = preferred.clamp(minValue, maxValue);
    }
    return mapped;
  }

  static List<PlacedControl> _createCompactControls({
    required DashboardPageTemplate template,
    required List<PlacedControl> sourceControls,
    required int cols,
    required int rows,
    required String Function() nextInstanceId,
  }) {
    final priority = switch (template) {
      DashboardPageTemplate.defaultLayout => const [
        'status_line',
        'map',
        'flight_button',
        'vario',
        'compass_wind',
        'vertical_graph',
      ],
      DashboardPageTemplate.goLanding => const [
        'map',
        'default_landing_waypoint',
        'nearest_landing_waypoint',
      ],
    };
    final controlsByType = {
      for (final control in sourceControls) control.type.id: control,
    };
    final visible = priority
        .map((typeId) => controlsByType[typeId])
        .whereType<PlacedControl>()
        .take(rows)
        .toList(growable: false);
    if (visible.isEmpty) return const [];

    final expandedIndex = visible.indexWhere(
      (control) => control.type.id == 'map',
    );
    final targetIndex = expandedIndex < 0 ? 0 : expandedIndex;
    final extraRows = rows - visible.length;
    var row = 0;
    final result = <PlacedControl>[];
    for (var index = 0; index < visible.length; index++) {
      final height = index == targetIndex ? 1 + extraRows : 1;
      result.add(
        _copyControl(
          visible[index],
          instanceId: nextInstanceId(),
          col: 0,
          row: row,
          cols: cols,
          rows: height,
        ),
      );
      row += height;
    }
    return result;
  }

  static PlacedControl _copyControl(
    PlacedControl source, {
    required String instanceId,
    required int col,
    required int row,
    required int cols,
    required int rows,
  }) {
    return PlacedControl(
      instanceId: instanceId,
      type: source.type,
      col: col,
      row: row,
      cols: cols,
      rows: rows,
      settings: Map<String, dynamic>.from(source.settings),
    );
  }
}
