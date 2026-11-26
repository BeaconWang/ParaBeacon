import 'dart:async';

import 'package:flutter/material.dart';

import '../data/color_palette_settings.dart';
import '../data/competition/competition_task_server_service.dart';
import '../data/parabeacon_account_service.dart';
import '../data/vario_color_settings.dart';
import '../l10n/app_localizations.dart';
import 'decimal_places.dart';
import 'control_settings.dart';
import 'placed_control.dart';

/// Shows a modal bottom sheet to edit a single control's settings.
///
/// Mutates [control.settings] live as the user changes values and calls
/// [onChanged] so the host can rebuild. Returns when dismissed.
Future<void> showControlSettingsSheet(
  BuildContext context, {
  required PlacedControl control,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Let the sheet's own Material resolve its color from
    // `Theme.of(context).bottomSheetTheme.modalBackgroundColor` lazily, so
    // theme switches propagate live. Capturing `Theme.of(context)…` here
    // would bake the caller's palette into the route.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) =>
        _ControlSettingsSheet(control: control, onChanged: onChanged),
  );
}

class _ControlSettingsSheet extends StatefulWidget {
  final PlacedControl control;
  final VoidCallback onChanged;

  const _ControlSettingsSheet({required this.control, required this.onChanged});

  @override
  State<_ControlSettingsSheet> createState() => _ControlSettingsSheetState();
}

class _ControlSettingsSheetState extends State<_ControlSettingsSheet> {
  late final List<ControlSetting> _schema = settingsSchemaFor(
    widget.control.type.id,
  );
  Future<List<CompetitionTaskServerEntry>>? _mapServerTasks;

  @override
  void initState() {
    super.initState();
    final control = widget.control;
    if (control.type.id == 'map') {
      _mapServerTasks = _loadMapServerTasks();
    }
    if (control.type.id != 'map' ||
        !control.settings.containsKey('showLandingPoints')) {
      return;
    }
    final legacyVisibility = control.boolSetting(
      'showLandingPoints',
      fallback: true,
    );
    control.settings.putIfAbsent(
      'showDefaultLandingPoint',
      () => legacyVisibility,
    );
    control.settings.putIfAbsent(
      'showNearestLandingPoint',
      () => legacyVisibility,
    );
  }

  Future<List<CompetitionTaskServerEntry>> _loadMapServerTasks() async {
    final account = ParaBeaconAccountService.instance;
    await account.load();
    if (!account.isSignedIn) throw StateError('ParaBeacon sign-in required');
    return CompetitionTaskServerService.instance.listTasks();
  }

  void _reloadMapServerTasks() {
    setState(() => _mapServerTasks = _loadMapServerTasks());
  }

  void _set(String key, dynamic value) {
    setState(() => widget.control.settings[key] = value);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final control = widget.control;
    final visibleSchema = _schema.where((setting) {
      final visibleWhenKey = setting.visibleWhenKey;
      if (visibleWhenKey == null) return true;
      final toggle = _schema.firstWhere(
        (candidate) => candidate.key == visibleWhenKey,
      );
      return control.boolSetting(
        visibleWhenKey,
        fallback: toggle.defaultValue as bool,
      );
    }).toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(control.type.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.controlSettingsTitle(control.type.labelOf(l10n)),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (control.type.id == 'vario')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.settingVarioColorsGlobalNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_schema.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.controlNoSettings,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount:
                      visibleSchema.length + (control.type.id == 'map' ? 2 : 0),
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index < visibleSchema.length) {
                      return _buildSettingTile(
                        context,
                        l10n,
                        visibleSchema[index],
                      );
                    }
                    final isFilter = index == visibleSchema.length + 1;
                    final key = isFilter
                        ? 'otherPilotTaskFilter'
                        : 'competitionTaskSource';
                    final fallback = isFilter ? 'all' : 'local';
                    return _MapServerTaskSettingTile(
                      title: isFilter
                          ? l10n.competitionMapTaskFilter
                          : l10n.competitionMapTaskSource,
                      selectedId: control.setting(key) is String
                          ? control.setting(key) as String
                          : fallback,
                      isFilter: isFilter,
                      tasks: _mapServerTasks!,
                      onRetry: _reloadMapServerTasks,
                      onSelected: (value) => _set(key, value),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    AppLocalizations l10n,
    ControlSetting setting,
  ) {
    final control = widget.control;

    // Border color/width only take effect when `showBorder` is on. Grey out
    // those rows in that case so the user understands why toggling them has
    // no visible effect, but still let them edit the value ahead of time.
    final borderOff = !control.boolSetting('showBorder', fallback: true);
    final isBorderChild =
        setting.key == 'borderColor' || setting.key == 'borderWidth';
    final dimmed = isBorderChild && borderOff;
    final tile = _buildSettingTileBody(context, l10n, setting);
    if (!dimmed) return tile;
    return Opacity(opacity: 0.5, child: tile);
  }

  Widget _buildSettingTileBody(
    BuildContext context,
    AppLocalizations l10n,
    ControlSetting setting,
  ) {
    final theme = Theme.of(context);
    final control = widget.control;
    final label = setting.labelOf(l10n);

    switch (setting.kind) {
      case SettingKind.toggle:
        final value = control.boolSetting(
          setting.key,
          fallback: setting.defaultValue as bool,
        );
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: setting.key == 'showPublicPilots'
              ? Text(l10n.settingShowPublicPilotsSubtitle)
              : null,
          value: value,
          onChanged: (v) => _set(setting.key, v),
        );

      case SettingKind.slider:
        final value = control.doubleSetting(
          setting.key,
          fallback: setting.defaultValue as double,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(
                    '${value.toStringAsFixed(setting.divisions != null && (setting.max - setting.min) <= setting.divisions! ? 0 : 1)}'
                    '${setting.unit.isNotEmpty ? ' ${setting.unit}' : ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: value.clamp(setting.min, setting.max),
                min: setting.min,
                max: setting.max,
                divisions: setting.divisions,
                label: value.toStringAsFixed(1),
                onChanged: (v) => _set(setting.key, v),
              ),
            ],
          ),
        );

