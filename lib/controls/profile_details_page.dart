import 'package:flutter/material.dart';

import '../data/parabeacon_account_service.dart';
import '../data/pilot_avatar.dart';
import '../l10n/app_localizations.dart';
import 'app_notice.dart';
import 'profile_password_change_section.dart';

class ProfileDetailsPage extends StatelessWidget {
  const ProfileDetailsPage({
    required this.account,
    required this.onChangeProfileImage,
    required this.onOpenProfileImage,
    super.key,
  });

  final ParaBeaconAccountService account;
  final Future<void> Function() onChangeProfileImage;
  final Future<void> Function() onOpenProfileImage;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: account,
    builder: (context, _) {
      final user = account.user;
      final l10n = AppLocalizations.of(context);
      if (user == null) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.accountProfileDetailsTitle)),
          body: Center(child: Text(l10n.accountProfileSignInRequired)),
        );
      }
      final birthday = user.birthday.isEmpty
          ? l10n.accountProfileNotSet
          : MaterialLocalizations.of(
              context,
            ).formatMediumDate(DateTime.parse(user.birthday));
      return Scaffold(
        appBar: AppBar(title: Text(l10n.accountProfileDetailsTitle)),
        body: ListView(
          children: [
            _ProfileDetailRow(
              key: const ValueKey('profile-detail-name'),
              title: l10n.accountProfileName,
              value: user.displayName.isEmpty
                  ? user.username
                  : user.displayName,
              onTap: () => _editName(context, user.displayName),
            ),
            const Divider(height: 1, indent: 16),
            _ProfileDetailRow(
              key: const ValueKey('profile-detail-image'),
              title: l10n.accountProfileImage,
              trailing: PilotAvatarPicture(
                avatarId: user.avatarId,
                profileImageUrl: user.profileImageUrl,
                size: 42,
              ),
              onTap: user.profileImageUrl == null
                  ? onChangeProfileImage
                  : onOpenProfileImage,
            ),
            const Divider(height: 1, indent: 16),
            _ProfileDetailRow(
              key: const ValueKey('profile-detail-introduction'),
              title: l10n.accountProfileIntroduction,
              value: user.introduction.isEmpty
                  ? l10n.accountProfileNotSet
                  : user.introduction,
              maxValueLines: 2,
              onTap: () => _editIntroduction(context, user.introduction),
            ),
            const Divider(height: 1, indent: 16),
            _ProfileDetailRow(
              key: const ValueKey('profile-detail-gender'),
              title: l10n.accountProfileGender,
              value: _genderLabel(l10n, user.gender),
              onTap: () => _editGender(context, user.gender),
            ),
            const Divider(height: 1, indent: 16),
            _ProfileDetailRow(
              key: const ValueKey('profile-detail-birthday'),
              title: l10n.accountProfileBirthday,
              value: birthday,
              onTap: () => _editBirthday(context, user.birthday),
            ),
            const Divider(height: 1, indent: 16),
            _ProfileDetailRow(
              key: const ValueKey('profile-change-password'),
              title: l10n.accountChangePassword,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ProfilePasswordChangePage(account: account),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  String _genderLabel(AppLocalizations l10n, String gender) => switch (gender) {
    'male' => l10n.accountGenderMale,
    'female' => l10n.accountGenderFemale,
    'other' => l10n.accountGenderOther,
    'prefer_not_to_say' => l10n.accountGenderPreferNotToSay,
    _ => l10n.accountProfileNotSet,
  };

  Future<void> _editName(BuildContext context, String currentName) async {
    final l10n = AppLocalizations.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ProfileTextEditorDialog(
        title: l10n.accountProfileName,
        initialValue: currentName,
        maxLength: 48,
        capitalized: true,
        saveLabel: l10n.save,
        cancelLabel: l10n.cancel,
      ),
    );
    if (value == null || !context.mounted) return;
    final saved = await account.updateDisplayName(value);
    if (!context.mounted) return;
    _showSaveResult(context, saved, l10n);
  }

  Future<void> _editIntroduction(
    BuildContext context,
    String currentIntroduction,
  ) async {
    final l10n = AppLocalizations.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ProfileTextEditorDialog(
        title: l10n.accountProfileIntroduction,
        initialValue: currentIntroduction,
        hint: l10n.accountIntroductionHint,
        maxLength: 200,
        maxLines: 5,
        capitalization: TextCapitalization.sentences,
        saveLabel: l10n.save,
        cancelLabel: l10n.cancel,
      ),
    );
    if (value == null || !context.mounted) return;
    final saved = await account.updateProfileDetails(introduction: value);
    if (!context.mounted) return;
    _showSaveResult(context, saved, l10n);
  }

  Future<void> _editGender(BuildContext context, String currentGender) async {
    final l10n = AppLocalizations.of(context);
    const genders = <String>[
      'male',
      'female',
      'other',
      'prefer_not_to_say',
      '',
    ];
    final labels = <String, String>{
      'male': l10n.accountGenderMale,
      'female': l10n.accountGenderFemale,
      'other': l10n.accountGenderOther,
      'prefer_not_to_say': l10n.accountGenderPreferNotToSay,
      '': l10n.accountProfileNotSet,
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final gender in genders)
              ListTile(
                title: Text(labels[gender]!),
                trailing: currentGender == gender
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(gender),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    final saved = await account.updateProfileDetails(gender: selected);
    if (!context.mounted) return;
    _showSaveResult(context, saved, l10n);
  }

  Future<void> _editBirthday(
    BuildContext context,
    String currentBirthday,
  ) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(currentBirthday);
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selected == null || !context.mounted) return;
    final value =
        '${selected.year.toString().padLeft(4, '0')}-'
        '${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';
    final saved = await account.updateProfileDetails(birthday: value);
    if (!context.mounted) return;
    _showSaveResult(context, saved, AppLocalizations.of(context));
  }

  void _showSaveResult(
    BuildContext context,
    bool saved,
    AppLocalizations l10n,
  ) {
    AppNotice.show(
      saved ? l10n.accountProfileFieldSaved : l10n.accountProfileFieldInvalid,
    );
  }
}

class _ProfileTextEditorDialog extends StatefulWidget {
  const _ProfileTextEditorDialog({
    required this.title,
    required this.initialValue,
    required this.maxLength,
    required this.saveLabel,
    required this.cancelLabel,
    this.hint,
    this.maxLines = 1,
    this.capitalized = false,
    this.capitalization = TextCapitalization.none,
  });

  final String title;
  final String initialValue;
  final String? hint;
  final int maxLength;
  final int maxLines;
  final bool capitalized;
  final TextCapitalization capitalization;
  final String saveLabel;
  final String cancelLabel;

  @override
  State<_ProfileTextEditorDialog> createState() =>
      _ProfileTextEditorDialogState();
}

class _ProfileTextEditorDialogState extends State<_ProfileTextEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: widget.maxLines == 1 ? 1 : 3,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      textCapitalization: widget.capitalized
          ? TextCapitalization.words
          : widget.capitalization,
      decoration: widget.hint == null
          ? null
          : InputDecoration(hintText: widget.hint),
      onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: Text(widget.saveLabel),
      ),
    ],
  );
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.title,
    required this.onTap,
    this.value,
    this.trailing,
    this.maxValueLines = 1,
    super.key,
  });

  final String title;
  final String? value;
  final Widget? trailing;
  final int maxValueLines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null)
          trailing!
        else if (value != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              value!,
              maxLines: maxValueLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    ),
    onTap: onTap,
  );
}
