import 'package:flutter/material.dart';

import 'control_catalog.dart';
import 'placed_control.dart';

/// Actions available from a control's long-press context menu.
enum ControlAction {
  settings,
  duplicate,
  bringToFront,
  sendToBack,
  delete,
}

/// Shows a bottom menu for a single control (triggered by long-press) and
/// returns the chosen [ControlAction], or null if dismissed.
Future<ControlAction?> showControlContextMenu(
  BuildContext context, {
  required PlacedControl control,
}) {
  return showModalBottomSheet<ControlAction>(
    context: context,
    showDragHandle: true,
    // See other sheets: omitted so the theme's bottomSheetTheme drives it
    // live and runtime theme switches don't leave a stale caller color.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(control.type.icon, color: theme.colorScheme.primary),
              title: Text(
                control.type.label,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(control.type.kind.title),
            ),
            const Divider(height: 1),
            _item(
              context,
              icon: Icons.tune,
              label: 'Settings',
              action: ControlAction.settings,
            ),
            _item(
              context,
              icon: Icons.copy_all_outlined,
              label: 'Duplicate',
              action: ControlAction.duplicate,
            ),
            _item(
              context,
              icon: Icons.flip_to_front,
              label: 'Bring to front',
              action: ControlAction.bringToFront,
            ),
            _item(
              context,
              icon: Icons.flip_to_back,
              label: 'Send to back',
              action: ControlAction.sendToBack,
            ),
            const Divider(height: 1),
            _item(
              context,
              icon: Icons.delete_outline,
              label: 'Delete',
              action: ControlAction.delete,
              destructive: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Widget _item(
  BuildContext context, {
  required IconData icon,
  required String label,
  required ControlAction action,
  bool destructive = false,
}) {
  final theme = Theme.of(context);
  final color = destructive ? theme.colorScheme.error : null;
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color)),
    onTap: () => Navigator.of(context).pop(action),
  );
}
