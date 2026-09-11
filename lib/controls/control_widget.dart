import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'placed_control.dart';
import 'data_value_control.dart';
import 'compass_wind_control.dart';
import 'status_line_control.dart';
import 'data_monitor_control.dart';
import 'debug_sensor_control.dart';
import 'flight_button_control.dart';
import 'map_control.dart';
import 'vario_control.dart';

/// Visual representation of a [PlacedControl] on the dashboard.
///
/// In edit mode it renders as a selectable/movable card (the edit-mode
/// overlays — delete button, resize handle — are added by the host at the
/// dashboard level so their hit area can extend beyond the control bounds).
/// In view mode it renders as a plain control face.
///
/// [isControlled] marks a widget that the user has long-pressed to unlock in
/// view mode: it is currently allowed to receive its own pointer events
/// (map pan/zoom, buttons, etc.). Every other widget is locked / static.
class ControlWidget extends StatelessWidget {
  final PlacedControl control;
  final bool isEditMode;
  final bool isSelected;
  final bool isControlled;
  final VoidCallback? onTap;

  /// Stable key for the inner Map control, supplied by the dashboard host so
  /// the map's State (zoom/pan) survives select/deselect reparenting. Only
  /// used by the `map` control type.
  final Key? mapKey;

  const ControlWidget({
    super.key,
    required this.control,
    required this.isEditMode,
    required this.isSelected,
    this.isControlled = false,
    this.onTap,
    this.mapKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBorder = control.boolSetting('showBorder', fallback: true);

    // User-picked border color, stored as ARGB int; 0 == "automatic" (fall
    // back to the theme outline the app has always used). Light themes need a
    // stronger outline than dark ones for the widget edges to read clearly
    // against a light background, so pick the alpha per brightness.
    final customBorderArgb = control.intSetting('borderColor', fallback: 0);
    final isLight = theme.brightness == Brightness.light;
    final autoBorderAlpha = isEditMode
        ? 160
        : (isLight ? 130 : 60);
    final autoBorderColor =
        theme.colorScheme.outlineVariant.withAlpha(autoBorderAlpha);
    final baseBorderColor = customBorderArgb == 0
        ? autoBorderColor
        : Color(customBorderArgb);

    // Selection highlight always wins over the user's color so it stays
    // obvious which control is being edited. The "controlled" highlight
    // (long-pressed to unlock in view mode) uses the same primary tint so
    // the user can immediately see which widget is currently interactive.
    final highlight = isSelected || isControlled;
    final borderColor =
        highlight ? theme.colorScheme.primary : baseBorderColor;

    // Keep a subtle border while editing (for hit feedback) even if the user
    // disabled it, but hide it in view mode when requested.
    final effectiveBorderColor = (showBorder || isEditMode || highlight)
        ? borderColor
        : Colors.transparent;

    // User-picked width, clamped to a safe range. Highlight state bumps it
    // slightly so it's visible regardless of the base width.
    final userWidth =
        control.doubleSetting('borderWidth', fallback: 1.0).clamp(0.5, 6.0);
    final effectiveBorderWidth =
        highlight ? (userWidth + 1.0) : userWidth.toDouble();

    // User-picked outer corner radius. The face-level clip radius shrinks
    // with it (min 0) so nested content like the map/vario preview keeps
    // sitting just inside the border like before.
    final outerRadiusValue =
        control.doubleSetting('borderRadius', fallback: 8.0).clamp(0.0, 64.0);
    final outerRadius = BorderRadius.circular(outerRadiusValue.toDouble());
    final innerRadius = BorderRadius.circular(
      (outerRadiusValue - 4).clamp(0.0, 64.0).toDouble(),
    );

    // User-picked background opacity (stored as percent 0..100). In edit
    // mode we floor the effective alpha so a nearly-transparent widget can
    // still be picked up, moved, and deleted; the user's real value is used
    // verbatim in view mode.
    final userOpacity =
        (control.doubleSetting('backgroundOpacity', fallback: 92.0) / 100.0)
            .clamp(0.0, 1.0);
    const editModeMinOpacity = 0.35;
    final effectiveOpacity =
        isEditMode ? userOpacity.clamp(editModeMinOpacity, 1.0) : userOpacity;
    // User-picked background color, stored as ARGB int; 0 == "automatic"
    // (fall back to the theme surface the app has always used). We strip
    // the alpha channel from the user's swatch and let `backgroundOpacity`
    // drive transparency uniformly, so both settings stay meaningful and
    // don't fight each other.
    final customBgArgb = control.intSetting('backgroundColor', fallback: 0);
    final baseBgColor = customBgArgb == 0
        ? theme.colorScheme.surface
        : Color(customBgArgb);
    final surfaceColor =
        baseBgColor.withAlpha((effectiveOpacity * 255).round().clamp(0, 255));

    // User-picked whole-control opacity (percent 0..100). This fades the
    // entire control (background + border + face contents) together via a
    // single Opacity layer. The delete button stays outside this wrapper so
    // a user who fully hid a widget can still recover it in edit mode.
    final userControlOpacity =
        (control.doubleSetting('controlOpacity', fallback: 100.0) / 100.0)
            .clamp(0.0, 1.0);
    final effectiveControlOpacity = isEditMode
        ? userControlOpacity.clamp(editModeMinOpacity, 1.0)
        : userControlOpacity;

    // User-picked text color, stored as ARGB int; 0 == "automatic" (fall
    // back to the theme's on-surface color). We route this through a nested
    // Theme override so every data control that reads
    // `theme.colorScheme.onSurface` / `onSurfaceVariant` picks it up
    // automatically without needing a per-widget parameter. Semantic colors
    // (climb green, sink red) live in the widgets themselves and stay
    // untouched so state coloring keeps its meaning.
    final customTextArgb = control.intSetting('textColor', fallback: 0);
    final faceThemeData = customTextArgb == 0
        ? theme
        : _applyTextColor(theme, Color(customTextArgb));

    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: effectiveControlOpacity.toDouble(),
        child: Material(
          color: surfaceColor,
          borderRadius: outerRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: outerRadius,
                border: Border.all(
                  color: effectiveBorderColor,
                  width: effectiveBorderWidth,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Theme(
                  data: faceThemeData,
                  child: Builder(
                    builder: (context) =>
                        _buildFace(context, faceThemeData, innerRadius),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the actual control face. Specific control types get a custom
  /// renderer; everything else falls back to a generic icon + label face.
  Widget _buildFace(
      BuildContext context, ThemeData theme, BorderRadius innerRadius) {
    final showTitle = control.boolSetting('showTitle', fallback: true);
    switch (control.type.id) {
      case 'vario':
        return ClipRRect(
          borderRadius: innerRadius,
          child: VarioControl(
            maxScale: control.doubleSetting('maxScale', fallback: 8.0),
          ),
        );
      case 'vertical_speed':
        return VerticalSpeedControl(showTitle: showTitle);
      case 'location':
        final fmt = control.setting('format');
        return LocationControl(
          showTitle: showTitle,
          format:
              fmt == 'dms' ? LocationFormat.dms : LocationFormat.decimal,
        );
      case 'altitude':
        final src = control.setting('source');
        AltitudeSource source;
        switch (src) {
          case 'gps':
            source = AltitudeSource.gps;
            break;
          case 'baro':
            source = AltitudeSource.baro;
            break;
          case 'auto':
          default:
            source = AltitudeSource.auto;
        }
        return AltitudeControl(showTitle: showTitle, source: source);
      case 'max_altitude':
        return MaxAltitudeControl(showTitle: showTitle);
      case 'ground_speed':
        return GroundSpeedControl(showTitle: showTitle);
      case 'glide_ratio':
        return GlideRatioControl(showTitle: showTitle);
      case 'heading':
        return HeadingControl(
          showTitle: showTitle,
          cardinal: control.setting('format') == 'cardinal',
        );
      case 'wind_speed':
        return WindSpeedControl(showTitle: showTitle);
      case 'wind_direction':
        return WindDirectionControl(
          showTitle: showTitle,
          cardinal: control.setting('format') == 'cardinal',
        );
      case 'pressure':
        return PressureControl(showTitle: showTitle);
      case 'temperature':
        return TemperatureControl(showTitle: showTitle);
      case 'clock':
        return ClockControl(
          showTitle: showTitle,
          showSeconds: control.boolSetting('showSeconds', fallback: false),
          use24Hour: control.setting('timeFormat') != '12h',
        );
      case 'flight_time':
        return FlightTimeControl(showTitle: showTitle);
      case 'air_time':
        return AirTimeControl(showTitle: showTitle);
      case 'distance_to_takeoff':
        return DistanceToTakeoffControl(showTitle: showTitle);
      case 'sensor_battery':
        return SensorBatteryControl(showTitle: showTitle);
      case 'heart_rate':
        return HeartRateControl(showTitle: showTitle);
      case 'debug_sensor':
        return const DebugSensorControl();
      case 'data_monitor':
        return const DataMonitorControl();
      case 'flight_button':
        return FlightButtonControl(
          showAutoDetect:
              control.boolSetting('showAutoDetect', fallback: true),
        );
      case 'status_line':
        return StatusLineControl(
          showGps: control.boolSetting('showGps', fallback: true),
          showBluetooth: control.boolSetting('showBluetooth', fallback: true),
          showSensorBattery:
              control.boolSetting('showSensorBattery', fallback: true),
          showDeviceBattery:
              control.boolSetting('showDeviceBattery', fallback: true),
          showFlightTimer:
              control.boolSetting('showFlightTimer', fallback: true),
          showClock: control.boolSetting('showClock', fallback: true),
          gpsDetailed: control.boolSetting('gpsDetailed', fallback: false),
          use24Hour: control.setting('timeFormat') != '12h',
        );
      case 'compass_wind':
        return ClipRRect(
          borderRadius: innerRadius,
          child: const CompassWindControl(),
        );
      case 'map':
        final source = control.setting('tileSource');
        final rot = control.setting('rotation');
        final windAlg = control.setting('windAlgorithm');
        return ClipRRect(
          borderRadius: innerRadius,
          child: MapControl(
            key: mapKey,
            // The map is "active" (shows its operation buttons and receives
            // gestures) when it's the selected widget in edit mode or the
            // long-press-unlocked widget in view mode.
            active: isSelected || isControlled,
            follow: control.boolSetting('follow', fallback: true),
            initialZoom: control.doubleSetting('zoom', fallback: 17.0),
            tileSource: source is String ? source : 'osm',
            trackUp: rot == 'track',
            showNorth: control.boolSetting('showNorth', fallback: false),
            pilotArrowCoef:
                control.doubleSetting('pilotArrowCoef', fallback: 100.0) /
                    100.0,
            lineThickness:
                control.doubleSetting('lineThickness', fallback: 1.0),
            tracklogMinutes:
                control.doubleSetting('tracklogMinutes', fallback: 0.0),
            latestThermals:
                control.doubleSetting('latestThermals', fallback: 8.0).round(),
            windAlgorithm: windAlg is String ? windAlg : 'classic',
            showWind: control.boolSetting('showWind', fallback: true),
            showSun: control.boolSetting('showSun', fallback: false),
            showBearing: control.boolSetting('showBearing', fallback: false),
            showScale: control.boolSetting('showScale', fallback: true),
            useOffline: control.boolSetting('useOffline', fallback: true),
            showTrack: control.boolSetting('showTrack', fallback: true),
            showThermal: control.boolSetting('showThermal', fallback: true),
            showAirspace: control.boolSetting('showAirspace', fallback: true),
            showLegend: control.boolSetting('showLegend', fallback: false),
            showZoomLevel:
                control.boolSetting('showZoomLevel', fallback: true),
            showAttribution:
                control.boolSetting('showAttribution', fallback: true),
            showStatus: control.boolSetting('showStatus', fallback: true),
          ),
        );
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              control.type.icon,
              size: 22,
              color: theme.colorScheme.primary,
            ),
            if (showTitle) ...[
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  control.type.labelOf(AppLocalizations.of(context)),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ],
        );
    }
  }

  /// Returns a copy of [base] whose color scheme uses [textColor] as the
  /// on-surface color, with a slightly-muted variant for secondary labels.
  ///
  /// The Material color scheme also carries `onSurface` as its default text
  /// style color, so we simultaneously rebuild `textTheme` / `primaryTextTheme`
  /// with `apply(bodyColor:, displayColor:)` — otherwise `Text` widgets that
  /// rely on the theme's default text style would keep the old tint.
  ThemeData _applyTextColor(ThemeData base, Color textColor) {
    // Muted variant for secondary labels (title, unit). Blend towards the
    // background so both fully-white and fully-black user picks stay legible.
    final muted = Color.alphaBlend(textColor.withAlpha(0xB3), Colors.transparent);
    final scheme = base.colorScheme.copyWith(
      onSurface: textColor,
      onSurfaceVariant: muted,
    );
    return base.copyWith(
      colorScheme: scheme,
      textTheme: base.textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      iconTheme: base.iconTheme.copyWith(color: textColor),
    );
  }
}
