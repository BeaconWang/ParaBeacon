import 'package:flutter/material.dart';

import '../data/color_palette_settings.dart';
import '../data/flight_recorder.dart';
import '../data/flight_store.dart';
import '../data/flight_details_settings.dart';
import '../data/map_tile_cache.dart';
import '../data/map_source.dart';
import '../data/share_card_settings.dart';
import '../data/user_agent_settings.dart';
import '../data/vertical_speed_settings.dart';
import '../l10n/app_localizations.dart';
import 'color_palette_settings_sheet.dart';
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
  Future<int>? _flightLibrarySizeFuture;
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
    'opentopomap' => l10n.settingMapSourceOpenTopoMap,
    'esri-world-imagery' => l10n.settingMapSourceEsriImagery,
    _ => id,
  };

  String _details(AppLocalizations l10n, MapTileCacheStats stats) => l10n
      .mapCacheSizeDetails(_formatMapCacheSize(stats.bytes), stats.tileCount);

  Future<void> _editUserAgent() async {
    final settings = UserAgentSettings.instance;
    final controller = TextEditingController(text: settings.userAgent);
    var invalid = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).networkUserAgentTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).networkUserAgentSubtitle),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                maxLength: 512,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: invalid
                      ? AppLocalizations.of(context).networkUserAgentInvalid
                      : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await settings.resetToChromeDefault();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Text(AppLocalizations.of(context).networkUserAgentReset),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () async {
                final saved = await settings.setUserAgent(controller.text);
                if (!saved) {
                  setDialogState(() => invalid = true);
                  return;
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

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

  Widget _buildFlightLibraryStorage(AppLocalizations l10n, ThemeData theme) {
    final flightCount = FlightRecorder.instance.tracks.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FutureBuilder<int>(
        future: _flightLibrarySizeFuture ??= FlightStore.instance
            .storageSizeBytes(),
        builder: (context, snapshot) {
          final subtitle = snapshot.connectionState != ConnectionState.done
              ? l10n.flightLibraryStorageLoading
              : snapshot.hasError || !snapshot.hasData
              ? l10n.flightLibraryStorageUnavailable
              : l10n.flightLibraryStorageDetails(
                  _formatMapCacheSize(snapshot.data!),
                  flightCount,
                );
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.flight_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(l10n.flightLibraryStorageTitle),
            subtitle: Text(subtitle),
          );
        },
      ),
    );
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

  Widget _buildOutlierSlider({
    required ThemeData theme,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
              Text(valueLabel, style: theme.textTheme.bodyMedium),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ShareCardSettings.instance,
        UserAgentSettings.instance,
        FlightDetailsSettings.instance,
        VerticalSpeedSettings.instance,
      ]),
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
                      Icons.view_agenda_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.shareCardCompactLayout),
                    subtitle: Text(l10n.shareCardCompactLayoutSubtitle),
                    value: ShareCardSettings.instance.compactLayout,
                    onChanged: ShareCardSettings.instance.setCompactLayout,
                  ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.map_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.shareCardMapSource),
                          subtitle: Text(l10n.shareCardMapSourceSubtitle),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 56, right: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                ShareCardSettings.instance.mapSourceId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'none',
                                child: Text(l10n.settingMapSourceNone),
                              ),
                              for (final source
                                  in MapSourceCatalog.secureRasterSources)
                                DropdownMenuItem(
                                  value: source.id,
                                  child: Text(
                                    _sourceLabel(l10n, source.id),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (id) {
                              if (id != null) {
                                ShareCardSettings.instance.setMapSourceId(id);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.language,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.networkUserAgentTitle),
                    subtitle: Text(
                      UserAgentSettings.instance.userAgent,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _editUserAgent,
                  ),
                  _buildOutlierSlider(
                    theme: theme,
                    title: l10n.verticalSpeedAverageWindow,
                    value: VerticalSpeedSettings.instance.averageWindowSeconds,
                    min: 0.5,
                    max: 3,
                    divisions: 25,
                    valueLabel:
                        '${VerticalSpeedSettings.instance.averageWindowSeconds.toStringAsFixed(1)} s',
                    onChanged:
                        VerticalSpeedSettings.instance.setAverageWindowSeconds,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.filter_alt_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.flightDetailOutlierFilter),
                    subtitle: Text(l10n.flightDetailOutlierFilterSubtitle),
                    value: FlightDetailsSettings.instance.filterVarioOutliers,
                    onChanged:
                        FlightDetailsSettings.instance.setFilterVarioOutliers,
                  ),
                  if (FlightDetailsSettings.instance.filterVarioOutliers) ...[
                    _buildOutlierSlider(
                      theme: theme,
                      title: l10n.flightDetailOutlierSensitivity,
                      value: FlightDetailsSettings.instance.madMultiplier,
                      min: 2,
                      max: 8,
                      divisions: 12,
                      valueLabel:
                          '${FlightDetailsSettings.instance.madMultiplier.toStringAsFixed(1)}×',
                      onChanged:
                          FlightDetailsSettings.instance.setMadMultiplier,
                    ),
                    _buildOutlierSlider(
                      theme: theme,
                      title: l10n.flightDetailOutlierWindow,
                      value: FlightDetailsSettings.instance.windowSeconds
                          .toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      valueLabel:
                          '${FlightDetailsSettings.instance.windowSeconds} s',
                      onChanged:
                          FlightDetailsSettings.instance.setWindowSeconds,
                    ),
                    _buildOutlierSlider(
                      theme: theme,
                      title: l10n.flightDetailOutlierMaximumRate,
                      value:
                          FlightDetailsSettings.instance.maximumVerticalSpeedMs,
                      min: 5,
                      max: 40,
                      divisions: 35,
                      valueLabel:
                          '${FlightDetailsSettings.instance.maximumVerticalSpeedMs.toStringAsFixed(1)} m/s',
                      onChanged: FlightDetailsSettings
                          .instance
                          .setMaximumVerticalSpeedMs,
                    ),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.color_lens_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.colorPalettePreferencesTitle),
                    subtitle: AnimatedBuilder(
                      animation: ColorPaletteSettings.instance,
                      builder: (context, _) => Text(
                        l10n.colorPalettePreferencesSubtitle(
                          ColorPaletteSettings.instance.colorCount,
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () async {
                      await showColorPaletteSettingsSheet(context);
                    },
                  ),
                  _buildFlightLibraryStorage(l10n, theme),
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
