import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ProfileImageCropPage extends StatefulWidget {
  const ProfileImageCropPage({
    required this.imageBytes,
    required this.title,
    required this.instructions,
    required this.cropAction,
    required this.cancelLabel,
    required this.invalidImageMessage,
    super.key,
  });

  final Uint8List imageBytes;
  final String title;
  final String instructions;
  final String cropAction;
  final String cancelLabel;
  final String invalidImageMessage;

  static Future<Uint8List?> edit(
    BuildContext context, {
    required Uint8List imageBytes,
    required String title,
    required String instructions,
    required String cropAction,
    required String cancelLabel,
    required String invalidImageMessage,
  }) => Navigator.of(context).push<Uint8List>(
    MaterialPageRoute<Uint8List>(
      builder: (_) => ProfileImageCropPage(
        imageBytes: imageBytes,
        title: title,
        instructions: instructions,
        cropAction: cropAction,
        cancelLabel: cancelLabel,
        invalidImageMessage: invalidImageMessage,
      ),
    ),
  );

  @override
  State<ProfileImageCropPage> createState() => _ProfileImageCropPageState();
}

class _ProfileImageCropPageState extends State<ProfileImageCropPage> {
  static const double _maximumZoom = 6;
  static const double _maximumFrameSide = 512;

  final GlobalKey _frameKey = GlobalKey();
  late final Future<Map<String, Object>?> _preparedImage;
  double _zoom = 1;
  double _gestureStartZoom = 1;
  Offset _offset = Offset.zero;
  bool _imageReady = false;
  bool _imageLoading = true;
  Offset _gestureStartImageFocal = Offset.zero;
  bool _cropping = false;
  String? _cropError;

