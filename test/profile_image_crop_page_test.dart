import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:parabeacon/controls/profile_image_crop_page.dart';

void main() {
  test('crop rectangle follows drag and zoom transforms', () {
    final centered = ProfileImageCropMath.sourceRect(
      imageWidth: 400,
      imageHeight: 200,
      frameSide: 100,
      zoom: 1,
      offset: Offset.zero,
    );
    expect(centered.left, closeTo(100, 1e-10));
    expect(centered.top, closeTo(0, 1e-10));
    expect(centered.width, closeTo(200, 1e-10));
    expect(centered.height, closeTo(200, 1e-10));

    final dragged = ProfileImageCropMath.sourceRect(
      imageWidth: 400,
      imageHeight: 200,
      frameSide: 100,
      zoom: 1,
      offset: const Offset(25, 0),
    );
    expect(dragged.left, closeTo(50, 1e-10));

    final zoomed = ProfileImageCropMath.sourceRect(
      imageWidth: 400,
      imageHeight: 200,
      frameSide: 100,
      zoom: 2,
      offset: Offset.zero,
    );
    expect(zoomed.left, closeTo(150, 1e-10));
    expect(zoomed.width, closeTo(100, 1e-10));
  });

  test('crops the selected square region to an upload-ready image', () {
    final source = img.Image(width: 400, height: 200);
    final sourceRect = ProfileImageCropMath.sourceRect(
      imageWidth: source.width,
      imageHeight: source.height,
      frameSide: 100,
      zoom: 1.5,
      offset: const Offset(18, -6),
    );

    final croppedBytes = ProfileImageCropMath.cropImage(source, sourceRect);
    final cropped = img.decodeImage(croppedBytes);
    expect(cropped?.width, 512);
    expect(cropped?.height, 512);
    expect(croppedBytes.length, lessThan(8 * 1024 * 1024));
  });
}
