import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/waypoint_bearing_labels.dart';
import 'package:parabeacon/l10n/app_localizations_en.dart';
import 'package:parabeacon/l10n/app_localizations_zh.dart';

void main() {
  test('formats relative bearings as English position labels', () {
    const labels = [
      'Ahead',
      'Right front',
      'Right',
      'Right back',
      'Behind',
      'Left back',
      'Left',
      'Left front',
    ];
    final l10n = AppLocalizationsEn();

    for (var i = 0; i < labels.length; i++) {
      expect(relativeBearingPositionLabel(l10n, i * 45.0), labels[i]);
    }
    expect(relativeBearingPositionLabel(l10n, 360), 'Ahead');
    expect(relativeBearingPositionLabel(l10n, -45), 'Left front');
  });

  test('formats relative bearings as Chinese position labels', () {
    const labels = ['前方', '右前方', '右侧', '右后方', '后方', '左后方', '左侧', '左前方'];
    final l10n = AppLocalizationsZh();

    for (var i = 0; i < labels.length; i++) {
      expect(relativeBearingPositionLabel(l10n, i * 45.0), labels[i]);
    }
  });
}
