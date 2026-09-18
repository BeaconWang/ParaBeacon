import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/language_settings_sheet.dart';
import '../theme/theme_settings_sheet.dart';
import 'accounts_sheet.dart';
import 'flights_sheet.dart';

Future<void> showMineSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _MineSheet(),
  );
}

class _MineFeature {
  const _MineFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.requiresLogin = true,
    this.isAvailable = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final bool requiresLogin;
  final bool isAvailable;
}

class _MineSheet extends StatefulWidget {
  const _MineSheet();

  @override
  State<_MineSheet> createState() => _MineSheetState();
}

class _MineSheetState extends State<_MineSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = AsfcAuthService.instance;
      await auth.load();
      if (auth.isSignedIn) await auth.loadProfile();
    });
  }

  Future<void> _openFeature(_MineFeature feature) async {
    final auth = AsfcAuthService.instance;
    if (feature.requiresLogin && !auth.isSignedIn) {
      await showAccountsSheet(context);
      return;
    }
    if (feature.title == AppLocalizations.of(context).mineFlightRecords) {
      await showFlightsSheet(context);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _MineFeatureSheet(feature: feature),
    );
  }

  Future<void> _openSettings() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              l10n.mineSettings,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.theme),
              onTap: () => showThemeSettingsSheet(context),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              onTap: () => showLanguageSettingsSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  List<_MineFeature> _features(AppLocalizations l10n) => [
    _MineFeature(
      icon: Icons.emoji_events_outlined,
      title: l10n.mineCompetitions,
      subtitle: l10n.mineCompetitionsSubtitle,
      detail: l10n.mineCompetitionsDetail,
    ),
    _MineFeature(
      icon: Icons.school_outlined,
      title: l10n.mineTraining,
      subtitle: l10n.mineTrainingSubtitle,
      detail: l10n.mineTrainingDetail,
    ),
    _MineFeature(
      icon: Icons.assignment_outlined,
      title: l10n.mineExams,
      subtitle: l10n.mineExamsSubtitle,
      detail: l10n.mineExamsDetail,
    ),
    _MineFeature(
      icon: Icons.workspace_premium_outlined,
      title: l10n.mineCertificates,
      subtitle: l10n.mineCertificatesSubtitle,
      detail: l10n.mineCertificatesDetail,
    ),
    _MineFeature(
      icon: Icons.card_membership_outlined,
      title: l10n.mineLicenses,
      subtitle: l10n.mineLicensesSubtitle,
      detail: l10n.mineLicensesDetail,
    ),
    _MineFeature(
      icon: Icons.badge_outlined,
      title: l10n.mineMembership,
      subtitle: l10n.mineMembershipSubtitle,
      detail: l10n.mineMembershipDetail,
    ),
    _MineFeature(
      icon: Icons.confirmation_num_outlined,
      title: l10n.mineTicketBookings,
      subtitle: l10n.mineTicketBookingsSubtitle,
      detail: l10n.mineTicketBookingsDetail,
    ),
    _MineFeature(
      icon: Icons.cabin_outlined,
      title: l10n.mineCampBookings,
      subtitle: l10n.mineCampBookingsSubtitle,
      detail: l10n.mineCampBookingsDetail,
    ),
    _MineFeature(
      icon: Icons.route_outlined,
      title: l10n.mineFlightRecords,
      subtitle: l10n.mineFlightRecordsSubtitle,
      detail: l10n.mineFlightRecordsDetail,
      isAvailable: true,
    ),
    _MineFeature(
      icon: Icons.groups_outlined,
      title: l10n.mineTeams,
      subtitle: l10n.mineTeamsSubtitle,
      detail: l10n.mineTeamsDetail,
    ),
    _MineFeature(
      icon: Icons.bookmark_outline,
      title: l10n.mineFavorites,
      subtitle: l10n.mineFavoritesSubtitle,
      detail: l10n.mineFavoritesDetail,
    ),
    _MineFeature(
      icon: Icons.gavel_outlined,
      title: l10n.mineJudging,
      subtitle: l10n.mineJudgingSubtitle,
      detail: l10n.mineJudgingDetail,
    ),
    _MineFeature(
      icon: Icons.video_library_outlined,
      title: l10n.mineTrainingMaterials,
      subtitle: l10n.mineTrainingMaterialsSubtitle,
      detail: l10n.mineTrainingMaterialsDetail,
    ),
    _MineFeature(
      icon: Icons.verified_user_outlined,
      title: l10n.mineIdentityVerification,
      subtitle: l10n.mineIdentityVerificationSubtitle,
      detail: l10n.mineIdentityVerificationDetail,
    ),
    _MineFeature(
      icon: Icons.paragliding_outlined,
      title: l10n.mineEquipment,
      subtitle: l10n.mineEquipmentSubtitle,
      detail: l10n.mineEquipmentDetail,
    ),
    _MineFeature(
      icon: Icons.assignment_turned_in_outlined,
      title: l10n.mineRegistration,
      subtitle: l10n.mineRegistrationSubtitle,
      detail: l10n.mineRegistrationDetail,
    ),
    _MineFeature(
      icon: Icons.info_outline,
      title: l10n.mineAbout,
      subtitle: l10n.mineAboutSubtitle,
      detail: l10n.mineAboutDetail,
      requiresLogin: false,
      isAvailable: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: AsfcAuthService.instance,
      builder: (context, _) {
        final auth = AsfcAuthService.instance;
        final features = _features(l10n);
        return Material(
          color: theme.colorScheme.surface,
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  title: Text(l10n.mine),
                  actions: [
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _profileCard(theme, l10n, auth),
                      const SizedBox(height: 22),
                      _sectionTitle(theme, l10n.mineSportsData),
                      const SizedBox(height: 8),
                      _featureGrid(features.take(8).toList()),
                      const SizedBox(height: 22),
                      _sectionTitle(theme, l10n.mineMoreFeatures),
                      const SizedBox(height: 8),
                      ...features.skip(8).map(_featureTile),
                      const Divider(height: 28),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.settings_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(l10n.mineSettings),
                        subtitle: Text(l10n.mineSettingsSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openSettings,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.feedback_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(l10n.mineFeedback),
                        subtitle: Text(l10n.mineFeedbackSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openFeature(
                          _MineFeature(
                            icon: Icons.feedback_outlined,
                            title: l10n.mineFeedback,
                            subtitle: l10n.mineFeedbackSubtitle,
                            detail: l10n.mineFeedbackDetail,
                            requiresLogin: false,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileCard(
    ThemeData theme,
    AppLocalizations l10n,
    AsfcAuthService auth,
  ) {
    if (!auth.isSignedIn) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            radius: 28,
            child: Icon(Icons.person_outline, color: theme.colorScheme.primary),
          ),
          title: Text(l10n.asfcAccount),
          subtitle: Text(l10n.mineSignInPrompt),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showAccountsSheet(context),
        ),
      );
    }
    final profile = auth.profile;
    final user = profile?['user'];
    final circle = profile?['circleInfo'];
    final name =
        (circle is Map<String, dynamic> ? circle['userNickname'] : null) ??
        (user is Map<String, dynamic> ? user['username'] : null) ??
        auth.username ??
        l10n.asfcAccount;
    final avatar = auth.avatarUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAccountsSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: avatar == null ? null : NetworkImage(avatar),
                child: avatar == null
                    ? Text(name.toString().substring(0, 1).toUpperCase())
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toString(), style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      l10n.asfcSignedIn,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) => Text(
    title,
    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _featureGrid(List<_MineFeature> features) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.45,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final feature = features[index];
        final theme = Theme.of(context);
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openFeature(feature),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(feature.icon, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    feature.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feature.isAvailable
                        ? AppLocalizations.of(context).mineAvailable
                        : AppLocalizations.of(context).mineNotConnected,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: feature.isAvailable
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _featureTile(_MineFeature feature) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(feature.icon, color: theme.colorScheme.primary),
      title: Text(feature.title),
      subtitle: Text(feature.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openFeature(feature),
    );
  }
}

class _MineFeatureSheet extends StatelessWidget {
  const _MineFeatureSheet({required this.feature});

  final _MineFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(feature.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(feature.title, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(feature.detail, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: feature.isAvailable
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                feature.isAvailable
                    ? l10n.mineAvailableDetail
                    : l10n.mineNotConnectedDetail,
                style: TextStyle(
                  color: feature.isAvailable
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
