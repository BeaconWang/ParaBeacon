import 'package:flutter/material.dart';

import '../data/competition/competition_task.dart';
import '../l10n/app_localizations.dart';

class CompetitionTaskPreviewSheet extends StatelessWidget {
  const CompetitionTaskPreviewSheet({
    required this.task,
    required this.l10n,
    super.key,
  });

  final CompetitionTask task;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskName = task.name.trim().isEmpty
        ? l10n.competitionUnnamedTask
        : task.name;
    final start = task.start;
    final goalType = task.goal.type == TaskGoalType.line
        ? l10n.competitionGoalLine
        : l10n.competitionGoalCylinder;
    final deadline = task.goal.deadlineSeconds == null
        ? l10n.competitionNoDeadline
        : secondsToClock(task.goal.deadlineSeconds!);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.competitionServerPreview,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.flag_outlined),
                        ),
                        title: Text(taskName),
                        subtitle: Text(
                          l10n.competitionTaskSummarySubtitle(
                            task.turnpoints.length,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < task.turnpoints.length; index++)
                      _TurnpointPreviewCard(
                        index: index,
                        turnpoint: task.turnpoints[index],
                        l10n: l10n,
                      ),
                    if (start != null)
                      _PreviewInfoCard(
                        title: l10n.competitionStartSection,
                        lines: [
                          '${l10n.competitionStartType}: ${start.type == TaskStartType.race ? l10n.competitionStartTypeRace : l10n.competitionStartTypeElapsed}',
                          '${l10n.competitionStartDirection}: ${start.direction == TaskStartDirection.enter ? l10n.competitionStartEnter : l10n.competitionStartExit}',
                          if (start.timeGates.isNotEmpty)
                            '${l10n.competitionTimeGates}: ${start.timeGates.map(secondsToClock).join(', ')}',
                        ],
                      ),
                    _PreviewInfoCard(
                      title: l10n.competitionGoalSection,
                      lines: [
                        '${l10n.competitionGoalType}: $goalType',
                        '${l10n.competitionDeadline}: $deadline',
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.competitionServerUseTask),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnpointPreviewCard extends StatelessWidget {
  const _TurnpointPreviewCard({
    required this.index,
    required this.turnpoint,
    required this.l10n,
  });

  final int index;
  final Turnpoint turnpoint;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = turnpoint.name.trim().isEmpty
        ? l10n.competitionTurnpointShort(index + 1)
        : turnpoint.name;
    final role = switch (turnpoint.role) {
      TurnpointRole.takeoff => l10n.competitionRoleTakeoff,
      TurnpointRole.sss => l10n.competitionRoleSss,
      TurnpointRole.ess => l10n.competitionRoleEss,
      TurnpointRole.turnpoint => l10n.competitionRoleTurnpoint,
    };
    final coordinates =
        '${turnpoint.latitude.toStringAsFixed(5)}, '
        '${turnpoint.longitude.toStringAsFixed(5)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(label),
        subtitle: Text(
          '$role · $coordinates · ${turnpoint.radiusMeters.round()} m',
        ),
      ),
    );
  }
}

class _PreviewInfoCard extends StatelessWidget {
  const _PreviewInfoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final line in lines) Text(line),
        ],
      ),
    ),
  );
}
