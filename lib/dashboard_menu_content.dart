import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'controls/flights_sheet.dart';
import 'controls/weather_sheet.dart';
import 'data/dashboard_page_templates.dart';
import 'l10n/app_localizations.dart';

class DashboardMenuContent extends StatelessWidget {
  final bool isEditMode;
  final int pageIndex;
  final int pageCount;
  final double gridSize;
  final int controlCount;
  final ValueChanged<double> onGridSizeChanged;
  final VoidCallback onToggleEditMode;
  final VoidCallback onAddControl;
  final ValueChanged<DashboardPageTemplate> onApplyPageTemplate;
  final VoidCallback onAddPage;
  final VoidCallback onDeletePage;
  final VoidCallback onClearAll;
  final VoidCallback onOpenPreferences;

  const DashboardMenuContent({
    super.key,
    required this.isEditMode,
    required this.pageIndex,
    required this.pageCount,
    required this.gridSize,
    required this.controlCount,
    required this.onGridSizeChanged,
    required this.onToggleEditMode,
    required this.onAddControl,
    required this.onApplyPageTemplate,
    required this.onAddPage,
    required this.onDeletePage,
    required this.onClearAll,
    required this.onOpenPreferences,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      // Wrap content height so the panel matches the items (no blank space);
      // scrolls only when the items exceed the panel's max height.
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        SwitchListTile(
          secondary: Icon(_menuIcons.mode, color: theme.colorScheme.primary),
          title: Text(l10n.editMode),
          subtitle: Text(l10n.pageOfPages(pageIndex + 1, pageCount)),
          value: isEditMode,
          onChanged: (_) => onToggleEditMode(),
        ),
        // Control- and page-editing items are only meaningful in edit mode.
        if (isEditMode) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.pageTemplate,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            l10n.pageTemplateSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DashboardPageTemplate>(
                      value: null,
                      hint: Text(l10n.pageTemplateChoose),
                      isExpanded: true,
                      menuMaxHeight: 360,
                      borderRadius: BorderRadius.circular(12),
                      items: DashboardPageTemplates.all
                          .map(
                            (template) => DropdownMenuItem(
                              value: template,
                              child: Row(
                                children: [
                                  Icon(
                                    template.icon,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(template.titleOf(l10n)),
                                        Text(
                                          template.descriptionOf(l10n),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (template) {
                        if (template != null) onApplyPageTemplate(template);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.add_box_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(l10n.addControl),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onAddControl,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.note_add_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(l10n.addPage),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onAddPage,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: pageCount > 1
                  ? theme.colorScheme.error
                  : theme.disabledColor,
            ),
            title: Text(
              l10n.deletePage,
              style: TextStyle(
                color: pageCount > 1
                    ? theme.colorScheme.error
                    : theme.disabledColor,
              ),
            ),
            enabled: pageCount > 1,
            onTap: pageCount > 1 ? onDeletePage : null,
          ),
          const Divider(height: 1),
          // Grid size slider — only meaningful while placing/resizing
          // controls, so it lives under the edit-mode section of the menu.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _menuIcons.grid,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l10n.gridSize)),
                    Text(
                      l10n.gridSizePx(gridSize.round()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: gridSize.clamp(16.0, 120.0),
                  min: 16.0,
                  max: 120.0,
                  divisions: 26, // step = 4px
                  label: l10n.gridSizePx(gridSize.round()),
                  onChanged: onGridSizeChanged,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_sweep_outlined,
              color: controlCount > 0
                  ? theme.colorScheme.error
                  : theme.disabledColor,
            ),
            title: Text(
              l10n.clearAllControls,
              style: TextStyle(
                color: controlCount > 0
                    ? theme.colorScheme.error
                    : theme.disabledColor,
              ),
            ),
            subtitle: Text(l10n.controlsPlaced(controlCount)),
            enabled: controlCount > 0,
            onTap: controlCount > 0 ? onClearAll : null,
          ),
        ],
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.route, color: theme.colorScheme.primary),
          title: Text(l10n.flights),
          subtitle: Text(l10n.flightsSubtitle),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => showFlightsSheet(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.air, color: theme.colorScheme.primary),
          title: Text(l10n.weather),
          subtitle: Text(l10n.weatherSubtitle),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => showWeatherSheet(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(_menuIcons.settings, color: theme.colorScheme.primary),
          title: Text(l10n.preferences),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onOpenPreferences,
        ),
      ],
    );
  }
}

const _menuIcons = (
  mode: Icons.edit_outlined,
  grid: Icons.grid_4x4,
  settings: Icons.settings_outlined,
);
