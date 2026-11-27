import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'parabeacon_server_config.dart';

const int maxAndroidApkSizeBytes = 512 * 1024 * 1024;

abstract interface class AppUpdatePlatform {
  bool get isAndroid;
  Future<bool> isWifiConnected();
  Future<bool> isAirplaneModeEnabled();
  Future<Map<String, Object?>?> getPendingApk();
  Future<bool> showUpdateReadyNotification({
    required String title,
    required String body,
  });
  Future<String> downloadApk({
    required Uri url,
    required Uri serverBaseUri,
    required String fileName,
    required String versionName,
    required int versionCode,
    required String packageName,
    required int sizeBytes,
    required String sha256Hex,
    required void Function(double progress) onProgress,
  });
  Future<InstallApkResult> installApk({
    required String filePath,
    required int sizeBytes,
    required String sha256Hex,
    required String packageName,
    required int versionCode,
  });
}

enum InstallApkResult { launched, permissionRequired }

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  waitingForWifi,
  downloading,
  downloaded,
  installPermissionRequired,
  error,
}

@immutable
class AppUpdateRelease {
  const AppUpdateRelease({
    required this.versionName,
    required this.versionCode,
    required this.packageName,
    required this.sizeBytes,
    required this.sha256Hex,
    required this.downloadUri,
  });

  final String versionName;
  final int versionCode;
  final String packageName;
  final int sizeBytes;
  final String sha256Hex;
  final Uri downloadUri;
}

@immutable
class InstalledAppVersion {
  const InstalledAppVersion({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
  });

  final String packageName;
  final String versionName;
  final int versionCode;
}

class AppUpdateService extends ChangeNotifier {
  AppUpdateService({
    Uri? apiBaseUri,
    http.Client? httpClient,
    AppUpdatePlatform? platform,
    Future<InstalledAppVersion> Function()? installedVersion,
  }) : _apiBaseUri = _validApiBase(apiBaseUri) ? apiBaseUri : null,
       _httpClient = httpClient ?? http.Client(),
       _platform = platform ?? const _MethodChannelAppUpdatePlatform(),
       _installedVersion = installedVersion ?? _readInstalledVersion;

  static final AppUpdateService instance = AppUpdateService();

  static const _channel = MethodChannel('com.beacon.parabeacon/app_update');

  final http.Client _httpClient;
  final AppUpdatePlatform _platform;
  final Future<InstalledAppVersion> Function() _installedVersion;
  Uri? _apiBaseUri;
  Future<void>? _checkFuture;
  Future<void>? _downloadFuture;
  AppUpdateStatus _status = AppUpdateStatus.idle;
  AppUpdateRelease? _release;
  String? _downloadedApkPath;
  String? _errorCode;
  double? _downloadProgress;
  int _downloadGeneration = 0;

  AppUpdateStatus get status => _status;
  AppUpdateRelease? get availableRelease => _release;
  String? get errorCode => _errorCode;
  double? get downloadProgress => _downloadProgress;
  int get downloadGeneration => _downloadGeneration;
  bool get hasPendingInstall =>
      _release != null &&
      _downloadedApkPath != null &&
      (_status == AppUpdateStatus.downloaded ||
          _status == AppUpdateStatus.installPermissionRequired);

  void configure(Uri? apiBaseUri) {
    final nextBaseUri = _validApiBase(apiBaseUri) ? apiBaseUri : null;
    if (_apiBaseUri == nextBaseUri) return;
    _apiBaseUri = nextBaseUri;
    _release = null;
    _downloadedApkPath = null;
    _errorCode = null;
    _downloadProgress = null;
    _setStatus(AppUpdateStatus.idle);
  }

  Future<bool> isWifiConnected() async {
    if (!_platform.isAndroid) return false;
    try {
      return await _platform.isWifiConnected();
    } on Object {
      return false;
    }
  }

