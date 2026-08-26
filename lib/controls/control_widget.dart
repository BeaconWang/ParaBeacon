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
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withAlpha(isEditMode ? 160 : 60);
    // Keep a subtle border while editing (for hit feedback) even if the user
    // disabled it, but hide it in view mode when requested.
    final effectiveBorderColor = (showBorder || isEditMode || isSelected)
        ? borderColor
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: theme.colorScheme.surface.withAlpha(isEditMode ? 210 : 235),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: effectiveBorderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _buildFace(context, theme),
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
  Widget _buildFace(BuildContext context, ThemeData theme) {
    final showTitle = control.boolSetting('showTitle', fallback: true);
    switch (control.type.id) {
      case 'vario':
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
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
          borderRadius: BorderRadius.circular(4),
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
