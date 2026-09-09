import 'package:flutter/material.dart';

/// Catalog of built-in ParaBeacon theme presets.
///
/// Each preset is a full Material 3 [ColorScheme] tuned for one flight
/// scenario (night flying, bright sun, high-contrast for older eyes, …).
/// The controller layer (`ThemeController`) picks one preset by id and the
/// app-wide [MaterialApp] rebuilds with it — every widget that reads
/// `Theme.of(context)` (which is essentially every screen and every control
/// face) inherits the change with no per-widget wiring.
///
/// Palettes are ported from the reference project's `AppColorScheme` presets;
/// the mapping is:
///   background/surface        → surface (+ background is a Flutter alias)
///   surfaceContainer*         → surfaceContainer*
///   onSurface / onSurfaceVariant → onSurface / onSurfaceVariant
///   primaryFixedDim family    → primary + primaryContainer
///   secondaryFixedDim family  → secondary + secondaryContainer
///   tertiaryFixedDim family   → tertiary + tertiaryContainer
///   outline / outlineVariant  → outline / outlineVariant
///   error / onError           → error / onError
enum AppThemeId {
  // Dark presets — good for dusk / night / dim cockpit.
  darkCyan,
  darkSlate,
  darkAmber,
  darkForest,
  darkOcean,

  // Light presets — good for daylight / bright cockpit.
  lightSky,
  lightSand,
  lightMint,
  lightPaper,
  lightLavender,

  // High-contrast presets — WCAG-AAA-style ≥ 7:1 ratio for strong sun /
  // reduced-vision users. Kept in a separate group in the UI so users
  // don't stumble into them by accident.
  darkContrast,
  lightContrast;

  /// Stable string used for `SharedPreferences` persistence. Renaming the
  /// enum in code without keeping this key stable would silently reset
  /// every user's theme back to the default on next launch.
  String get storageKey => name;

  /// Bilingual display label used in the theme picker.
  String get label {
    switch (this) {
      case AppThemeId.darkCyan:
        return 'Dark Cyan / 暗青（默认）';
      case AppThemeId.darkSlate:
        return 'Dark Slate / 暗石板';
      case AppThemeId.darkAmber:
        return 'Dark Amber / 暗琥珀（夜视）';
      case AppThemeId.darkForest:
        return 'Dark Forest / 暗森林';
      case AppThemeId.darkOcean:
        return 'Dark Ocean / 暗海洋';
      case AppThemeId.lightSky:
        return 'Light Sky / 亮天空';
      case AppThemeId.lightSand:
        return 'Light Sand / 亮沙色';
      case AppThemeId.lightMint:
        return 'Light Mint / 亮薄荷';
      case AppThemeId.lightPaper:
        return 'Light Paper / 亮航图纸';
      case AppThemeId.lightLavender:
        return 'Light Lavender / 亮薰衣草';
      case AppThemeId.darkContrast:
        return 'Dark High-Contrast / 暗高对比';
      case AppThemeId.lightContrast:
        return 'Light High-Contrast / 亮高对比';
    }
  }

  /// One-line recommendation shown under the label.
  String get description {
    switch (this) {
      case AppThemeId.darkCyan:
        return '深底 + 青色高亮（经典默认）';
      case AppThemeId.darkSlate:
        return '商务深灰 + 蓝紫高亮';
      case AppThemeId.darkAmber:
        return '驾驶舱琥珀色，长时间夜飞不刺眼';
      case AppThemeId.darkForest:
        return '墨绿森林 + 金黄日光';
      case AppThemeId.darkOcean:
        return '深海蓝紫 + 青绿珊瑚色';
      case AppThemeId.lightSky:
        return '阳光下高对比，白天飞行首选';
      case AppThemeId.lightSand:
        return '暖色米底，长时间使用不疲劳';
      case AppThemeId.lightMint:
        return '清新薄荷绿，视觉舒适';
      case AppThemeId.lightPaper:
        return '航图纸张风格，怀旧 VFR';
      case AppThemeId.lightLavender:
        return '淡薰衣草 + 深紫，柔和不刺眼';
      case AppThemeId.darkContrast:
        return '纯黑 + 高饱和黄（WCAG AAA）';
      case AppThemeId.lightContrast:
        return '纯白 + 纯黑 + 深蓝（WCAG AAA）';
    }
  }

