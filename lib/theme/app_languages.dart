import 'dart:ui' show Locale;

import '../l10n/app_localizations.dart';

/// Catalog of the app's selectable UI languages.
///
/// Mirrors the shape of [AppThemeId]: a small enum with a stable [storageKey]
/// for persistence, display [label]s for the picker, a resolved [locale] fed
/// into the root [MaterialApp], and a [fromKey] resolver that falls back to
/// the default when the persisted value is missing / unknown.
///
/// [system] is the default: it lets the platform decide the locale (so the app
/// follows the device language) by passing a `null` locale to [MaterialApp].
enum AppLanguage {
  /// Follow the device/OS language.
  system,

  /// English.
  english,

  /// Simplified Chinese.
  chineseSimplified;

  /// Stable string used for `SharedPreferences` persistence. Must stay fixed
  /// even if the enum is renamed, or every user's choice silently resets on
  /// the next launch.
  String get storageKey {
    switch (this) {
      case AppLanguage.system:
        return 'system';
      case AppLanguage.english:
        return 'en';
      case AppLanguage.chineseSimplified:
        return 'zh_CN';
    }
  }

  /// Localized display label shown in the language picker.
  String labelOf(AppLocalizations l10n) {
    switch (this) {
      case AppLanguage.system:
        return l10n.languageSystemDefault;
      case AppLanguage.english:
        return l10n.languageEnglish;
      case AppLanguage.chineseSimplified:
        return l10n.languageChineseSimplified;
    }
  }

  /// Localized one-line description shown under the label.
  String descriptionOf(AppLocalizations l10n) {
    switch (this) {
      case AppLanguage.system:
        return l10n.languageSystemDescription;
      case AppLanguage.english:
        return l10n.languageEnglishDescription;
      case AppLanguage.chineseSimplified:
        return l10n.languageChineseSimplifiedDescription;
    }
  }

  /// The [Locale] to hand to [MaterialApp.locale]. `null` for [system] so the
  /// framework resolves the best match from the device settings against
  /// [supportedLocales].
  Locale? get locale {
    switch (this) {
      case AppLanguage.system:
        return null;
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.chineseSimplified:
        return const Locale('zh', 'CN');
    }
  }

  /// Every non-system locale the app declares support for. Used to populate
  /// [MaterialApp.supportedLocales].
  static List<Locale> get supportedLocales => [
        for (final lang in AppLanguage.values)
          if (lang.locale != null) lang.locale!,
      ];

  /// Resolves a persisted [storageKey] back to a language, falling back to
  /// [system] when the value is missing / unknown.
  static AppLanguage fromKey(String? key) {
    if (key == null) return AppLanguage.system;
    for (final lang in AppLanguage.values) {
      if (lang.storageKey == key) return lang;
    }
    return AppLanguage.system;
  }
}
