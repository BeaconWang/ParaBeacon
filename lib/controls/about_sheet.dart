import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import 'about_info_sphere.dart';

Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _AboutSheet(),
  );
}

class _AboutSheet extends StatefulWidget {
  const _AboutSheet();

  @override
  State<_AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<_AboutSheet> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  String _platformName(AppLocalizations l10n) {
    if (kIsWeb) return l10n.aboutPlatformWeb;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => l10n.aboutPlatformAndroid,
      TargetPlatform.iOS => l10n.aboutPlatformIos,
      TargetPlatform.linux => l10n.aboutPlatformLinux,
      TargetPlatform.macOS => l10n.aboutPlatformMacos,
      TargetPlatform.windows => l10n.aboutPlatformWindows,
      TargetPlatform.fuchsia => l10n.aboutPlatformFuchsia,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.about, style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(l10n.aboutLoading),
                      ],
                    ),
                  );
                }

                final packageInfo = snapshot.data;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Center(
                      child: Icon(
                        Icons.flight_takeoff,
                        size: 44,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        l10n.appTitle,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.aboutDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.aboutSphereTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    AboutInfoSphere(
                      labels: const [
                        '师父：炉头',
                        '涂君',
                        '刘登科',
                        '李永林',
                        '中奇',
                        '十一',
                      ],
                      semanticsLabel: l10n.aboutSphereSemantics,
                      dragHint: l10n.aboutSphereHint,
                    ),
                    Text(
                      l10n.aboutSphereHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeading(context, l10n.aboutApplicationDetails),
                    _detailRow(
                      context,
                      label: l10n.aboutVersion,
                      value: packageInfo?.version ?? '—',
                    ),
                    _detailRow(
                      context,
                      label: l10n.aboutBuildNumber,
                      value: packageInfo?.buildNumber ?? '—',
                    ),
                    _detailRow(
                      context,
                      label: l10n.aboutPackageId,
                      value: packageInfo?.packageName ?? '—',
                    ),
                    _detailRow(
                      context,
                      label: l10n.aboutPlatform,
                      value: _platformName(l10n),
                    ),
                    const SizedBox(height: 20),
                    _sectionHeading(context, l10n.aboutCapabilities),
                    _capability(context, l10n.aboutCapabilityDashboard),
                    _capability(context, l10n.aboutCapabilityVario),
                    _capability(context, l10n.aboutCapabilitySensors),
                    _capability(context, l10n.aboutCapabilityMapping),
                    _capability(context, l10n.aboutCapabilityFlights),
                    _capability(context, l10n.aboutCapabilityIntegrations),
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: Text(l10n.aboutOpenSourceLicenses),
                        subtitle: Text(l10n.aboutOpenSourceLicensesSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName:
                              packageInfo?.appName ?? l10n.appTitle,
                          applicationVersion: packageInfo == null
                              ? null
                              : '${packageInfo.version}+${packageInfo.buildNumber}',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: theme.textTheme.titleMedium),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _capability(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