  /// Which group the preset belongs to in the picker UI.
  AppThemeGroup get group {
    switch (this) {
      case AppThemeId.darkCyan:
      case AppThemeId.darkSlate:
      case AppThemeId.darkAmber:
      case AppThemeId.darkForest:
      case AppThemeId.darkOcean:
        return AppThemeGroup.dark;
      case AppThemeId.lightSky:
      case AppThemeId.lightSand:
      case AppThemeId.lightMint:
      case AppThemeId.lightPaper:
      case AppThemeId.lightLavender:
        return AppThemeGroup.light;
      case AppThemeId.darkContrast:
      case AppThemeId.lightContrast:
        return AppThemeGroup.highContrast;
    }
  }

  /// Resolves a persisted [storageKey] back to a preset, falling back to the
  /// default when the value is missing / unknown (e.g. after a rename).
  static AppThemeId fromKey(String? key) {
    if (key == null) return AppThemeId.darkCyan;
    for (final id in AppThemeId.values) {
      if (id.storageKey == key) return id;
    }
    return AppThemeId.darkCyan;
  }
}

/// Grouping used purely by the theme picker UI.
enum AppThemeGroup { dark, light, highContrast }

/// Returns the full [ThemeData] for [id]. Cheap enough to call on every app
/// rebuild — the underlying [ColorScheme] instances are `const`, and
/// `ThemeData` just fans them out.
ThemeData themeDataFor(AppThemeId id) {
  final scheme = _schemeFor(id);
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    // Match backgrounds so system chrome / scaffolds pick up the palette.
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    // Bottom sheets across the app use `showModalBottomSheet(...)` without
    // an explicit `backgroundColor`, so their `Material` background resolves
    // to `bottomSheetTheme.modalBackgroundColor` at build time. Routing that
    // through the current theme's `surfaceContainerHigh` keeps every sheet
    // (Preferences, Theme picker, Bluetooth, Vario, control settings, …)
    // in sync when the user switches themes at runtime — call sites that
    // captured `Theme.of(context)` at open time would otherwise freeze on
    // the old palette.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      modalBackgroundColor: scheme.surfaceContainerHigh,
    ),
  );
}

