/// A minimum/maximum number of fractional digits for one displayed value.
class DecimalPlaceRange {
  final int min;
  final int max;

  const DecimalPlaceRange(this.min, this.max);

  static const maxSupportedPlaces = 8;

  static DecimalPlaceRange? parse(Object? value) {
    if (value is! String || value == 'auto') return null;
    final match = RegExp(r'^(\d{1,2})-(\d{1,2})$').firstMatch(value);
    if (match == null) return null;
    final min = int.parse(match.group(1)!);
    final max = int.parse(match.group(2)!);
    if (min > max || max > maxSupportedPlaces) return null;
    return DecimalPlaceRange(min, max);
  }

  String encode() => '$min-$max';

  @override
  bool operator ==(Object other) =>
      other is DecimalPlaceRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// Formats [value] with the default precision unless [range] overrides it.
/// Configured ranges show up to [DecimalPlaceRange.max] digits and trim trailing
/// zeroes without going below [DecimalPlaceRange.min].
String formatDecimalValue(
  double value, {
  required int autoDecimals,
  DecimalPlaceRange? range,
}) {
  if (!value.isFinite) return value.toString();
  final decimals =
      range?.max ??
      autoDecimals.clamp(0, DecimalPlaceRange.maxSupportedPlaces).toInt();
  var formatted = value.toStringAsFixed(decimals);
  if (range == null) return formatted;
  final dot = formatted.indexOf('.');
  if (dot < 0) return formatted;
  while (formatted.length > dot + 1 + range.min && formatted.endsWith('0')) {
    formatted = formatted.substring(0, formatted.length - 1);
  }
  if (formatted.endsWith('.')) {
    formatted = formatted.substring(0, formatted.length - 1);
  }
  return formatted;
}
