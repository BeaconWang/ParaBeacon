import 'package:flutter/material.dart';

import 'app_themes.dart';
import 'theme_controller.dart';

/// Opens the theme picker as a modal bottom sheet.
///
/// Lists every built-in [AppThemeId] preset grouped into Dark / Light /
/// High-contrast. Tapping a row selects the theme via [ThemeController],
/// which persists it and rebuilds the whole app tree so the change is
/// visible immediately.
Future<void> showThemeSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _ThemeSettingsSheet(),
  );
}

class _ThemeSettingsSheet extends StatefulWidget {
  const _ThemeSettingsSheet();

  @override
  State<_ThemeSettingsSheet> createState() => _ThemeSettingsSheetState();
}

class _ThemeSettingsSheetState extends State<_ThemeSettingsSheet> {
  AppThemeId _selected = ThemeController.instance.current;

  Future<void> _select(AppThemeId id) async {
    await ThemeController.instance.setTheme(id);
    if (!mounted) return;
    setState(() => _selected = id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = <AppThemeGroup, List<AppThemeId>>{
      for (final id in AppThemeId.values) id.group: [],
    };
    for (final id in AppThemeId.values) {
      grouped[id.group]!.add(id);
    }

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
                Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Theme / 主题',
                      style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _section('Dark themes / 暗色主题',
                      grouped[AppThemeGroup.dark]!),
                  _section('Light themes / 亮色主题',
                      grouped[AppThemeGroup.light]!),
                  _section(
                      'High contrast / 高对比度（WCAG AAA）',
                      grouped[AppThemeGroup.highContrast]!),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '切换后立即生效，无需重启。配色会持久化到本地。\n'
                      '高对比度主题：纯黑/纯白底 + 高饱和高亮，'
                      '适合强阳光下飞行、视力疲劳、年长用户。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<AppThemeId> ids) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < ids.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  _row(ids[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppThemeId id) {
    final theme = Theme.of(context);
    final selected = _selected == id;
    // Render the swatch using the *target* theme's colors, not the
    // currently-active one, so the preview reflects what the user is about
    // to pick even before they tap it.
    final preview = themeDataFor(id).colorScheme;
    return InkWell(
      onTap: () => _select(id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            _Swatch(scheme: preview),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    id.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniature four-cell swatch previewing a theme's background + accent trio.
class _Swatch extends StatelessWidget {
  final ColorScheme scheme;

  const _Swatch({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dot(scheme.primary),
          _dot(scheme.secondary),
          _dot(scheme.tertiary),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