  Future<bool> isAirplaneModeEnabled() async {
    if (!_platform.isAndroid) return false;
    try {
      return await _platform.isAirplaneModeEnabled();
    } on Object {
      return true;
    }
  }

  Future<void> restorePendingUpdate() async {
    final baseUri = _apiBaseUri;
    if (!_platform.isAndroid || baseUri == null) return;
    try {
      final metadata = await _platform.getPendingApk();
      final filePath = metadata?['file_path'];
      if (metadata == null || filePath is! String || filePath.isEmpty) return;
      final release = _parseRelease(jsonEncode(metadata), baseUri);
      final installed = await _installedVersion();
      if (release.packageName != installed.packageName ||
          release.versionCode <= installed.versionCode) {
        return;
      }
      _release = release;
      _downloadedApkPath = filePath;
      _downloadProgress = 1;
      _setStatus(AppUpdateStatus.downloaded);
    } on Object {
      return;
    }
  }

  Future<bool> showUpdateReadyNotification({
    required String title,
    required String body,
  }) async {
    if (!_platform.isAndroid) return false;
    try {
      return await _platform.showUpdateReadyNotification(
        title: title,
        body: body,
      );
    } on Object {
      return false;
    }
  }

  Future<void> checkForUpdate() async {
    if (!_platform.isAndroid || _apiBaseUri == null) return;
    final existing = _checkFuture;
    if (existing != null) return existing;
    final future = _checkForUpdate();
    _checkFuture = future;
    try {
      await future;
    } finally {
      if (identical(_checkFuture, future)) _checkFuture = null;
    }
  }

  Future<void> _checkForUpdate() async {
    final hadPendingInstall = hasPendingInstall;
    if (!hadPendingInstall) _setStatus(AppUpdateStatus.checking);
    try {
      final baseUri = _apiBaseUri!;
      final request = http.Request(
        'GET',
        baseUri.resolve('/api/v1/app/releases/latest'),
      )..followRedirects = false;
      final response = await http.Response.fromStream(
        await _httpClient.send(request).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        if (!hadPendingInstall) {
          _release = null;
          _downloadedApkPath = null;
          _setStatus(AppUpdateStatus.upToDate);
        }
        return;
      }
      if (response.statusCode != 200) {
        throw const _AppUpdateException('update_check_failed');
      }
      final release = _parseRelease(response.body, baseUri);
      final installed = await _installedVersion();
      if (installed.packageName != release.packageName) {
        throw const _AppUpdateException('update_package_mismatch');
      }
      if (release.versionCode <= installed.versionCode) {
        _release = null;
        _downloadedApkPath = null;
        _downloadProgress = null;
        _setStatus(AppUpdateStatus.upToDate);
        return;
      }
      if (hadPendingInstall &&
          _release?.versionCode == release.versionCode &&
          _release?.sha256Hex == release.sha256Hex) {
        if (_status != AppUpdateStatus.installPermissionRequired) {
          _setStatus(AppUpdateStatus.downloaded);
        }
        return;
      }
      _downloadedApkPath = null;
      _downloadProgress = null;
      _release = release;
      if (!await isWifiConnected()) {
        _setStatus(AppUpdateStatus.waitingForWifi);
        return;
      }
      await _startDownload(release, baseUri);
    } on _AppUpdateException catch (error) {
      if (hadPendingInstall) return;
      _errorCode = error.code;
      _setStatus(AppUpdateStatus.error);
    } on Object {
      if (hadPendingInstall) return;
      _errorCode = 'update_connection_failed';
      _setStatus(AppUpdateStatus.error);
    }
  }

  Future<void> downloadAvailableUpdate() async {
    final release = _release;
    final baseUri = _apiBaseUri;
    if (!_platform.isAndroid ||
        release == null ||
        baseUri == null ||
        _status != AppUpdateStatus.waitingForWifi ||
        !await isWifiConnected()) {
      return;
    }
    await _startDownload(release, baseUri);
  }

