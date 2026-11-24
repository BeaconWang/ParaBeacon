import 'package:flutter/material.dart';

import '../data/profile_image_url.dart';
import 'app_notice.dart';

Future<void> showProfileImagePreview(
  BuildContext context, {
  required String imageUrl,
  required String title,
  required String closeLabel,
  required String changeLabel,
  required String resetLabel,
  required String downloadLabel,
  required String downloadingLabel,
  required String downloadSuccessLabel,
  required String downloadFailedLabel,
  required Future<void> Function() onChange,
  required Future<void> Function() onReset,
  required Future<bool> Function() onDownload,
}) {
  final imageUri = ProfileImageUrl.resolve(imageUrl);
  if (imageUri == null) return Future<void>.value();
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => _ProfileImagePreviewPage(
        imageUrl: imageUri.toString(),
        title: title,
        closeLabel: closeLabel,
        changeLabel: changeLabel,
        resetLabel: resetLabel,
        downloadLabel: downloadLabel,
        downloadingLabel: downloadingLabel,
        downloadSuccessLabel: downloadSuccessLabel,
        downloadFailedLabel: downloadFailedLabel,
        onChange: onChange,
        onReset: onReset,
        onDownload: onDownload,
      ),
    ),
  );
}

class _ProfileImagePreviewPage extends StatefulWidget {
  const _ProfileImagePreviewPage({
    required this.imageUrl,
    required this.title,
    required this.closeLabel,
    required this.changeLabel,
    required this.resetLabel,
    required this.downloadLabel,
    required this.downloadingLabel,
    required this.downloadSuccessLabel,
    required this.downloadFailedLabel,
    required this.onChange,
    required this.onReset,
    required this.onDownload,
  });

  final String imageUrl;
  final String title;
  final String closeLabel;
  final String changeLabel;
  final String resetLabel;
  final String downloadLabel;
  final String downloadingLabel;
  final String downloadSuccessLabel;
  final String downloadFailedLabel;
  final Future<void> Function() onChange;
  final Future<void> Function() onReset;
  final Future<bool> Function() onDownload;

  @override
  State<_ProfileImagePreviewPage> createState() =>
      _ProfileImagePreviewPageState();
}

class _ProfileImagePreviewPageState extends State<_ProfileImagePreviewPage> {
  bool _downloading = false;
  bool _editing = false;

  Future<void> _runProfileAction(Future<void> Function() action) async {
    if (_editing || _downloading) return;
    setState(() => _editing = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _downloadImage() async {
    if (_downloading || _editing) return;
    setState(() => _downloading = true);
    var succeeded = false;
    try {
      succeeded = await widget.onDownload();
    } on Object {
      succeeded = false;
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
    if (mounted) {
      AppNotice.show(
        succeeded ? widget.downloadSuccessLabel : widget.downloadFailedLabel,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(widget.title),
      leading: IconButton(
        tooltip: widget.closeLabel,
        onPressed: _editing ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Image.network(
          widget.imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white70,
            size: 64,
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _editing || _downloading
                    ? null
                    : () => _runProfileAction(widget.onChange),
                icon: const Icon(Icons.edit_outlined),
                label: Text(widget.changeLabel),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _editing || _downloading
                    ? null
                    : () => _runProfileAction(widget.onReset),
                icon: const Icon(Icons.restart_alt),
                label: Text(widget.resetLabel),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _editing || _downloading ? null : _downloadImage,
                icon: _downloading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(
                  _downloading ? widget.downloadingLabel : widget.downloadLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
