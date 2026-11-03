import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'competition_task.dart';

/// Result of a task download attempt.
class TaskDownloadResult {
  const TaskDownloadResult._(this.task, this.error);

  factory TaskDownloadResult.success(CompetitionTask task) =>
      TaskDownloadResult._(task, null);
  factory TaskDownloadResult.failure(TaskDownloadError error) =>
      TaskDownloadResult._(null, error);

  final CompetitionTask? task;
  final TaskDownloadError? error;

  bool get ok => task != null;
}

enum TaskDownloadError {
  invalidUrl,
  blockedHost,
  network,
  tooLarge,
  notATask,
}

/// Downloads competition tasks from the network.
///
/// Supports three inputs:
///  * a full `http(s)` link to a `.xctsk` file (or any URL returning the task
///    JSON / `XCTSK:` code),
///  * an `xctrack.org/xcplanner` planner link,
///  * a short XContest task code, resolved via
///    `https://tools.xcontest.org/api/xctsk/load/{code}`.
///
/// SSRF hardening (per project security policy): only `http`/`https` is
/// allowed, redirects are followed manually and re-validated, and any host that
/// resolves to a loopback / link-local / private / otherwise internal address
/// is rejected. Internal-network access is denied by default.
abstract final class CompetitionTaskDownloader {
  static const int _maxBytes = 512 * 1024;
  static const int _maxRedirects = 5;
  static const Duration _timeout = Duration(seconds: 20);

  static const String _xcontestLoadBase =
      'https://tools.xcontest.org/api/xctsk/load/';

  /// Resolves [input] (a URL or a short task code) into a task.
  static Future<TaskDownloadResult> download(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return TaskDownloadResult.failure(TaskDownloadError.invalidUrl);
    }

    // A bare short code (no scheme, no dot/slash) → XContest load endpoint.
    final looksLikeUrl =
        trimmed.contains('://') ||
        trimmed.contains('/') ||
        trimmed.contains('.');
    final initialUrl = looksLikeUrl
        ? _normalizeUrl(trimmed)
        : Uri.tryParse('$_xcontestLoadBase${Uri.encodeComponent(trimmed)}');

    if (initialUrl == null) {
      return TaskDownloadResult.failure(TaskDownloadError.invalidUrl);
    }

    return _fetch(initialUrl);
  }

  static Uri? _normalizeUrl(String raw) {
    var text = raw;
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  static Future<TaskDownloadResult> _fetch(Uri start) async {
    final client = HttpClient()
      ..connectionTimeout = _timeout
      ..maxConnectionsPerHost = 2;
    try {
      var url = start;
      for (var redirect = 0; redirect <= _maxRedirects; redirect++) {
        final guard = await _validateUrl(url);
        if (guard != null) return TaskDownloadResult.failure(guard);

        final request = await client.getUrl(url).timeout(_timeout);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, 'application/xctsk, application/json, text/plain');
        final response = await request.close().timeout(_timeout);

        // Manual redirect handling so each hop is re-validated.
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null) {
            return TaskDownloadResult.failure(TaskDownloadError.network);
          }
          final next = url.resolve(location);
          if (next.scheme != 'http' && next.scheme != 'https') {
            return TaskDownloadResult.failure(TaskDownloadError.blockedHost);
          }
          url = next;
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>();
          return TaskDownloadResult.failure(TaskDownloadError.network);
        }

        // Enforce a hard byte cap while streaming.
        final declared = response.contentLength;
        if (declared > _maxBytes) {
          await response.drain<void>();
          return TaskDownloadResult.failure(TaskDownloadError.tooLarge);
        }
        final builder = BytesBuilder(copy: false);
        var total = 0;
        await for (final chunk in response) {
          total += chunk.length;
          if (total > _maxBytes) {
            return TaskDownloadResult.failure(TaskDownloadError.tooLarge);
          }
          builder.add(chunk);
        }

        String text;
        try {
          text = utf8.decode(builder.takeBytes());
        } catch (_) {
          return TaskDownloadResult.failure(TaskDownloadError.notATask);
        }
        final task = CompetitionTask.tryParse(text);
        if (task == null) {
          return TaskDownloadResult.failure(TaskDownloadError.notATask);
        }
        return TaskDownloadResult.success(task);
      }
      return TaskDownloadResult.failure(TaskDownloadError.network);
    } on TimeoutException {
      return TaskDownloadResult.failure(TaskDownloadError.network);
    } on SocketException {
      return TaskDownloadResult.failure(TaskDownloadError.network);
    } catch (_) {
      return TaskDownloadResult.failure(TaskDownloadError.network);
    } finally {
      client.close(force: true);
    }
  }

  /// Returns a blocking error, or null when the URL is allowed.
  static Future<TaskDownloadError?> _validateUrl(Uri url) async {
    if (url.scheme != 'http' && url.scheme != 'https') {
      return TaskDownloadError.blockedHost;
    }
    final host = url.host;
    if (host.isEmpty) return TaskDownloadError.invalidUrl;

    // Resolve the host and reject any internal/reserved address. If resolution
    // fails we treat it as a network error rather than silently allowing it.
    final List<InternetAddress> addresses;
    final literal = InternetAddress.tryParse(host);
    if (literal != null) {
      addresses = [literal];
    } else {
      try {
        addresses = await InternetAddress.lookup(host).timeout(_timeout);
      } catch (_) {
        return TaskDownloadError.network;
      }
    }
    if (addresses.isEmpty) return TaskDownloadError.network;
    for (final address in addresses) {
      if (_isInternal(address)) return TaskDownloadError.blockedHost;
    }
    return null;
  }

  /// Denies loopback, link-local, multicast and private / reserved ranges
  /// (including the additional 9/11/21/30.x blocks called out by policy).
  static bool _isInternal(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return true;
    }
    final raw = address.rawAddress;
    if (address.type == InternetAddressType.IPv4 && raw.length == 4) {
      final a = raw[0];
      final b = raw[1];
      // RFC1918 + CGNAT + reserved + policy-specific blocks.
      if (a == 0 || a == 10 || a == 127) return true;
      if (a == 169 && b == 254) return true; // link-local
      if (a == 172 && b >= 16 && b <= 31) return true;
      if (a == 192 && b == 168) return true;
      if (a == 100 && b >= 64 && b <= 127) return true; // CGNAT
      if (a == 9 || a == 11 || a == 21 || a == 30) return true; // policy
      if (a >= 224) return true; // multicast / reserved
      return false;
    }
    if (address.type == InternetAddressType.IPv6 && raw.length == 16) {
      // Unique-local fc00::/7.
      if ((raw[0] & 0xfe) == 0xfc) return true;
      // Link-local fe80::/10.
      if (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80) return true;
      // Loopback ::1 and unspecified :: handled by isLoopback; also reject
      // IPv4-mapped addresses to a private v4 range.
      final isV4Mapped =
          raw.take(10).every((b) => b == 0) && raw[10] == 0xff && raw[11] == 0xff;
      if (isV4Mapped) {
        return _isInternal(
          InternetAddress(
            '${raw[12]}.${raw[13]}.${raw[14]}.${raw[15]}',
          ),
        );
      }
      return false;
    }
    return true; // Unknown family: deny.
  }
}