      case SettingKind.choice:
        final value = control.setting(setting.key) ?? setting.defaultValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: setting.options.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(setting.optionLabelOf(l10n, entry.key)),
                    selected: value == entry.key,
                    onSelected: (_) => _set(setting.key, entry.key),
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case SettingKind.decimalRange:
        final range = DecimalPlaceRange.parse(control.setting(setting.key));
        final maxPlaces = setting.maxDecimalPlaces
            .clamp(1, DecimalPlaceRange.maxSupportedPlaces)
            .toInt();
        final selectedRange = range ?? DecimalPlaceRange(0, maxPlaces);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(
                    range == null
                        ? l10n.settingDecimalPlacesDefault
                        : '${selectedRange.min}–${selectedRange.max}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              RangeSlider(
                values: RangeValues(
                  selectedRange.min.toDouble(),
                  selectedRange.max.toDouble(),
                ),
                min: 0,
                max: maxPlaces.toDouble(),
                divisions: maxPlaces,
                labels: RangeLabels(
                  selectedRange.min.toString(),
                  selectedRange.max.toString(),
                ),
                onChanged: (values) => _set(
                  setting.key,
                  DecimalPlaceRange(
                    values.start.round(),
                    values.end.round(),
                  ).encode(),
                ),
              ),
              ChoiceChip(
                label: Text(l10n.settingDecimalPlacesDefault),
                selected: range == null,
                onSelected: (_) => _set(setting.key, 'default'),
              ),
            ],
          ),
        );

      case SettingKind.color:
        final value = control.intSetting(
          setting.key,
          fallback: setting.defaultValue as int,
        );
        return _ColorSettingEditor(
          key: ValueKey(setting.key),
          label: label,
          value: value,
          onColorSelected: (argb) => _set(setting.key, argb),
        );

      case SettingKind.globalColor:
        final index = VarioColorSettings.indexForKey(setting.key);
        if (index == null) return const SizedBox.shrink();
        return _GlobalVarioColorSettingEditor(
          key: ValueKey(setting.key),
          label: label,
          colorIndex: index,
        );
    }
  }
}

class _MapServerTaskSettingTile extends StatefulWidget {
  const _MapServerTaskSettingTile({
    required this.title,
    required this.selectedId,
    required this.isFilter,
    required this.tasks,
    required this.onRetry,
    required this.onSelected,
  });

  final String title;
  final String selectedId;
  final bool isFilter;
  final Future<List<CompetitionTaskServerEntry>> tasks;
  final VoidCallback onRetry;
  final ValueChanged<String> onSelected;

  @override
  State<_MapServerTaskSettingTile> createState() =>
      _MapServerTaskSettingTileState();
}

class _MapServerTaskSettingTileState extends State<_MapServerTaskSettingTile> {
  late Future<List<CompetitionTaskServerEntry>> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = widget.tasks;
  }

  Future<void> _choose() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _MapTaskChoiceSheet(
        title: widget.title,
        isFilter: widget.isFilter,
        selectedId: widget.selectedId,
        tasks: _tasks,
      ),
    );
    if (selected != null) widget.onSelected(selected);
  }

  String _selectedLabel(
    AppLocalizations l10n,
    List<CompetitionTaskServerEntry>? tasks,
  ) {
    if (widget.isFilter && widget.selectedId == 'all') {
      return l10n.competitionMapAllPilots;
    }
    if (!widget.isFilter && widget.selectedId == 'local') {
      return l10n.competitionMapLocalTask;
    }
    for (final entry in tasks ?? const <CompetitionTaskServerEntry>[]) {
      if (entry.ownerId != widget.selectedId) continue;
      final name = entry.task.name.trim().isEmpty
          ? l10n.competitionUnnamedTask
          : entry.task.name;
      final owner = entry.displayName.trim().isEmpty
          ? '@${entry.username}'
          : '${entry.displayName} · @${entry.username}';
      return '$name · $owner';
    }
    return l10n.competitionMapTaskLoadFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<CompetitionTaskServerEntry>>(
      future: _tasks,
      builder: (context, snapshot) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(widget.title),
        subtitle: Text(
          _selectedLabel(l10n, snapshot.data),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: snapshot.connectionState == ConnectionState.waiting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: snapshot.hasError ? l10n.refresh : l10n.edit,
                onPressed: snapshot.hasError ? widget.onRetry : _choose,
                icon: Icon(
                  snapshot.hasError
                      ? Icons.refresh
                      : Icons.arrow_drop_down_circle_outlined,
                ),
              ),
        onTap: snapshot.connectionState == ConnectionState.waiting
            ? null
            : _choose,
      ),
    );
  }
}

