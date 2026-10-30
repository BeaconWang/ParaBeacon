/// The `gliderCat` string of `POST /api/flight`.
///
/// Reversed from `config/t0.smali:10405-10730` (`t0.D()`), which is what
/// `live/c1.smali:3487-3492` passes as `FlightOptions.gliderCat`. It is **not**
/// the certification the UI shows (`EN-A`…`EN-D`): it is XContest's own
/// category id, built from pref `Glider.FAIClass` (t0.K0, default `"3"`).
///
/// The server parses it with attoparsec, so a surprise value is a 400:
/// `Error in $.gliderCat: Failed reading: takeWhile1`.
library;

/// `Glider.FAIClass` -> gliderCat.
///
/// [faiClass] is the raw pref: "3" (paraglider), "1" (hangglider), "5"/"2"
/// (rigid wing), "11"…"16" (powered/rigid). [engineType] is pref
/// `Glider.EngineType` (t0.L0, default `"T"`) and is only appended for the
/// 11-16 classes (`t0.C()` = `parseInt(faiClass) >= 11`, t0.smali:5060-5105).
String gliderCatOf(String faiClass, {String engineType = 'T', bool tandem = false}) {
  const rigid = <String, String>{
    '11': 'RPF',
    '12': 'RPL',
    '13': 'RAL',
    '14': 'RWL',
    '15': 'RWF',
    '16': 'RGL',
  };

  final cat = rigid[faiClass] ?? 'FAI-$faiClass';
  final code = int.tryParse(faiClass) ?? 3; // util/g1.i(3, faiClass)
  if (code < 11) return cat;
  return '$cat${tandem ? '2' : '1'}$engineType';
}

/// Default `Glider.FAIClass` (paraglider) - t0.smali:1096-1100.
const String kDefaultFaiClass = '3';

/// What a fresh XCTrack sends: `Glider.Name` is empty by default
/// (t0.H0, t0.smali:1045-1049).
const String kDefaultGliderName = '';
