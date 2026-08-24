import 'package:flutter/material.dart';
import 'placed_control.dart';

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
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withAlpha(isEditMode ? 160 : 60);

    return Material(
      color: theme.colorScheme.surface.withAlpha(isEditMode ? 210 : 235),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        control.type.icon,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
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
                  ),
                ),
              ),
            ),
          ),
          if (isEditMode && isSelected && onDelete != null)
            Positioned(
              top: -2,
              right: -2,
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
        ],
      ),
    );
  }
}
