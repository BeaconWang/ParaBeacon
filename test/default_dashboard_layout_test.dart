import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/default_dashboard_layout.dart';
import 'package:parabeacon/l10n/app_localizations_en.dart';

void main() {
  for (final viewport in [const Size(360, 640), const Size(800, 480)]) {
    test('starter pages fit without overlapping at $viewport', () {
      const gridSize = 32.0;
      final cols = (viewport.width / gridSize).round();
      final rows = (viewport.height / gridSize).round();
      final pages = DefaultDashboardLayout.create(
        viewport: viewport,
        gridSize: gridSize,
        l10n: AppLocalizationsEn(),
      );

      expect(pages.map((page) => page.title), [
        'Flight',
        'Navigation',
        'Conditions',
      ]);
      expect(
        pages.first.controls.map((control) => control.type.id),
        contains('flight_button'),
      );
      expect(
        pages[1].controls.map((control) => control.type.id),
        contains('map'),
      );
      expect(
        pages[2].controls.map((control) => control.type.id),
        contains('wind_speed'),
      );

      final instanceIds = <String>{};
      for (final page in pages) {
        for (var i = 0; i < page.controls.length; i++) {
          final control = page.controls[i];
          expect(instanceIds.add(control.instanceId), isTrue);
          expect(control.col, greaterThanOrEqualTo(0));
          expect(control.row, greaterThanOrEqualTo(0));
          expect(control.col + control.cols, lessThanOrEqualTo(cols));
          expect(control.row + control.rows, lessThanOrEqualTo(rows));

          for (var j = i + 1; j < page.controls.length; j++) {
            final other = page.controls[j];
            final overlapsX =
                control.col < other.col + other.cols &&
                control.col + control.cols > other.col;
            final overlapsY =
                control.row < other.row + other.rows &&
                control.row + control.rows > other.row;
            expect(
              overlapsX && overlapsY,
              isFalse,
              reason:
                  '${control.type.id} overlaps ${other.type.id} on ${page.title}',
            );
          }
        }
      }
    });
  }
}
