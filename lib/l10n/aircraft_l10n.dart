import 'app_localizations.dart';

String aircraftFaiClassLabel(AppLocalizations l10n, String value) {
  switch (value) {
    case '1':
      return l10n.aircraftFaiHangGlider;
    case '2':
      return l10n.aircraftFaiRigidWingFai2;
    case '3':
      return l10n.aircraftFaiParaglider;
    case '5':
      return l10n.aircraftFaiRigidWing;
    case '11':
      return l10n.aircraftFaiPoweredParagliderFoot;
    case '12':
      return l10n.aircraftFaiPoweredParagliderTrike;
    case '13':
      return l10n.aircraftFaiPoweredAircraft;
    case '14':
      return l10n.aircraftFaiRigidWingPowered;
    case '15':
      return l10n.aircraftFaiRigidWingFootLaunched;
    case '16':
      return l10n.aircraftFaiRigidGlider;
    default:
      return value;
  }
}
