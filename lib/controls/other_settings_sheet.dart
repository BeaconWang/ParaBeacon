import 'package:flutter/material.dart';

import '../data/map_tile_cache.dart';
import '../data/share_card_settings.dart';
import '../l10n/app_localizations.dart';
import 'map_control.dart' show MapTileSources;

Future<void> showOtherSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _OtherSettingsSheet(),
  );
}

class _OtherSettingsSheet extends StatefulWidget {
  const _OtherSettingsSheet();

  @override
  State<_OtherSettingsSheet> createState() => _OtherSettingsSheetState();
}

class _OtherSettingsSheetState extends State<_OtherSettingsSheet> {
  Future<MapTileCacheSummary>? _mapCacheSummaryFuture;

  String _formatMapCacheSize(int bytes) {
    const units = ['B', 'KiB', 'MiB', 'GiB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final formatted = unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$formatted ${units[unitIndex]}';
  }

  String _sourceLabel(AppLocalizations l10n, String id) => switch (id) {
    'osm' => l10n.settingMapSourceOsm,
    'osmfr' => l10n.settingMapSourceOsmFr,
    'carto-dark' => l10n.settingMapSourceCartoDark,
    'carto-voyager' => l10n.settingMapSourceCartoVoyager,
    'amap' => l10n.settingMapSourceAmap,
    'amap-sat' => l10n.settingMapSourceAmapSat,
    _ => id,
  };

  String _details(AppLocalizations l10n, MapTileCacheStats stats) =>
      l10n.mapCacheSizeDetails(
        _formatMapCacheSize(stats.bytes),
        stats.tileCount,
        stats.bytes,
      );

  Future<void> _clearMapTileCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mapCacheClearTitle),
        content: Text(l10n.mapCacheClearConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await MapTileCacheService.instance.clearCache();
      if (!mounted) return;
      setState(() {
        _mapCacheSummaryFuture = MapTileCacheService.instance.getCacheSummary();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.mapCacheCleared)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.mapCacheClearFailed)));
    }
  }

  Widget _buildMapCache(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(l10n.mapCacheTitle, style: theme.textTheme.titleMedium),
        ),
        Text(
          l10n.mapCacheSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        FutureBuilder<MapTileCacheSummary>(
          future: _mapCacheSummaryFuture ??= MapTileCacheService.instance
              .getCacheSummary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.mapCacheSummary),
                subtitle: Text(l10n.mapCacheSizeLoading),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.mapCacheSummary),
                subtitle: Text(l10n.mapCacheSizeUnavailable),
              );
            }
            final summary = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.summarize_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.mapCacheSummary),
                  subtitle: Text(_details(l10n, summary.total)),
                  trailing: IconButton(
                    tooltip: l10n.clear,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _clearMapTileCache,
                  ),
                ),
                for (final source in MapTileSources.all)
                  if (!source.isNone)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 16),
                      title: Text(_sourceLabel(l10n, source.id)),
                      subtitle: Text(
                        _details(
                          l10n,
                          summary.bySource[source.id] ??
                              const MapTileCacheStats(bytes: 0, tileCount: 0),
                        ),
                      ),
                    ),
                if ((summary.bySource['legacy']?.bytes ?? 0) > 0)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 16),
                    title: Text(l10n.mapCacheLegacySource),
                    subtitle: Text(_details(l10n, summary.bySource['legacy']!)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ShareCardSettings.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.more_horiz, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        l10n.otherSettings,
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.otherSettingsSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.layers_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.shareCardFlatDesign),
                    subtitle: Text(l10n.shareCardFlatDesignSubtitle),
                    value: ShareCardSettings.instance.flatDesign,
                    onChanged: ShareCardSettings.instance.setFlatDesign,
                  ),
                  _buildMapCache(l10n, theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
