import '../l10n/app_localizations.dart';

/// Converts a relative bearing into an 8-point position label.
///
/// The input uses compass bearings: 0° is ahead, increasing clockwise.
String relativeBearingPositionLabel(AppLocalizations l10n, double degrees) {
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized + 22.5) ~/ 45) % 8;
  return switch (index) {
    0 => l10n.landingRelativeAhead,
    1 => l10n.landingRelativeRightFront,
    2 => l10n.landingRelativeRight,
    3 => l10n.landingRelativeRightBack,
    4 => l10n.landingRelativeBehind,
    5 => l10n.landingRelativeLeftBack,
    6 => l10n.landingRelativeLeft,
    _ => l10n.landingRelativeLeftFront,
  };
}
