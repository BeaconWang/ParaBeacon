import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

/// Which data layer the full-screen background visualization renders.
/// Mirrors Windy's layer switcher — all layers are derived from the same
/// Open-Meteo state (no external radar/tile source required):
///  * [wind]          — 2D particle flow field driven by wind speed/dir
///  * [temperature]   — particle flow tinted by the temperature palette
///  * [precipitation] — falling rain streaks, density by probability
///  * [clouds]        — drifting soft cloud masses, opacity by cover
enum WindyLayer { wind, temperature, precipitation, clouds }

/// Resolved, layer-ready values for the background animation. The screen
/// computes these from the unified [WeatherData] (canonical units: km/h,
/// °C, %) so the animation stays unit-agnostic.
class WindyBackgroundData {
  /// Mean wind speed in km/h.
  final double windKmh;

  /// Wind direction in degrees (the direction the wind comes FROM).
  final double windDirection;

  /// Temperature in °C (for the temperature palette), null when unknown.
  final double? temperatureC;

  /// Precipitation probability 0..100, null when unknown.
  final double? precipProbability;

  /// Cloud cover 0..100, null when unknown.
  final double? cloudCover;

  const WindyBackgroundData({
    required this.windKmh,
    required this.windDirection,
    this.temperatureC,
    this.precipProbability,
    this.cloudCover,
  });

  /// Gentle idle field shown before any data arrives.
  static const WindyBackgroundData idle = WindyBackgroundData(
    windKmh: 12,
    windDirection: 250,
  );
}

/// Full-screen animated weather background (Windy-like). Owns the particle
/// simulation and repaints it every animation tick through a CustomPainter
/// whose `repaint` listens to the driving controller.
class WindyBackground extends StatefulWidget {
  const WindyBackground({
    required this.layer,
    required this.data,
    super.key,
  });

  final WindyLayer layer;
  final WindyBackgroundData data;

  @override
  State<WindyBackground> createState() => _WindyBackgroundState();
}

class _WindyBackgroundState extends State<WindyBackground>
    with SingleTickerProviderStateMixin {
  /// Per-vsync frame ticker driving the particle simulation.
  ///
  /// A raw Ticker instead of an AnimationController: the simulation only
  /// needs the elapsed-time delta between frames, and
  /// `AnimationController.repeat()` on an unbounded controller would throw
  /// ("called without an explicit period and with no default Duration")
  /// while a bounded one would wrap its value into 0..1 — neither models a
  /// clock. The tick also bumps [_frame] so the painter repaints each frame.
  late final Ticker _ticker = createTicker(_onTick);

  final _Field _field = _Field();

  /// Notified every frame; used as the CustomPainter's repaint listenable.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // Clamp dt (tab pauses / debugger stalls) so particles don't teleport.
    _field.tick(dt.clamp(0.0, 0.05));
    _frame.value = ++_frameCount;
  }

  @override
  void didUpdateWidget(WindyBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer != widget.layer) {
      _field.reseed();
    }
    _field.data = widget.data;
    _field.layer = widget.layer;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _field.configure(size, widget.layer, widget.data);
        return CustomPaint(
          size: size,
          painter: _WindyPainter(
            field: _field,
            repaint: _frame,
          ),
        );
      },
    );
  }
}

// ── Simulation ───────────────────────────────────────────────────────────────

/// One particle. For flow layers [trail] keeps the last few positions so
/// the painter can draw Windy-style streaks; rain/clouds use fewer or none.
/// [tempSample] carries this particle's pseudo-local temperature for the
/// temperature layer's palette (unused otherwise).
class _P {
  double x = 0, y = 0;
  double px = 0, py = 0; // previous position (velocity rendering)
  double vx = 0, vy = 0;
  double life = 0, maxLife = 0;
  double jitter = 1;
  double alpha = 1;
  double size = 1;
  double tempSample = 0;
  final List<Offset> trail = [];
}

