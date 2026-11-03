import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'competition_task.dart';

/// File import/export for XCTrack-compatible `.xctsk` competition tasks.
class CompetitionTaskIO {
  CompetitionTaskIO._();

  static final CompetitionTaskIO instance = CompetitionTaskIO._();

  static const String extension = 'xctsk';
  static const int maxFileBytes = 512 * 1024;

  /// Parses an `.xctsk` file (or an `XCTSK:` task-code text file) from bytes.
  CompetitionTask? parseBytes(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) return null;
    try {
      return CompetitionTask.tryParse(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  Future<CompetitionTask?> importFile(String path) async {
    final file = File(path);
    final length = await file.length();
    if (length <= 0 || length > maxFileBytes) return null;
    return parseBytes(await file.readAsBytes());
  }

  /// Writes the task to a temporary `.xctsk` file and opens the share sheet.
  Future<bool> exportAndShare(CompetitionTask task) async {
    final bytes = utf8.encode('${task.toXctskString()}\n');
    if (bytes.length > maxFileBytes) return false;

    final safeName = _fileSafe(task.name);
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    final fileName = safeName.isEmpty
        ? 'task_$stamp.$extension'
        : '${safeName}_$stamp.$extension';

    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(file.path, name: fileName, mimeType: 'application/xctsk+json'),
    ], subject: 'ParaBeacon competition task');
    return true;
  }

  String _fileSafe(String raw) {
    final cleaned = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }
}