class _MapTaskChoiceSheet extends StatelessWidget {
  const _MapTaskChoiceSheet({
    required this.title,
    required this.isFilter,
    required this.selectedId,
    required this.tasks,
  });

  final String title;
  final bool isFilter;
  final String selectedId;
  final Future<List<CompetitionTaskServerEntry>> tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<CompetitionTaskServerEntry>>(
                future: tasks,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.competitionMapSignInToLoad,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final entries = snapshot.data ?? const [];
                  return ListView(
                    children: [
                      if (isFilter)
                        ListTile(
                          leading: const Icon(Icons.groups_outlined),
                          title: Text(l10n.competitionMapAllPilots),
                          trailing: selectedId == 'all'
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(context).pop('all'),
                        )
                      else
                        ListTile(
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(l10n.competitionMapLocalTask),
                          trailing: selectedId == 'local'
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(context).pop('local'),
                        ),
                      for (final entry in entries)
                        ListTile(
                          leading: const Icon(Icons.cloud_outlined),
                          title: Text(
                            entry.task.name.trim().isEmpty
                                ? l10n.competitionUnnamedTask
                                : entry.task.name,
                          ),
                          subtitle: Text(
                            entry.displayName.trim().isEmpty
                                ? '@${entry.username}'
                                : '${entry.displayName} · @${entry.username}',
                          ),
                          trailing: selectedId == entry.ownerId
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(context).pop(entry.ownerId),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlobalVarioColorSettingEditor extends StatefulWidget {
  const _GlobalVarioColorSettingEditor({
    super.key,
    required this.label,
    required this.colorIndex,
  });

  final String label;
  final int colorIndex;

  @override
  State<_GlobalVarioColorSettingEditor> createState() =>
      _GlobalVarioColorSettingEditorState();
}

class _GlobalVarioColorSettingEditorState
    extends State<_GlobalVarioColorSettingEditor> {
  @override
  void initState() {
    super.initState();
    VarioColorSettings.instance.addListener(_onSettingsChanged);
    ColorPaletteSettings.instance.addListener(_onSettingsChanged);
    unawaited(VarioColorSettings.instance.load());
    unawaited(ColorPaletteSettings.instance.load());
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    VarioColorSettings.instance.removeListener(_onSettingsChanged);
    ColorPaletteSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = VarioColorSettings.instance;
    final currentColor = settings.colorAt(widget.colorIndex);
    final colors = <int>{
      currentColor,
      VarioColorSettings.defaultColors[widget.colorIndex],
      ...ColorPaletteSettings.instance.visiblePresetColors,
    }.toList(growable: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((argb) {
              return _ColorSwatch(
                argb: argb,
                selected: argb == currentColor,
                onTap: () =>
                    unawaited(settings.setColor(widget.colorIndex, argb)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ColorSettingEditor extends StatefulWidget {
  const _ColorSettingEditor({
    super.key,
    required this.label,
    required this.value,
    required this.onColorSelected,
  });

  final String label;
  final int value;
  final ValueChanged<int> onColorSelected;

  @override
  State<_ColorSettingEditor> createState() => _ColorSettingEditorState();
}

class _ColorSettingEditorState extends State<_ColorSettingEditor> {
  @override
  void initState() {
    super.initState();
    ColorPaletteSettings.instance.addListener(_onPaletteSettingsChanged);
    ColorPaletteSettings.instance.load();
  }

  void _onPaletteSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ColorPaletteSettings.instance.removeListener(_onPaletteSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ColorPaletteSettings.instance.pickerColors
                .map(
                  (argb) => _ColorSwatch(
                    argb: argb,
                    selected: argb == widget.value,
                    onTap: () => widget.onColorSelected(argb),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Small square swatch used by the color picker. Renders a diagonal "auto"
/// glyph for the special sentinel value `0` so the user can revert to the
/// theme default.
class _ColorSwatch extends StatelessWidget {
  final int argb;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.argb,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAuto = argb == 0;
    final color = isAuto
        ? theme.colorScheme.surfaceContainerHighest
        : Color(argb);
    final ringColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: isAuto ? 'Automatic color' : 'Color 0x${argb.toRadixString(16)}',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: selected ? 3 : 1),
          ),
          alignment: Alignment.center,
          child: isAuto
              ? Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
      ),
    );
  }
}