class _Field {
  WindyLayer layer = WindyLayer.wind;
  WindyBackgroundData data = WindyBackgroundData.idle;
  Size size = Size.zero;
  final List<_P> particles = [];
  final math.Random _rng = math.Random();
  // Cloud layer uses dedicated blobs.
  final List<_P> blobs = [];

  void configure(Size newSize, WindyLayer newLayer, WindyBackgroundData newData) {
    final resized = size != newSize;
    size = newSize;
    data = newData;
    layer = newLayer;
    if (resized && size != Size.zero) reseed();
  }

  void reseed() {
    if (size == Size.zero) return;
    particles.clear();
    blobs.clear();
    switch (layer) {
      case WindyLayer.precipitation:
        final prob = (data.precipProbability ?? 30).clamp(0, 100);
        final count = (60 + prob * 3.2).round().clamp(40, 420);
        for (var i = 0; i < count; i++) {
          particles.add(_newRain(seed: true));
        }
        break;
      case WindyLayer.clouds:
        final cover = (data.cloudCover ?? 50).clamp(0, 100);
        final count = (6 + cover / 6).round().clamp(5, 22);
        for (var i = 0; i < count; i++) {
          blobs.add(_newBlob(seed: true, maxCount: count));
        }
        break;
      case WindyLayer.wind:
      case WindyLayer.temperature:
        final area = size.width * size.height;
        final count = (area / 7000).round().clamp(140, 420);
        for (var i = 0; i < count; i++) {
          particles.add(_newFlow(seed: true));
        }
        break;
    }
  }

  _P _newFlow({bool seed = false}) {
    final p = _P();
    p.x = _rng.nextDouble() * size.width;
    p.y = _rng.nextDouble() * size.height;
    p.maxLife = 1.5 + _rng.nextDouble() * 3.5;
    p.life = seed ? _rng.nextDouble() * p.maxLife : 0;
    p.jitter = 0.55 + _rng.nextDouble() * 0.9;
    p.alpha = 0.18 + _rng.nextDouble() * 0.4;
    p.size = 0.9 + _rng.nextDouble() * 0.8;
    p.trail.clear();
    return p;
  }

  _P _newRain({bool seed = false}) {
    final p = _P();
    p.x = _rng.nextDouble() * (size.width + 120) - 60;
    p.y = seed ? _rng.nextDouble() * size.height : -_rng.nextDouble() * 80;
    p.maxLife = 6;
    p.life = 0;
    p.alpha = 0.15 + _rng.nextDouble() * 0.35;
    p.size = 6 + _rng.nextDouble() * 12; // streak length
    return p;
  }

  _P _newBlob({required bool seed, required int maxCount}) {
    final p = _P();
    p.x = _rng.nextDouble() * (size.width + 400) - 200;
    p.y = _rng.nextDouble() * size.height;
    p.size = 60 + _rng.nextDouble() * 130;
    p.alpha = (0.05 + _rng.nextDouble() * 0.10) *
        ((data.cloudCover ?? 60) / 100).clamp(0.3, 1.0);
    p.jitter = 0.35 + _rng.nextDouble() * 0.85; // parallax speed factor
    p.maxLife = double.infinity;
    p.life = 0;
    return p;
  }

  void tick(double dt) {
    if (size == Size.zero || dt <= 0) return;
    switch (layer) {
      case WindyLayer.wind:
      case WindyLayer.temperature:
        _tickFlow(dt);
        break;
      case WindyLayer.precipitation:
        _tickRain(dt);
        break;
      case WindyLayer.clouds:
        _tickClouds(dt);
        break;
    }
  }

  /// Pixel-per-second speed for a km/h value, clamped to a pleasant range.
  double _speedPx(double kmh, double jitter) {
    final raw = kmh * 2.4 * jitter;
    return raw.clamp(14.0, 150.0);
  }

