/// Integer codecs behind LiveCompressAdapter.
///
///   polylineEncode / polylineDecode -> util/y.f / util/y.c
///   deltaEncode   / deltaDecode     -> LiveCompressAdapter.smali:195-280
library;

import 'trackpoint.dart';

const int _fields = 6;

/// Google polyline: varint + zigzag.
String polylineEncode(Iterable<int> values) {
  final out = StringBuffer();
  for (final value in values) {
    var v = value << 1;
    if (v < 0) {
      v = ~v; // two's complement, same as Java ~
    }
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1F)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }
  return out.toString();
}

List<int> polylineDecode(String text) {
  final out = <int>[];
  var result = 0;
  var shift = 0;
  for (var i = 0; i < text.length; i++) {
    final d = text.codeUnitAt(i) - 63;
    result |= (d & 0x1F) << shift;
    shift += 5;
    if (d < 0x20) {
      out.add((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      result = 0;
      shift = 0;
    }
  }
  return out;
}

/// Each row becomes (row - previous row); the first row stays absolute.
///
/// The APK walks the list backwards (i = size-1 .. 1) and the fields backwards
/// (j = 5 .. 0) so it can mutate in place - arithmetically identical.
List<List<int>> deltaEncode(List<List<int>> rows) {
  final out = rows.map((r) => List<int>.from(r)).toList();
  for (var i = out.length - 1; i > 0; i--) {
    final cur = out[i];
    final prev = out[i - 1];
    for (var j = _fields - 1; j >= 0; j--) {
      cur[j] -= prev[j];
    }
  }
  return out;
}

/// util/y.e - running prefix sum.
List<List<int>> deltaDecode(List<List<int>> rows) {
  final out = <List<int>>[];
  var prev = List<int>.filled(_fields, 0);
  for (final row in rows) {
    final cur = <int>[
      for (var i = 0; i < _fields; i++) row[i] + prev[i],
    ];
    out.add(cur);
    prev = cur;
  }
  return out;
}

/// util/y.n(6, list) - regroup a flat list into 6-tuples.
List<List<int>> chunkRows(List<int> values, int size) => <List<int>>[
      for (var i = 0; i + size <= values.length; i += size)
        values.sublist(i, i + size),
    ];

/// Encodes a track segment into the single string that goes on the wire.
String compressPoints(List<LiveTrackpoint> points) {
  final rows = deltaEncode(points.map((p) => p.toInts()).toList());
  return polylineEncode(rows.expand((r) => r));
}

List<LiveTrackpoint> decompressPoints(String text) {
  final rows = deltaDecode(chunkRows(polylineDecode(text), _fields));
  return rows.map(LiveTrackpoint.fromInts).toList();
}

List<LiveTrackpointHP> decompressPointsHP(String text) {
  final rows = deltaDecode(chunkRows(polylineDecode(text), _fields));
  return rows.map(LiveTrackpointHP.fromInts).toList();
}