  @override
  void initState() {
    super.initState();
    _preparedImage = compute(_prepareProfileImage, widget.imageBytes);
    _preparedImage.then((prepared) {
      if (mounted) {
        setState(() {
          _imageReady = prepared != null;
          _imageLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<Map<String, Object>?>(
                future: _preparedImage,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final prepared = snapshot.data;
                  if (prepared == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.invalidImageMessage,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final imageWidth = prepared['width']! as int;
                  final imageHeight = prepared['height']! as int;
                  final previewBytes = prepared['preview']! as Uint8List;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final side = math.min(
                        _maximumFrameSide,
                        math.min(constraints.maxWidth, constraints.maxHeight),
                      );
                      return Center(
                        child: SizedBox.square(
                          key: _frameKey,
                          dimension: side,
                          child: _buildCropFrame(
                            side: side,
                            imageWidth: imageWidth,
                            imageHeight: imageHeight,
                            previewBytes: previewBytes,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                widget.instructions,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_cropError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _cropError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cropping
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(widget.cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _cropping || !_imageReady
                            ? null
                            : _cropAndReturn,
                        icon: _cropping || _imageLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.crop),
                        label: Text(widget.cropAction),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropFrame({
    required double side,
    required int imageWidth,
    required int imageHeight,
    required Uint8List previewBytes,
  }) {
    final baseScale = math.max(side / imageWidth, side / imageHeight);
    final displayedWidth = imageWidth * baseScale;
    final displayedHeight = imageHeight * baseScale;
    return ClipRect(
      child: GestureDetector(
        key: const ValueKey('profile-image-crop-gesture'),
        behavior: HitTestBehavior.opaque,
        onScaleStart: (details) {
          _gestureStartZoom = _zoom;
          final focal = details.localFocalPoint - Offset(side / 2, side / 2);
          _gestureStartImageFocal = (focal - _offset) / _zoom;
        },
        onScaleUpdate: (details) {
          final zoom = (_gestureStartZoom * details.scale)
              .clamp(1.0, _maximumZoom)
              .toDouble();
          final focal = details.localFocalPoint - Offset(side / 2, side / 2);
          final offset = focal - _gestureStartImageFocal * zoom;
          setState(() {
            _zoom = zoom;
            _offset = _clampOffset(
              offset,
              side: side,
              imageWidth: imageWidth,
              imageHeight: imageHeight,
              baseScale: baseScale,
              zoom: zoom,
            );
          });
        },
        onDoubleTap: () => setState(() {
          _zoom = 1;
          _offset = Offset.zero;
        }),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            Center(
              child: Transform.translate(
                offset: _offset,
                child: Transform.scale(
                  scale: _zoom,
                  child: Image.memory(
                    previewBytes,
                    width: displayedWidth,
                    height: displayedHeight,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _SquareCropFramePainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset _clampOffset(
    Offset offset, {
    required double side,
    required int imageWidth,
    required int imageHeight,
    required double baseScale,
    required double zoom,
  }) {
    final horizontalLimit = math
        .max(0, (imageWidth * baseScale * zoom - side) / 2)
        .toDouble();
    final verticalLimit = math
        .max(0, (imageHeight * baseScale * zoom - side) / 2)
        .toDouble();
    return Offset(
      offset.dx.clamp(-horizontalLimit, horizontalLimit).toDouble(),
      offset.dy.clamp(-verticalLimit, verticalLimit).toDouble(),
    );
  }

  Future<void> _cropAndReturn() async {
    if (_cropping) return;
    final frame = _frameKey.currentContext?.findRenderObject();
    final imageSize = await _preparedImage;
    if (!mounted || imageSize == null || frame is! RenderBox) return;
    final frameSide = frame.size.shortestSide;
    if (frameSide <= 0) return;

    final imageWidth = imageSize['width']! as int;
    final imageHeight = imageSize['height']! as int;
    final cropRect = ProfileImageCropMath.sourceRect(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      frameSide: frameSide,
      zoom: _zoom,
      offset: _offset,
    );
    setState(() {
      _cropping = true;
      _cropError = null;
    });
    try {
      final croppedBytes = await compute(_cropProfileImageBytes, {
        'bytes': widget.imageBytes,
        'left': cropRect.left,
        'top': cropRect.top,
        'size': cropRect.width,
      });
      if (mounted) Navigator.of(context).pop(croppedBytes);
    } on Object {
      if (mounted) {
        setState(() {
          _cropping = false;
          _cropError = widget.invalidImageMessage;
        });
      }
    }
  }
}

abstract final class ProfileImageCropMath {
  static Rect sourceRect({
    required int imageWidth,
    required int imageHeight,
    required double frameSide,
    required double zoom,
    required Offset offset,
  }) {
    final baseScale = math.max(frameSide / imageWidth, frameSide / imageHeight);
    final scale = baseScale * zoom;
    final sourceSide = frameSide / scale;
    final left = ((imageWidth - sourceSide) / 2 - offset.dx / scale)
        .clamp(0.0, imageWidth - sourceSide)
        .toDouble();
    final top = ((imageHeight - sourceSide) / 2 - offset.dy / scale)
        .clamp(0.0, imageHeight - sourceSide)
        .toDouble();
    return Rect.fromLTWH(left, top, sourceSide, sourceSide);
  }

  static Uint8List cropImage(img.Image source, Rect cropRect) {
    final requestedSize = cropRect.width.round();
    final size = requestedSize
        .clamp(1, math.min(source.width, source.height))
        .toInt();
    final left = cropRect.left.round().clamp(0, source.width - size).toInt();
    final top = cropRect.top.round().clamp(0, source.height - size).toInt();
    final square = img.copyCrop(
      source,
      x: left,
      y: top,
      width: size,
      height: size,
    );
    final resized = img.copyResize(square, width: 512, height: 512);
    return Uint8List.fromList(img.encodePng(resized));
  }
}

Map<String, Object>? _prepareProfileImage(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final oriented = img.bakeOrientation(decoded);
    if (oriented.width <= 0 ||
        oriented.height <= 0 ||
        oriented.width > 4096 ||
        oriented.height > 4096 ||
        oriented.width * oriented.height > 12000000) {
      return null;
    }
    final ratio = math.min(
      1.0,
      1024 / math.max(oriented.width, oriented.height),
    );
    final preview = img.copyResize(
      oriented,
      width: math.max(1, (oriented.width * ratio).round()),
      height: math.max(1, (oriented.height * ratio).round()),
    );
    return {
      'width': oriented.width,
      'height': oriented.height,
      'preview': Uint8List.fromList(img.encodePng(preview)),
    };
  } on Object {
    return null;
  }
}

Uint8List _cropProfileImageBytes(Map<String, Object> values) {
  final bytes = values['bytes']! as Uint8List;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Invalid image');
  final source = img.bakeOrientation(decoded);
  return ProfileImageCropMath.cropImage(
    source,
    Rect.fromLTWH(
      values['left']! as double,
      values['top']! as double,
      values['size']! as double,
      values['size']! as double,
    ),
  );
}

class _SquareCropFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, border);
    for (var division = 1; division < 3; division++) {
      final position = size.width * division / 3;
      canvas.drawLine(Offset(position, 0), Offset(position, size.height), grid);
      canvas.drawLine(Offset(0, position), Offset(size.width, position), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
