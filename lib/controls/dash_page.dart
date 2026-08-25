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