  void _tickFlow(double dt) {
    // Blow-TO vector (Open-Meteo direction is where the wind comes FROM).
    final rad = (data.windDirection + 180) * math.pi / 180;
    final ux = math.cos(rad);
    final uy = math.sin(rad);
    final speedPx = _speedPx(data.windKmh, 1);
    final temp = data.temperatureC;

    for (final p in particles) {
      final v = speedPx * p.jitter;
      p.px = p.x;
      p.py = p.y;
      p.x += ux * v * dt;
      p.y += uy * v * dt;
      p.life += dt;
      p.trail.add(Offset(p.x, p.y));
      if (p.trail.length > 6) p.trail.removeAt(0);

      final out = p.x < -20 || p.x > size.width + 20 ||
          p.y < -20 || p.y > size.height + 20;
      if (out || p.life > p.maxLife) {
        // Respawn: prefer upwind edge so streaks flow across the screen.
        final fresh = _newFlow();
        if (ux.abs() > uy.abs()) {
          fresh.x = ux > 0 ? -10 : size.width + 10;
          fresh.y = _rng.nextDouble() * size.height;
        } else {
          fresh.y = uy > 0 ? -10 : size.height + 10;
          fresh.x = _rng.nextDouble() * size.width;
        }
        p
          ..x = fresh.x
          ..y = fresh.y
          ..life = 0
          ..trail.clear();
      }
      // Unused in flow layers but kept coherent for painters.
      p.vx = ux * v;
      p.vy = uy * v;
      if (layer == WindyLayer.temperature && temp != null) {
        // Local temperature pseudo-variation (±2.5°C) for a multi-hue field.
        p.tempSample = temp + (_rng.nextDouble() - 0.5) * 5;
      } else {
        p.tempSample = temp ?? 0;
      }
    }
  }

  void _tickRain(double dt) {
    final rad = (data.windDirection + 180) * math.pi / 180;
    final windSlant = math.cos(rad) * _speedPx(data.windKmh, 1) * 0.35;
    final prob = (data.precipProbability ?? 30).clamp(0, 100);

    for (final p in particles) {
      final fall = 320 + 220 * p.jitter + prob * 2.2;
      p.px = p.x;
      p.py = p.y;
      p.x += windSlant * dt;
      p.y += fall * dt;
      if (p.y > size.height + 24 || p.x < -80 || p.x > size.width + 80) {
        final fresh = _newRain();
        p
          ..x = fresh.x
          ..y = -12 - _rng.nextDouble() * 40;
      }
      p.vx = windSlant;
      p.vy = fall;
    }
  }

