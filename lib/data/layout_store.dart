import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controls/dash_page.dart';

/// The persisted dashboard layout: the list of pages (with their controls) plus
/// the grid cell size.
@immutable
class SavedLayout {
  const SavedLayout({required this.pages, required this.gridSize});

  final List<DashPage> pages;
  final double gridSize;
}

/// Persists and restores the dashboard layout (pages, placed controls and their
/// settings, and the grid size) via [SharedPreferences].
///
/// Saving is **debounced** so a burst of edits (dragging, resizing) results in a
/// single write shortly after the user settles, rather than one write per frame.
class LayoutStore {
  LayoutStore._();
  static final LayoutStore instance = LayoutStore._();

  static const _kLayoutKey = 'pb.layout.v1';

  /// Bump when the serialized shape changes incompatibly.
  static const _schemaVersion = 1;

  Timer? _debounce;

  /// Loads the saved layout, or null if none exists / it can't be parsed.
  Future<SavedLayout?> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kLayoutKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if ((decoded['version'] as num?)?.toInt() != _schemaVersion) return null;

      final pagesJson = decoded['pages'];
      if (pagesJson is! List) return null;

      final pages = <DashPage>[];
      for (final p in pagesJson) {
        if (p is Map<String, dynamic>) {
          pages.add(DashPage.fromJson(p));
        }
      }
      if (pages.isEmpty) return null;

      final gridSize = (decoded['gridSize'] as num?)?.toDouble() ?? 40.0;
      return SavedLayout(pages: pages, gridSize: gridSize);
    } catch (_) {
      // Corrupt / incompatible data: fall back to defaults.
      return null;
    }
  }

  /// Schedules a debounced save of the given layout.
  void save({
    required List<DashPage> pages,
    required double gridSize,
    Duration debounce = const Duration(milliseconds: 400),
  }) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => _writeNow(pages, gridSize));
  }

  /// Writes immediately, cancelling any pending debounced save (e.g. call this
  /// when the app is being paused/closed).
  Future<void> flush({
    required List<DashPage> pages,
    required double gridSize,
  }) async {
    _debounce?.cancel();
    _debounce = null;
    await _writeNow(pages, gridSize);
  }

  Future<void> _writeNow(List<DashPage> pages, double gridSize) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'version': _schemaVersion,
        'gridSize': gridSize,
        'pages': pages.map((p) => p.toJson()).toList(),
      });
      await sp.setString(_kLayoutKey, payload);
    } catch (_) {
      // Best-effort persistence; ignore storage failures.
    }
  }
}
