import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'control_catalog.dart';

/// Control ids that are only offered in the "Add Control" picker while running
/// a debug build. In release/profile builds these are hidden from the chooser.
const Set<String> _debugOnlyControlIds = {'debug_sensor'};

/// A modal bottom sheet that lets the user pick a control to add to the
/// dashboard, grouped by category (like XCTrack's "Add widget" chooser).
///
/// Returns the selected [ControlType] via [Navigator.pop], or null if
/// dismissed.
Future<ControlType?> showAddControlSheet(BuildContext context) {
  return showModalBottomSheet<ControlType>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Background driven by the theme's bottomSheetTheme (see other sheets).
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _AddControlSheet(),
  );
}

class _AddControlSheet extends StatefulWidget {
  const _AddControlSheet();

  @override
  State<_AddControlSheet> createState() => _AddControlSheetState();
}

class _AddControlSheetState extends State<_AddControlSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();

    // Filter directories/controls by the search query. Debug-only controls
    // (e.g. the Debug Sensor) are hidden entirely outside debug builds.
    final directories = ControlCatalog.directories
        .map((directory) {
          final available = directory.controls
              .where((c) => kDebugMode || !_debugOnlyControlIds.contains(c.id));
          final matches = query.isEmpty
              ? available.toList()
              : available
                  .where((c) => c.label.toLowerCase().contains(query))
                  .toList();
          return (directory, matches);
        })
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text('Add Control', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search controls',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: directories.every((entry) => entry.$2.isEmpty)
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? 'No controls available yet'
                            : 'No controls match "$_query"',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      itemCount: directories.length,
                      itemBuilder: (context, index) {
                        final (directory, controls) = directories[index];
                        return _DirectorySection(
                          directory: directory,
                          controls: controls,
                          onSelected: (control) =>
                              Navigator.of(context).pop(control),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DirectorySection extends StatelessWidget {
  final ControlDirectory directory;
  final List<ControlType> controls;
  final ValueChanged<ControlType> onSelected;

  const _DirectorySection({
    required this.directory,
    required this.controls,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              Icon(directory.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                directory.title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (controls.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'No controls in this directory yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisExtent: 84,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: controls.length,
            itemBuilder: (context, index) {
              final control = controls[index];
              return _ControlTile(
                control: control,
                onTap: () => onSelected(control),
              );
            },
          ),
      ],
    );
  }
}

class _ControlTile extends StatelessWidget {
  final ControlType control;
  final VoidCallback onTap;

  const _ControlTile({required this.control, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(control.icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  control.label,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