/// Builds the raw M3 [ColorScheme] for a preset. Kept private so callers use
/// [themeDataFor] and don't accidentally rely on stray fields we don't own.
ColorScheme _schemeFor(AppThemeId id) {
  switch (id) {
    case AppThemeId.darkCyan:
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF00DAF3),
        onPrimary: Color(0xFF001F24),
        primaryContainer: Color(0xFF00626E),
        onPrimaryContainer: Color(0xFFC3F5FF),
        secondary: Color(0xFF00E639),
        onSecondary: Color(0xFF002203),
        secondaryContainer: Color(0xFF00530E),
        onSecondaryContainer: Color(0xFFECFFE3),
        tertiary: Color(0xFFFFB77D),
        onTertiary: Color(0xFF4D2600),
        tertiaryContainer: Color(0xFF894800),
        onTertiaryContainer: Color(0xFFFFE9DA),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: Color(0xFF111318),
        onSurface: Color(0xFFE2E2E8),
        onSurfaceVariant: Color(0xFFBAC9CC),
        outline: Color(0xFF849396),
        outlineVariant: Color(0xFF3B494C),
        surfaceContainerLowest: Color(0xFF0C0E12),
        surfaceContainerLow: Color(0xFF1A1C20),
        surfaceContainer: Color(0xFF1E2024),
        surfaceContainerHigh: Color(0xFF282A2E),
        surfaceContainerHighest: Color(0xFF333539),
      );
    case AppThemeId.darkSlate:
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF8B97FF),
        onPrimary: Color(0xFF050926),
        primaryContainer: Color(0xFF2A3590),
        onPrimaryContainer: Color(0xFFD6DCFF),
        secondary: Color(0xFF00C46A),
        onSecondary: Color(0xFF001D0E),
        secondaryContainer: Color(0xFF004621),
        onSecondaryContainer: Color(0xFFD6FFE9),
        tertiary: Color(0xFFFFA972),
        onTertiary: Color(0xFF422100),
        tertiaryContainer: Color(0xFF7A3D00),
        onTertiaryContainer: Color(0xFFFFE5D6),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF8C0009),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: Color(0xFF14171C),
        onSurface: Color(0xFFE5E6EB),
        onSurfaceVariant: Color(0xFFB6BCC8),
        outline: Color(0xFF7E8694),
        outlineVariant: Color(0xFF3C424B),
        surfaceContainerLowest: Color(0xFF0B0D11),
        surfaceContainerLow: Color(0xFF1C1F25),
        surfaceContainer: Color(0xFF20242A),
        surfaceContainerHigh: Color(0xFF2A2E35),
        surfaceContainerHighest: Color(0xFF353A42),
      );
    case AppThemeId.darkAmber:
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFB300),
        onPrimary: Color(0xFF1F1400),
        primaryContainer: Color(0xFF6B4800),
        onPrimaryContainer: Color(0xFFFFE082),
        secondary: Color(0xFFFFB74D),
        onSecondary: Color(0xFF1F0F00),
        secondaryContainer: Color(0xFF7A3D00),
        onSecondaryContainer: Color(0xFFFFE0B2),
        tertiary: Color(0xFFFFAB40),
        onTertiary: Color(0xFF3D1F00),
        tertiaryContainer: Color(0xFF7A3D00),
        onTertiaryContainer: Color(0xFFFFD180),
        error: Color(0xFFFF6B6B),
        onError: Color(0xFF1F0000),
        errorContainer: Color(0xFF8C0009),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: Color(0xFF0A0905),
        onSurface: Color(0xFFEDE3CD),
        onSurfaceVariant: Color(0xFFC8B98F),
        outline: Color(0xFF8C7E5A),
        outlineVariant: Color(0xFF453E2A),
        surfaceContainerLowest: Color(0xFF050402),
        surfaceContainerLow: Color(0xFF15120C),
        surfaceContainer: Color(0xFF1B1810),
        surfaceContainerHigh: Color(0xFF272318),
        surfaceContainerHighest: Color(0xFF332E20),
      );
    case AppThemeId.darkForest:
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFCA28),
        onPrimary: Color(0xFF1F1600),
        primaryContainer: Color(0xFF6B5000),
        onPrimaryContainer: Color(0xFFFFE082),
        secondary: Color(0xFF4FCB6A),
        onSecondary: Color(0xFF001A06),
        secondaryContainer: Color(0xFF003F17),
        onSecondaryContainer: Color(0xFFD7FFD9),
        tertiary: Color(0xFFE89D52),
        onTertiary: Color(0xFF3D2300),
        tertiaryContainer: Color(0xFF704000),
        onTertiaryContainer: Color(0xFFFFDDB5),
        error: Color(0xFFFFAFA0),
        onError: Color(0xFF5C0700),
        errorContainer: Color(0xFF8A1A0E),
        onErrorContainer: Color(0xFFFFDAD3),
        surface: Color(0xFF0E1812),
        onSurface: Color(0xFFDEE8DC),
        onSurfaceVariant: Color(0xFFB0C4B0),
        outline: Color(0xFF7E947F),
        outlineVariant: Color(0xFF38473A),
        surfaceContainerLowest: Color(0xFF070D0A),
        surfaceContainerLow: Color(0xFF182219),
        surfaceContainer: Color(0xFF1C281E),
        surfaceContainerHigh: Color(0xFF263428),
        surfaceContainerHighest: Color(0xFF324036),
      );
    case AppThemeId.darkOcean:
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF2BE0C4),
        onPrimary: Color(0xFF001F1A),
        primaryContainer: Color(0xFF00665A),
        onPrimaryContainer: Color(0xFF98F0E0),
        secondary: Color(0xFF22C5DC),
        onSecondary: Color(0xFF001E27),
        secondaryContainer: Color(0xFF006980),
        onSecondaryContainer: Color(0xFFD3F4FF),
        tertiary: Color(0xFFFF9966),
        onTertiary: Color(0xFF3D1A00),
        tertiaryContainer: Color(0xFF7A3500),
        onTertiaryContainer: Color(0xFFFFD9B8),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: Color(0xFF0A1220),
        onSurface: Color(0xFFDDE6F2),
        onSurfaceVariant: Color(0xFFAEBED5),
        outline: Color(0xFF7B8AA0),
        outlineVariant: Color(0xFF364258),
        surfaceContainerLowest: Color(0xFF050913),
        surfaceContainerLow: Color(0xFF131C2D),
        surfaceContainer: Color(0xFF182236),
        surfaceContainerHigh: Color(0xFF222D42),
        surfaceContainerHighest: Color(0xFF2D384E),
      );
    case AppThemeId.lightSky:
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF0066CC),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFCCE3FF),
        onPrimaryContainer: Color(0xFF002647),
        secondary: Color(0xFF1AAE52),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFA6E8B8),
        onSecondaryContainer: Color(0xFF002710),
        tertiary: Color(0xFFE67A19),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFD0A0),
        onTertiaryContainer: Color(0xFF3D1F00),
        error: Color(0xFFD32F2F),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: Color(0xFFF5F7FA),
        onSurface: Color(0xFF15181D),
        onSurfaceVariant: Color(0xFF455160),
        outline: Color(0xFF6B7585),
        outlineVariant: Color(0xFFC2CAD5),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFEFF2F7),
        surfaceContainer: Color(0xFFE9EDF3),
        surfaceContainerHigh: Color(0xFFDFE4EB),
        surfaceContainerHighest: Color(0xFFD5DBE3),
      );
    case AppThemeId.lightSand:
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFFC75A0E),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFD9B8),
        onPrimaryContainer: Color(0xFF411E00),
        secondary: Color(0xFF2E7D43),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFF99CFA8),
        onSecondaryContainer: Color(0xFF002612),
        tertiary: Color(0xFFB87D1F),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFD9A0),
        onTertiaryContainer: Color(0xFF3D2300),
        error: Color(0xFFC62828),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: Color(0xFFFAF6EE),
        onSurface: Color(0xFF1A1814),
        onSurfaceVariant: Color(0xFF514B3C),
        outline: Color(0xFF7A7160),
        outlineVariant: Color(0xFFC9BFA8),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF5EFE0),
        surfaceContainer: Color(0xFFEFE8D5),
        surfaceContainerHigh: Color(0xFFE5DCC4),
        surfaceContainerHighest: Color(0xFFDCD2B8),
      );
    case AppThemeId.lightMint:
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF00838F),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFB2EBF2),
        onPrimaryContainer: Color(0xFF002025),
        secondary: Color(0xFF00875A),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFF87DDB1),
        onSecondaryContainer: Color(0xFF002115),
        tertiary: Color(0xFFE65100),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFCC80),
        onTertiaryContainer: Color(0xFF3D1F00),
        error: Color(0xFFD32F2F),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: Color(0xFFF0F7F4),
        onSurface: Color(0xFF131A17),
        onSurfaceVariant: Color(0xFF40524C),
        outline: Color(0xFF67786F),
        outlineVariant: Color(0xFFB9CCC3),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFE9F2EE),
        surfaceContainer: Color(0xFFE2EDE8),
        surfaceContainerHigh: Color(0xFFD3E0DA),
        surfaceContainerHighest: Color(0xFFC4D3CC),
      );
    case AppThemeId.lightPaper:
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF8B4513),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFD0A0),
        onPrimaryContainer: Color(0xFF2E1300),
        secondary: Color(0xFF388E3C),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFA5D6A7),
        onSecondaryContainer: Color(0xFF002510),
        tertiary: Color(0xFFE65100),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFCC80),
        onTertiaryContainer: Color(0xFF3D1F00),
        error: Color(0xFFB71C1C),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFCDD2),
        onErrorContainer: Color(0xFF410002),
        surface: Color(0xFFFBF7F0),
        onSurface: Color(0xFF1E1A12),
        onSurfaceVariant: Color(0xFF534A3B),
        outline: Color(0xFF7F7460),
        outlineVariant: Color(0xFFCABEA5),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF6F0E2),
        surfaceContainer: Color(0xFFF0E9D5),
        surfaceContainerHigh: Color(0xFFE7DDC4),
        surfaceContainerHighest: Color(0xFFDCD0B0),
      );
    case AppThemeId.lightLavender:
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF6A1B9A),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE1BEE7),
        onPrimaryContainer: Color(0xFF2A0040),
        secondary: Color(0xFF43A047),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFA5D6A7),
        onSecondaryContainer: Color(0xFF002A0E),
        tertiary: Color(0xFFD81B60),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFF8BBD0),
        onTertiaryContainer: Color(0xFFFFFFFF),
        error: Color(0xFFC62828),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: Color(0xFFF7F3FB),
        onSurface: Color(0xFF1A171C),
        onSurfaceVariant: Color(0xFF4D4458),
        outline: Color(0xFF786B86),
        outlineVariant: Color(0xFFC6B9D2),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFEFE9F5),
        surfaceContainer: Color(0xFFE9E1EF),
        surfaceContainerHigh: Color(0xFFDDD2E7),
        surfaceContainerHighest: Color(0xFFD0C4DB),
      );
    case AppThemeId.darkContrast:
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFEB3B),
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xFFFFD600),
        onPrimaryContainer: Color(0xFF000000),
        secondary: Color(0xFF00FF7F),
        onSecondary: Color(0xFF000000),
        secondaryContainer: Color(0xFF00E676),
        onSecondaryContainer: Color(0xFF000000),
        tertiary: Color(0xFFFF9100),
        onTertiary: Color(0xFF000000),
        tertiaryContainer: Color(0xFFFF6D00),
        onTertiaryContainer: Color(0xFF000000),
        error: Color(0xFFFF5252),
        onError: Color(0xFF000000),
        errorContainer: Color(0xFFD50000),
        onErrorContainer: Color(0xFFFFFFFF),
        surface: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFE0E0E0),
        outline: Color(0xFFFFFFFF),
        outlineVariant: Color(0xFF707070),
        surfaceContainerLowest: Color(0xFF000000),
        surfaceContainerLow: Color(0xFF0A0A0A),
        surfaceContainer: Color(0xFF141414),
        surfaceContainerHigh: Color(0xFF1F1F1F),
        surfaceContainerHighest: Color(0xFF2A2A2A),
      );
    case AppThemeId.lightContrast:
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF0033A0),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFB3CCFF),
        onPrimaryContainer: Color(0xFF000000),
        secondary: Color(0xFF008A00),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFF85E085),
        onSecondaryContainer: Color(0xFF000000),
        tertiary: Color(0xFFCC5500),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFB870),
        onTertiaryContainer: Color(0xFFFFFFFF),
        error: Color(0xFFB00020),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFCDD2),
        onErrorContainer: Color(0xFF000000),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF000000),
        onSurfaceVariant: Color(0xFF1A1A1A),
        outline: Color(0xFF000000),
        outlineVariant: Color(0xFF707070),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF5F5F5),
        surfaceContainer: Color(0xFFEEEEEE),
        surfaceContainerHigh: Color(0xFFE0E0E0),
        surfaceContainerHighest: Color(0xFFD0D0D0),
      );
  }
}
