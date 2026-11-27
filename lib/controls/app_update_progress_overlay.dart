import 'package:flutter/material.dart';

import '../data/app_update_service.dart';
import '../l10n/app_localizations.dart';

class AppUpdateProgressOverlay extends StatefulWidget {
  const AppUpdateProgressOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<AppUpdateProgressOverlay> createState() =>
      _AppUpdateProgressOverlayState();
}

class _AppUpdateProgressOverlayState extends State<AppUpdateProgressOverlay> {
  int _dismissedGeneration = -1;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppUpdateService.instance,
    builder: (context, _) {
      final updater = AppUpdateService.instance;
      final release = updater.availableRelease;
      final generation = updater.downloadGeneration;
      if (updater.status != AppUpdateStatus.downloading ||
          release == null ||
          generation == _dismissedGeneration) {
        return widget.child;
      }
      final l10n = AppLocalizations.of(context);
      final progress = updater.downloadProgress ?? 0;
      final percent = (progress * 100).round();
      final colors = Theme.of(context).colorScheme;
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          PositionedDirectional(
            top: 8,
            start: 12,
            end: 12,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Material(
                    color: colors.surface,
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        8,
                        8,
                        12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.appUpdateDownloading(
                                    release.versionName,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text('$percent%'),
                              IconButton(
                                tooltip: l10n.close,
                                onPressed: () => setState(
                                  () => _dismissedGeneration = generation,
                                ),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          LinearProgressIndicator(value: progress),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
