import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_themes.dart';

/// App-wide theme selection.
///
/// Singleton [ChangeNotifier] that owns the currently active [AppThemeId]
/// and persists the user's choice across launches. The root [MaterialApp]
/// listens to it via [AnimatedBuilder] and rebuilds when the id changes, so
/// every widget that reads `Theme.of(context)` inherits the new palette
/// automatically — no per-widget wiring is needed.
///
/// Mirrors the shape of [DebugSettings] / [VarioSoundSettings] so behavior
/// (lazy [load], best-effort persistence, silent fallback on storage errors)
/// stays predictable across the app.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  /// Shared singleton.
  static final ThemeController instance = ThemeController._();

  // ── Persistence keys ──────────────────────────────────────────────────────
  static const _kThemeKey = 'pb.theme';

  // ── Current values (defaults) ─────────────────────────────────────────────
  AppThemeId _current = AppThemeId.darkCyan;

  /// Currently active theme preset.
  AppThemeId get current => _current;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Loads the persisted selection (if any). Safe to call multiple times;
  /// only the first call reads storage. Fire-and-forget from `main()`.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getString(_kThemeKey);
      _current = AppThemeId.fromKey(saved);
    } catch (_) {
      // Storage unavailable: keep the default preset.
    }
    notifyListeners();
  }

  /// Switches to [id] and persists the change. No-op if the id is already
  /// active (avoids a spurious rebuild).
  Future<void> setTheme(AppThemeId id) async {
    if (_current == id) return;
    _current = id;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kThemeKey, id.storageKey);
    } catch (_) {
      // Storage unavailable: the in-memory choice still applies for this
      // session; it just won't survive a restart.
    }
  }
}