  void _tickClouds(double dt) {
    final rad = (data.windDirection + 180) * math.pi / 180;
    final base = _speedPx(data.windKmh, 1) * 0.55;
    final ux = math.cos(rad) * base;
    final uy = math.sin(rad) * base;

    for (final p in blobs) {
      p.x += ux * p.jitter * dt;
      p.y += uy * p.jitter * dt;
      final r = p.size;
      // Wrap around with margin.
      if (p.x < -r * 2) p.x = size.width + r;
      if (p.x > size.width + r * 2) p.x = -r;
      if (p.y < -r * 2) p.y = size.height + r;
      if (p.y > size.height + r * 2) p.y = -r;
    }
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _WindyPainter extends CustomPainter {
  _WindyPainter({required this.field, required Listenable repaint})
      : super(repaint: repaint);

  final _Field field;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    switch (field.layer) {
      case WindyLayer.wind:
      case WindyLayer.temperature:
        _paintFlow(canvas);
        break;
      case WindyLayer.precipitation:
        _paintRain(canvas);
        break;
      case WindyLayer.clouds:
        _paintClouds(canvas);
        break;
    }
  }

  /// Deep-sky base gradient — dark enough for the overlay chrome to read
  /// in both day and night.
  void _paintSky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    Color top;
    Color bottom;
    switch (field.layer) {
      case WindyLayer.temperature:
        final t = field.data.temperatureC ?? 15;
        final c = tempPaletteColor(t);
        top = Color.lerp(const Color(0xFF0A1230), c.withAlpha(90), 0.35)!;
        bottom = Color.lerp(const Color(0xFF030A1E), c.withAlpha(60), 0.5)!;
        break;
      case WindyLayer.precipitation:
        top = const Color(0xFF0B1526);
        bottom = const Color(0xFF02060F);
        break;
      case WindyLayer.clouds:
        top = const Color(0xFF101B33);
        bottom = const Color(0xFF050B18);
        break;
      case WindyLayer.wind:
        top = const Color(0xFF0C1B3A);
        bottom = const Color(0xFF040917);
        break;
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  /// Wind/temperature particle streaks.
  void _paintFlow(Canvas canvas) {
    final isTemp = field.layer == WindyLayer.temperature;
    for (final p in field.particles) {
      if (p.trail.isEmpty) continue;
      Color color;
      if (isTemp) {
        color = tempPaletteColor(p.tempSample);
      } else {
        // Faster streaks are brighter — reads as Windy's speed shading.
        final rel = ((field.data.windKmh * p.jitter) / 60).clamp(0.2, 1.0);
        color = Colors.white.withAlpha((p.alpha * rel * 255).round().clamp(20, 200));
      }
      final paint = Paint()
        ..color = color.withAlpha(isTemp ? (p.alpha * 230).round().clamp(40, 200) : (p.alpha * 255).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = isTemp ? 1.5 : p.size.clamp(0.9, 1.8)
        ..strokeCap = StrokeCap.round;
      if (p.trail.length == 1) {
        canvas.drawPoints(
          PointMode.points,
          [p.trail.first],
          paint..strokeWidth = paint.strokeWidth * 2,
        );
        continue;
      }
      final path = Path()..moveTo(p.trail.first.dx, p.trail.first.dy);
      for (var i = 1; i < p.trail.length; i++) {
        path.lineTo(p.trail[i].dx, p.trail[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// Rain streaks along the fall+wind velocity.
  void _paintRain(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;
    for (final p in field.particles) {
      final v = p.vy == 0 ? 400.0 : p.vy;
      final len = p.size;
      final ux = p.vx / (v.abs() + 1e-3);
      paint.color = Colors.lightBlueAccent
          .withAlpha((p.alpha * 255).round().clamp(30, 160));
      canvas.drawLine(
        Offset(p.x - ux * len, p.y - len),
        Offset(p.x, p.y),
        paint,
      );
    }
  }

  /// Soft cloud masses (radial-gradient blobs).
  void _paintClouds(Canvas canvas) {
    for (final p in field.blobs) {
      final rect = Rect.fromCircle(center: Offset(p.x, p.y), radius: p.size);
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.blueGrey.withAlpha((p.alpha * 255).round().clamp(8, 90)),
              Colors.blueGrey.withAlpha(0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_WindyPainter oldDelegate) => true;
}

// ── Temperature palette ──────────────────────────────────────────────────────

/// Maps a °C value onto the classic weather-map temperature ramp
/// (deep purple → blue → cyan → green → amber → orange → red).
Color tempPaletteColor(double celsius) {
  // Non-const: double map keys have no primitive equality, so this map
  // cannot be a compile-time constant.
  final stops = <double, Color>{
    -25: const Color(0xFF6A3DE8),
    -12: const Color(0xFF3D5AFE),
    -2: const Color(0xFF00BCD4),
    6: const Color(0xFF4CAF50),
    14: const Color(0xFFFFC107),
    22: const Color(0xFFFF9800),
    30: const Color(0xFFF4511E),
    40: const Color(0xFFD50000),
  };
  if (celsius <= stops.keys.first) return stops.values.first;
  double? prevT;
  Color? prevC;
  for (final entry in stops.entries) {
    if (celsius <= entry.key) {
      final t = (celsius - prevT!) / (entry.key - prevT);
      return Color.lerp(prevC, entry.value, t.clamp(0.0, 1.0))!;
    }
    prevT = entry.key;
    prevC = entry.value;
  }
  return stops.values.last;
}