  Future<void> _startDownload(AppUpdateRelease release, Uri baseUri) async {
    final existing = _downloadFuture;
    if (existing != null) return existing;
    final future = _download(release, baseUri);
    _downloadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_downloadFuture, future)) _downloadFuture = null;
    }
  }

  Future<void> _download(AppUpdateRelease release, Uri baseUri) async {
    _downloadGeneration++;
    _downloadProgress = 0;
    _errorCode = null;
    _setStatus(AppUpdateStatus.downloading);
    try {
      final path = await _platform.downloadApk(
        url: release.downloadUri,
        serverBaseUri: baseUri,
        fileName: 'parabeacon-${release.versionCode}.apk',
        versionName: release.versionName,
        versionCode: release.versionCode,
        packageName: release.packageName,
        sizeBytes: release.sizeBytes,
        sha256Hex: release.sha256Hex,
        onProgress: (value) {
          if (!value.isFinite) return;
          _downloadProgress = value.clamp(0.0, 1.0).toDouble();
          notifyListeners();
        },
      );
      if (path.isEmpty) {
        throw const _AppUpdateException('update_download_failed');
      }
      _downloadedApkPath = path;
      _downloadProgress = 1;
      _setStatus(AppUpdateStatus.downloaded);
    } on _AppUpdateException catch (error) {
      _errorCode = error.code;
      _downloadProgress = null;
      _setStatus(
        error.code == 'wifi_required'
            ? AppUpdateStatus.waitingForWifi
            : AppUpdateStatus.error,
      );
    } on Object {
      _errorCode = 'update_download_failed';
      _downloadProgress = null;
      _setStatus(AppUpdateStatus.error);
    }
  }

  Future<void> installPendingApk() async {
    final path = _downloadedApkPath;
    if (!_platform.isAndroid || path == null || path.isEmpty) return;
    try {
      final release = _release;
      if (release == null) return;
      final result = await _platform.installApk(
        filePath: path,
        sizeBytes: release.sizeBytes,
        sha256Hex: release.sha256Hex,
        packageName: release.packageName,
        versionCode: release.versionCode,
      );
      _setStatus(
        result == InstallApkResult.permissionRequired
            ? AppUpdateStatus.installPermissionRequired
            : AppUpdateStatus.downloaded,
      );
    } on Object {
      _errorCode = 'update_install_failed';
      _setStatus(AppUpdateStatus.error);
    }
  }

  static AppUpdateRelease _parseRelease(String body, Uri baseUri) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const _AppUpdateException('invalid_update_metadata');
    }
    final versionName = decoded['version_name'];
    final versionCode = decoded['version_code'];
    final packageName = decoded['package_name'];
    final sizeBytes = decoded['size_bytes'];
    final sha256Hex = decoded['sha256'];
    final downloadUrl = decoded['download_url'];
    if (versionName is! String ||
        versionName.isEmpty ||
        versionName.length > 64 ||
        versionCode is! int ||
        versionCode < 1 ||
        versionCode > 2100000000 ||
        packageName is! String ||
        packageName.isEmpty ||
        sizeBytes is! int ||
        sizeBytes < 1 ||
        sizeBytes > maxAndroidApkSizeBytes ||
        sha256Hex is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256Hex) ||
        downloadUrl is! String) {
      throw const _AppUpdateException('invalid_update_metadata');
    }
    final downloadUri = baseUri.resolve(downloadUrl);
    if (downloadUri.scheme != baseUri.scheme ||
        downloadUri.host.toLowerCase() != baseUri.host.toLowerCase() ||
        downloadUri.port != baseUri.port ||
        downloadUri.userInfo.isNotEmpty ||
        downloadUri.path != '/api/v1/app/releases/$versionCode/download' ||
        downloadUri.hasQuery ||
        downloadUri.hasFragment) {
      throw const _AppUpdateException('invalid_update_download_url');
    }
    return AppUpdateRelease(
      versionName: versionName,
      versionCode: versionCode,
      packageName: packageName,
      sizeBytes: sizeBytes,
      sha256Hex: sha256Hex.toLowerCase(),
      downloadUri: downloadUri,
    );
  }

  static bool _validApiBase(Uri? uri) =>
      ParaBeaconServerConfig.isValidOrigin(uri);

  static Future<InstalledAppVersion> _readInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    final versionCode = int.tryParse(info.buildNumber);
    if (versionCode == null || versionCode < 0) {
      throw const _AppUpdateException('invalid_installed_version');
    }
    return InstalledAppVersion(
      packageName: info.packageName,
      versionName: info.version,
      versionCode: versionCode,
    );
  }

  void _setStatus(AppUpdateStatus value) {
    _status = value;
    notifyListeners();
  }
}

