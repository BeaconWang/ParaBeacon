/// Google Encoded Polyline codec as used by XCTrack's competition-task compact
/// (version 2) QR format (`org.xcontest.XCTrack.util.y`).
///
/// Unlike the map-track variant, every integer is encoded from its **absolute**
/// value (no cumulative delta), using the standard zig-zag + 5-bit varint over
/// ASCII 63..126.
abstract final class TaskPolyline {
  /// Encodes a flat list of integers to a polyline string.
  static String encode(List<int> values) {
    final buffer = StringBuffer();
    for (final v in values) {
      var x = v << 1; // zig-zag
      if (v < 0) x = ~x;
      if (x == 0) {
        buffer.writeCharCode(63);
        continue;
      }
      while (x > 0x1f) {
        buffer.writeCharCode(((x & 0x1f) | 0x20) + 63);
        x >>= 5;
      }
      buffer.writeCharCode(x + 63);
    }
    return buffer.toString();
  }

  /// Decodes a polyline string back to the flat list of integers. Returns an
  /// empty list on malformed input.
  static List<int> decode(String encoded) {
    final result = <int>[];
    var value = 0;
    var shift = 0;
    for (final code in encoded.codeUnits) {
      final b = code - 63;
      if (b < 0 || b > 0x3f) {
        // Not a valid polyline character.
        return const [];
      }
      value |= (b & 0x1f) << shift;
      shift += 5;
      if (b <= 0x1f) {
        final negative = (value & 1) == 1;
        var n = value >> 1;
        if (negative) n = ~n;
        result.add(n);
        value = 0;
        shift = 0;
      }
    }
    // A trailing partial group (shift != 0) means a truncated string.
    if (shift != 0) return const [];
    return result;
  }
}
