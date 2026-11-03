import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Decodes QR codes from still images (picture files), working on every
/// platform (pure Dart via `image` + `zxing2`). Used both for "scan from a
/// picture file" and as the desktop fallback where no live camera is wired up.
abstract final class QrImageDecoder {
  /// Decodes the first QR code found in [bytes]. Returns the decoded text, or
  /// null when no QR code is present or the image cannot be read.
  static Future<String?> decodeBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      return await Future(() => _decodeSync(bytes));
    } catch (_) {
      return null;
    }
  }

  static String? _decodeSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // Downscale very large photos to keep the binarizer fast and memory-safe.
    var image = decoded;
    const maxDimension = 2000;
    if (image.width > maxDimension || image.height > maxDimension) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? maxDimension : null,
        height: image.height > image.width ? maxDimension : null,
      );
    }

    final width = image.width;
    final height = image.height;
    final pixels = Int32List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        pixels[y * width + x] = (0xff << 24) | (r << 16) | (g << 8) | b;
      }
    }

    final source = RGBLuminanceSource(width, height, pixels);
    final reader = QRCodeReader();

    // Try a plain decode first, then a harder, TRY_HARDER pass.
    for (final tryHarder in [false, true]) {
      try {
        final bitmap = BinaryBitmap(HybridBinarizer(source));
        final hints = DecodeHints();
        if (tryHarder) hints.put(DecodeHintType.tryHarder);
        final result = reader.decode(bitmap, hints: hints);
        final text = result.text.trim();
        if (text.isNotEmpty) return text;
      } catch (_) {
        // Try the next strategy.
      }
    }
    return null;
  }
}