class _AppUpdateException implements Exception {
  const _AppUpdateException(this.code);
  final String code;
}

class _MethodChannelAppUpdatePlatform implements AppUpdatePlatform {
  const _MethodChannelAppUpdatePlatform();

  @override
  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isWifiConnected() async =>
      await AppUpdateService._channel.invokeMethod<bool>('isWifiConnected') ??
      false;

  @override
  Future<bool> isAirplaneModeEnabled() async =>
      await AppUpdateService._channel.invokeMethod<bool>(
        'isAirplaneModeEnabled',
      ) ??
      false;

  @override
  Future<Map<String, Object?>?> getPendingApk() async => await AppUpdateService
      ._channel
      .invokeMapMethod<String, Object?>('getPendingApk');

  @override
  Future<bool> showUpdateReadyNotification({
    required String title,
    required String body,
  }) async =>
      await AppUpdateService._channel.invokeMethod<bool>(
        'showUpdateReadyNotification',
        {'title': title, 'body': body},
      ) ??
      false;

  @override
  Future<String> downloadApk({
    required Uri url,
    required Uri serverBaseUri,
    required String fileName,
    required String versionName,
    required int versionCode,
    required String packageName,
    required int sizeBytes,
    required String sha256Hex,
    required void Function(double progress) onProgress,
  }) async {
    AppUpdateService._channel.setMethodCallHandler((call) async {
      if (call.method != 'downloadProgress' || call.arguments is! Map) return;
      final arguments = call.arguments as Map;
      final bytes = arguments['bytesDownloaded'];
      final total = arguments['totalBytes'];
      if (bytes is num && total is num && total > 0) {
        onProgress(bytes / total);
      }
    });
    try {
      final path = await AppUpdateService._channel
          .invokeMethod<String>('downloadApk', {
            'url': url.toString(),
            'serverOrigin': serverBaseUri.toString(),
            'fileName': fileName,
            'versionName': versionName,
            'versionCode': versionCode,
            'packageName': packageName,
            'sizeBytes': sizeBytes,
            'sha256': sha256Hex,
          });
      if (path == null || path.isEmpty) {
        throw const _AppUpdateException('update_download_failed');
      }
      return path;
    } on PlatformException catch (error) {
      if (error.code == 'WIFI_REQUIRED') {
        throw const _AppUpdateException('wifi_required');
      }
      throw const _AppUpdateException('update_download_failed');
    } finally {
      AppUpdateService._channel.setMethodCallHandler(null);
    }
  }

  @override
  Future<InstallApkResult> installApk({
    required String filePath,
    required int sizeBytes,
    required String sha256Hex,
    required String packageName,
    required int versionCode,
  }) async {
    final result = await AppUpdateService._channel
        .invokeMethod<String>('installApk', {
          'filePath': filePath,
          'sizeBytes': sizeBytes,
          'sha256': sha256Hex,
          'packageName': packageName,
          'versionCode': versionCode,
        });
    return result == 'permission_required'
        ? InstallApkResult.permissionRequired
        : InstallApkResult.launched;
  }
}
