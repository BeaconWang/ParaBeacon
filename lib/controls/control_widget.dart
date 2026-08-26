import 'package:flutter/material.dart';
import 'placed_control.dart';
import 'data_value_control.dart';
import 'data_monitor_control.dart';
import 'debug_sensor_control.dart';
import 'flight_button_control.dart';
import 'map_control.dart';
import 'vario_control.dart';

/// Visual representation of a [PlacedControl] on the dashboard.
///
/// In edit mode it shows a selectable/movable card with a delete affordance;
/// in view mode it renders as a plain control face.
class ControlWidget extends StatelessWidget {
  final PlacedControl control;
  final bool isEditMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ControlWidget({
    super.key,
    required this.control,
    required this.isEditMode,
    required this.isSelected,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBorder = control.boolSetting('showBorder', fallback: true);

    // User-picked border color, stored as ARGB int; 0 == "automatic" (fall
    // back to the theme outline the app has always used).
    final customBorderArgb = control.intSetting('borderColor', fallback: 0);
    final autoBorderColor =
        theme.colorScheme.outlineVariant.withAlpha(isEditMode ? 160 : 60);
    final baseBorderColor = customBorderArgb == 0
        ? autoBorderColor
        : Color(customBorderArgb);

    // Selection highlight always wins over the user's color so it stays
    // obvious which control is being edited.
    final borderColor =
        isSelected ? theme.colorScheme.primary : baseBorderColor;

    // Keep a subtle border while editing (for hit feedback) even if the user
    // disabled it, but hide it in view mode when requested.
    final effectiveBorderColor = (showBorder || isEditMode || isSelected)
        ? borderColor
        : Colors.transparent;

    // User-picked width, clamped to a safe range. Selection state bumps it
    // slightly so the highlight is visible regardless of the base width.
    final userWidth =
        control.doubleSetting('borderWidth', fallback: 1.0).clamp(0.5, 6.0);
    final effectiveBorderWidth =
        isSelected ? (userWidth + 1.0) : userWidth.toDouble();

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
    final surfaceColor = theme.colorScheme.surface
        .withAlpha((effectiveOpacity * 255).round().clamp(0, 255));

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
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
                    child: _buildFace(context, theme, innerRadius),
                  ),
                ),
              ),
            ),
          ),
          if (isEditMode && isSelected && onDelete != null)
            Positioned(
              top: 0,
              right: 0,
              // Shift the button so its center sits on the top-right corner.
              child: FractionalTranslation(
                translation: const Offset(0.5, -0.5),
                child: IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: onDelete,
                ),
              ),
            ),
        ],
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
      case 'debug_sensor':
        return const DebugSensorControl();
      case 'data_monitor':
        return const DataMonitorControl();
      case 'flight_button':
        return FlightButtonControl(
          showAutoDetect:
              control.boolSetting('showAutoDetect', fallback: true),
        );
      case 'map':
        final source = control.setting('tileSource');
        return ClipRRect(
          borderRadius: innerRadius,
          child: MapControl(
            follow: control.boolSetting('follow', fallback: true),
            initialZoom: control.doubleSetting('zoom', fallback: 13.0),
            tileSource: source is String ? source : 'osm',
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
                  control.type.label,
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
}
