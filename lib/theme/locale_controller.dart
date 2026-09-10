import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_languages.dart';

/// App-wide language selection.
///
/// Singleton [ChangeNotifier] that owns the currently active [AppLanguage] and
/// persists the user's choice across launches. The root [MaterialApp] listens
/// to it (alongside [ThemeController]) and rebuilds when the language changes,
/// so `MaterialApp.locale` — and therefore every localized widget, date/number
/// format and the text direction — updates automatically with no per-widget
/// wiring.
///
/// Mirrors the shape of [ThemeController] (lazy [load], best-effort
/// persistence, silent fallback on storage errors) so behavior stays
/// predictable across the app.
class LocaleController extends ChangeNotifier {
  LocaleController._();

  /// Shared singleton.
  static final LocaleController instance = LocaleController._();

  // ── Persistence keys ──────────────────────────────────────────────────────
  static const _kLanguageKey = 'pb.language';

  // ── Current values (defaults) ─────────────────────────────────────────────
  AppLanguage _current = AppLanguage.system;

  /// Currently active language selection.
  AppLanguage get current => _current;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Loads the persisted selection (if any). Safe to call multiple times;
  /// only the first call reads storage. Fire-and-forget from `main()`.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getString(_kLanguageKey);
      _current = AppLanguage.fromKey(saved);
    } catch (_) {
      // Storage unavailable: keep the default (follow the system language).
    }
    notifyListeners();
  }

  /// Switches to [language] and persists the change. No-op if it is already
  /// active (avoids a spurious rebuild).
  Future<void> setLanguage(AppLanguage language) async {
    if (_current == language) return;
    _current = language;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kLanguageKey, language.storageKey);
    } catch (_) {
      // Storage unavailable: the in-memory choice still applies for this
      // session; it just won't survive a restart.
    }
  }
}
