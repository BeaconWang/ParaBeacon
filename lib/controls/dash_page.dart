import 'package:flutter/material.dart';

import 'placed_control.dart';

/// A single dashboard page holding its own set of placed controls.
///
/// The app supports multiple pages (like tabs); the user swipes horizontally
/// to switch between them in view mode, and can add pages in edit mode.
class DashPage {
  final String id;

  /// Controls placed on this page. Draw order = list order (last = top).
  final List<PlacedControl> controls;

  /// Customizable header icon shown in the page indicator / header.
  IconData icon;

  /// Optional custom title for the page.
  String? title;

  DashPage({
    required this.id,
    List<PlacedControl>? controls,
    this.icon = Icons.dashboard_outlined,
    this.title,
  }) : controls = controls ?? [];

  /// Serializes this page (and its controls) to a JSON-safe map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'iconCodePoint': icon.codePoint,
        'title': title,
        'controls': controls.map((c) => c.toJson()).toList(),
      };

  /// Rebuilds a page from [toJson] output, dropping any controls whose type is
  /// no longer known.
  factory DashPage.fromJson(Map<String, dynamic> json) {
    final controlsJson = json['controls'];
    final controls = <PlacedControl>[];
    if (controlsJson is List) {
      for (final c in controlsJson) {
        if (c is Map<String, dynamic>) {
          final pc = PlacedControl.fromJson(c);
          if (pc != null) controls.add(pc);
        }
      }
    }
    return DashPage(
      id: (json['id'] as String?) ?? 'page',
      controls: controls,
      icon: _iconFromCodePoint(json['iconCodePoint'] as int?),
      title: json['title'] as String?,
    );
  }

  /// Maps a persisted icon code point back to one of the known header icons
  /// (falls back to the default). Restricting to [kPageHeaderIcons] keeps the
  /// icons tree-shakeable (no dynamic IconData construction).
  static IconData _iconFromCodePoint(int? codePoint) {
    if (codePoint == null) return Icons.dashboard_outlined;
    for (final icon in kPageHeaderIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.dashboard_outlined;
  }
}

/// The set of icons the user can pick for a page header.
const List<IconData> kPageHeaderIcons = [
  Icons.dashboard_outlined,
  Icons.home_outlined,
  Icons.flight_takeoff,
  Icons.explore_outlined,
  Icons.map_outlined,
  Icons.speed,
  Icons.terrain,
  Icons.air,
  Icons.navigation_outlined,
  Icons.timer_outlined,
  Icons.show_chart,
  Icons.settings_outlined,
  Icons.star_outline,
  Icons.favorite_outline,
  Icons.flag_outlined,
  Icons.bolt,
];
