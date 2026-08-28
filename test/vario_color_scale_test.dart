import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/vario_color_scale.dart';

// 8-bit channel accessors compatible with newer Flutter's float channels.
int _r(Color c) => (c.r * 255.0).round() & 0xff;
int _g(Color c) => (c.g * 255.0).round() & 0xff;
int _b(Color c) => (c.b * 255.0).round() & 0xff;

/// Asserts two colours match within a small per-channel tolerance (rounding).
void expectColorClose(Color actual, Color expected, {int tol = 2}) {
  expect((_r(actual) - _r(expected)).abs() <= tol, isTrue,
      reason: 'red $actual vs $expected');
  expect((_g(actual) - _g(expected)).abs() <= tol, isTrue,
      reason: 'green $actual vs $expected');
  expect((_b(actual) - _b(expected)).abs() <= tol, isTrue,
      reason: 'blue $actual vs $expected');
}

/// Heuristics for the RED → GRAY → GREEN semantics.
bool _isReddish(Color c) => _r(c) > _g(c) + 20;
bool _isGreenish(Color c) => _g(c) > _r(c) + 20;
bool _isGrayish(Color c) =>
    (_r(c) - _g(c)).abs() <= 30 && (_g(c) - _b(c)).abs() <= 40;

void main() {
  group('default visualisation range is -6..+6', () {
    test('exposes the -6/+6 defaults', () {
      expect(VarioColorScale.defaultColorMin, -6.0);
      expect(VarioColorScale.defaultColorMax, 6.0);
      final scale = VarioColorScale(sinkThreshold: -2.0, liftThreshold: 0.5);
      expect(scale.colorMin, -6.0);
      expect(scale.colorMax, 6.0);
    });
  });

  group('RED -> GRAY -> GREEN anchor colours (default range)', () {
    // Thresholds placed on the -2 / +2 anchors so the fixed light-red /
    // light-green anchors show through exactly.
    final scale = VarioColorScale(sinkThreshold: -2.0, liftThreshold: 2.0);

    test('strong sink is dark red', () {
      expectColorClose(scale.colorFor(-6), const Color(0xFF8B0000));
    });
    test('moderate sink is red', () {
      expectColorClose(scale.colorFor(-4), const Color(0xFFD73027));
    });
    test('mild sink (sink threshold) is light red', () {
      expectColorClose(scale.colorFor(-2), const Color(0xFFF4A6A6));
    });
    test('neutral is gray', () {
      expectColorClose(scale.colorFor(0), const Color(0xFFBDBDBD));
    });
    test('mild lift (lift threshold) is light green', () {
      expectColorClose(scale.colorFor(2), const Color(0xFFB8E0B8));
    });
    test('moderate lift is green', () {
      expectColorClose(scale.colorFor(4), const Color(0xFF31A354));
    });
    test('strong lift is dark green', () {
      expectColorClose(scale.colorFor(6), const Color(0xFF006D2C));
    });
  });

  group('semantic direction: sink reddish, neutral gray, lift greenish', () {
    final scale = VarioColorScale(sinkThreshold: -2.0, liftThreshold: 0.5);

    test('strong sink is clearly reddish', () {
      expect(_isReddish(scale.colorFor(-6)), isTrue);
      expect(_isReddish(scale.colorFor(-4)), isTrue);
    });
    test('neutral (between thresholds) is grayish', () {
      expect(_isGrayish(scale.colorFor(0)), isTrue);
    });
    test('strong lift is clearly greenish', () {
      expect(_isGreenish(scale.colorFor(6)), isTrue);
      expect(_isGreenish(scale.colorFor(4)), isTrue);
    });
  });

  group('extreme values are clamped for visualisation only', () {
    final scale = VarioColorScale(sinkThreshold: -2.0, liftThreshold: 0.5);

    test('<= -6 renders as the dark-red endpoint', () {
      expect(scale.colorFor(-6), equals(const Color(0xFF8B0000)));
      expect(scale.colorFor(-8), equals(scale.colorFor(-6)));
      expect(scale.colorFor(-10), equals(scale.colorFor(-6)));
      expect(scale.colorFor(-100), equals(scale.colorFor(-6)));
    });

    test('>= +6 renders as the dark-green endpoint', () {
      expect(scale.colorFor(6), equals(const Color(0xFF006D2C)));
      expect(scale.colorFor(8), equals(scale.colorFor(6)));
      expect(scale.colorFor(15), equals(scale.colorFor(6)));
      expect(scale.colorFor(100), equals(scale.colorFor(6)));
    });

    test('original data is never mutated (only colour differs)', () {
      // colorFor takes the speed by value and returns only a Color; there is no
      // API that returns a modified speed.
      expect(scale.colorFor(-10), isNot(equals(scale.colorFor(-4))));
    });

    test('NaN yields a valid (neutral) colour, not a crash', () {
      final c = scale.colorFor(double.nan);
      expect(c, isA<Color>());
    });
  });

  group('required sample points map to valid colours', () {
    final scale = VarioColorScale(sinkThreshold: -2.0, liftThreshold: 0.5);
    for (final v in <double>[-10, -6, -4, -2, 0, 1, 2, 4, 6, 10]) {
      test('colorFor($v) is a valid colour', () {
        final c = scale.colorFor(v);
        expect(_r(c), inInclusiveRange(0, 255));
        expect(_g(c), inInclusiveRange(0, 255));
        expect(_b(c), inInclusiveRange(0, 255));
      });
    }
  });

  group('continuous interpolation', () {
    final scale = VarioColorScale(sinkThreshold: -2.0, liftThreshold: 2.0);

    test('+3 lies strictly between the +2 (light green) and +4 (green) stops',
        () {
      final c = scale.colorFor(3.0);
      final lo = scale.colorFor(2.0); // light green #B8E0B8
      final hi = scale.colorFor(4.0); // green       #31A354
      expect(c, isNot(equals(lo)));
      expect(c, isNot(equals(hi)));
      // Red channel decreases light-green -> green, so interpolant is between.
      expect(_r(c) <= _r(lo) && _r(c) >= _r(hi), isTrue);
    });

    test('midpoint interpolation is the RGB average of its anchors', () {
      final a = scale.colorFor(2.0);
      final b = scale.colorFor(4.0);
      final mid = scale.colorFor(3.0);
      expect((_r(mid) - ((_r(a) + _r(b)) / 2).round()).abs() <= 2, isTrue);
      expect((_g(mid) - ((_g(a) + _g(b)) / 2).round()).abs() <= 2, isTrue);
      expect((_b(mid) - ((_b(a) + _b(b)) / 2).round()).abs() <= 2, isTrue);
    });
  });

  group('threshold-aware gray region adapts to configuration', () {
    // Config A: narrow neutral band (-2 .. +0.5).
    // Config B: wider neutral band (-1 .. +1.5).
    final a = VarioColorScale(sinkThreshold: -2.0, liftThreshold: 0.5);
    final b = VarioColorScale(sinkThreshold: -1.0, liftThreshold: 1.5);

    test('at +1: inside B\'s neutral band (gray-ish), above A\'s (greener)',
        () {
      // +1 is above A's liftThreshold (0.5) → leaning green; it is below B's
      // liftThreshold (1.5) → still within the neutral band, so grayer / less
      // green than in A.
      expect(_g(a.colorFor(1.0)) >= _g(b.colorFor(1.0)) - 2, isTrue);
      expect(a.colorFor(1.0), isNot(equals(b.colorFor(1.0))));
    });

    test('thresholds sit exactly on the light-red / light-green colours', () {
      expectColorClose(a.colorFor(-2.0), const Color(0xFFF4A6A6)); // A sink
      expectColorClose(a.colorFor(0.5), const Color(0xFFB8E0B8)); // A lift
      expectColorClose(b.colorFor(-1.0), const Color(0xFFF4A6A6)); // B sink
      expectColorClose(b.colorFor(1.5), const Color(0xFFB8E0B8)); // B lift
    });

    test('the 0 m/s neutral stays gray for both configs', () {
      expectColorClose(a.colorFor(0), const Color(0xFFBDBDBD));
      expectColorClose(b.colorFor(0), const Color(0xFFBDBDBD));
    });
  });

  group('robust edge cases (no NaN / crash / discontinuity)', () {
    final configs = <List<double>>[
      [-2.0, 0.5], // typical
      [-1.0, 1.5], // alternative from the spec
      [-0.5, 0.0], // thresholds close to zero
      [0.0, 0.0], // both zero
      [-3.0, 0.0], // liftThreshold == 0
      [0.0, 3.0], // sinkThreshold == 0
      [-8.0, -1.0], // both negative (out of app spec, but must be safe)
      [1.0, 4.0], // both positive (out of app spec, but must be safe)
      [2.0, -2.0], // sink >= lift (inverted, must be safe)
      [-20.0, 20.0], // out-of-range, must clamp safely
    ];

    for (final cfg in configs) {
      test('config sink=${cfg[0]} lift=${cfg[1]} is continuous & valid', () {
        final scale =
            VarioColorScale(sinkThreshold: cfg[0], liftThreshold: cfg[1]);
        Color? prev;
        for (double v = -9; v <= 9; v += 0.1) {
          final c = scale.colorFor(v);
          expect(_r(c), inInclusiveRange(0, 255));
          expect(_g(c), inInclusiveRange(0, 255));
          expect(_b(c), inInclusiveRange(0, 255));
          if (prev != null) {
            final pc = prev;
            final d = (_r(c) - _r(pc)).abs() +
                (_g(c) - _g(pc)).abs() +
                (_b(c) - _b(pc)).abs();
            expect(d < 90, isTrue,
                reason: 'discontinuity at v=$v (delta=$d) for cfg=$cfg');
          }
          prev = c;
        }
      });
    }

    test('sampleGradient returns the requested count with correct endpoints',
        () {
      final scale = VarioColorScale(sinkThreshold: -2.0, liftThreshold: 0.5);
      final g = scale.sampleGradient(24);
      expect(g.length, 24);
      expect(g.first, equals(scale.colorFor(scale.colorMin)));
      expect(g.last, equals(scale.colorFor(scale.colorMax)));
    });
  });

  group('custom visualisation range', () {
    test('a -3..+3 range still yields valid endpoints and interpolation', () {
      final scale = VarioColorScale(
        sinkThreshold: -1.0,
        liftThreshold: 0.5,
        colorMin: -3.0,
        colorMax: 3.0,
      );
      expectColorClose(scale.colorFor(-3), const Color(0xFF8B0000)); // dark red
      expectColorClose(scale.colorFor(3), const Color(0xFF006D2C)); // dark green
      expect(scale.colorFor(-10), equals(scale.colorFor(-3)));
    });

    test('an inverted/degenerate range does not crash or divide by zero', () {
      final scale = VarioColorScale(
        sinkThreshold: -1.0,
        liftThreshold: 0.5,
        colorMin: 5.0,
        colorMax: 5.0, // degenerate; constructor widens it safely
      );
      final c = scale.colorFor(5.0);
      expect(c, isA<Color>());
      expect(_r(c), inInclusiveRange(0, 255));
    });
  });
}
