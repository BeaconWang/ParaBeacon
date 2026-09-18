import 'package:flutter/material.dart';

import '../data/navigation_store.dart';

Future<void> showNavigationTaskSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _NavigationTaskSheet(),
  );
}

class _NavigationTaskSheet extends StatefulWidget {
  const _NavigationTaskSheet();

  @override
  State<_NavigationTaskSheet> createState() => _NavigationTaskSheetState();
}

class _NavigationTaskSheetState extends State<_NavigationTaskSheet> {
  final _taskName = TextEditingController();
  final _pointName = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _radius = TextEditingController(text: '100');
  final _points = <Waypoint>[];

  @override
  void initState() {
    super.initState();
    final task = NavigationStore.instance.task;
    if (task != null) {
      _taskName.text = task.name;
      _points.addAll(task.waypoints);
    }
  }

  @override
  void dispose() {
    _taskName.dispose();
    _pointName.dispose();
    _lat.dispose();
    _lon.dispose();
    _radius.dispose();
    super.dispose();
  }

  void _addPoint() {
    final name = _pointName.text.trim();
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    final radius = double.tryParse(_radius.text.trim()) ?? 100;
    if (name.isEmpty ||
        lat == null ||
        lon == null ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180 ||
        radius < 1 ||
        radius > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid name, coordinate and radius.'),
        ),
      );
      return;
    }
    setState(() {
      _points.add(
        Waypoint(name: name, latitude: lat, longitude: lon, radiusM: radius),
      );
      _pointName.clear();
      _lat.clear();
      _lon.clear();
    });
  }

  Future<void> _save() async {
    final name = _taskName.text.trim();
    if (name.isEmpty || _points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A task name and at least one waypoint are required.'),
        ),
      );
      return;
    }
    await NavigationStore.instance.setTask(
      NavigationTask(name: name, waypoints: List.unmodifiable(_points)),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Navigation task', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _taskName,
              decoration: const InputDecoration(
                labelText: 'Task name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('Waypoints', style: theme.textTheme.titleMedium),
            if (_points.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No waypoints yet.'),
              )
            else
              ..._points.asMap().entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(entry.value.name),
                  subtitle: Text(
                    '${entry.value.latitude.toStringAsFixed(5)}, '
                    '${entry.value.longitude.toStringAsFixed(5)} · '
                    '${entry.value.radiusM.round()} m',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        setState(() => _points.removeAt(entry.key)),
                  ),
                ),
              ),
            const Divider(),
            TextField(
              controller: _pointName,
              decoration: const InputDecoration(labelText: 'Waypoint name'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lon,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _radius,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Arrival radius (m)',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addPoint,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add waypoint'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (NavigationStore.instance.task != null)
                  TextButton(
                    onPressed: () async {
                      await NavigationStore.instance.setTask(null);
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Clear task'),
                  ),
                const Spacer(),
                FilledButton(onPressed: _save, child: const Text('Save task')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
