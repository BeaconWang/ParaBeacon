import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const int maxAndroidApkSizeBytes = 512 * 1024 * 1024;

abstract interface class AppUpdatePlatform {
  bool get isAndroid;
  Future<bool> isWifiConnected();
  Future<String> downloadApk({
    required Uri url,
    required String fileName,
    required int sizeBytes,
    required String sha256Hex,
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
  AppUpdateStatus _status = AppUpdateStatus.idle;
  AppUpdateRelease? _release;
  String? _downloadedApkPath;
  String? _errorCode;

  AppUpdateStatus get status => _status;
  AppUpdateRelease? get availableRelease => _release;
  String? get errorCode => _errorCode;
  bool get hasPendingInstall =>
      _release != null &&
      _downloadedApkPath != null &&
      (_status == AppUpdateStatus.downloaded ||
          _status == AppUpdateStatus.installPermissionRequired);

  void configure(Uri? apiBaseUri) {
    _apiBaseUri = _validApiBase(apiBaseUri) ? apiBaseUri : null;
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
    if ((_status == AppUpdateStatus.downloaded ||
            _status == AppUpdateStatus.installPermissionRequired) &&
        _downloadedApkPath != null) {
      return;
    }
    _setStatus(AppUpdateStatus.checking);
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
        _release = null;
        _setStatus(AppUpdateStatus.upToDate);
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
        _setStatus(AppUpdateStatus.upToDate);
        return;
      }
      _release = release;
      if (!await _platform.isWifiConnected()) {
        _setStatus(AppUpdateStatus.waitingForWifi);
        return;
      }
      _setStatus(AppUpdateStatus.checking);
      _downloadedApkPath = await _platform.downloadApk(
        url: release.downloadUri,
        fileName: 'parabeacon-${release.versionCode}.apk',
        sizeBytes: release.sizeBytes,
        sha256Hex: release.sha256Hex,
      );
      if (_downloadedApkPath == null || _downloadedApkPath!.isEmpty) {
        throw const _AppUpdateException('update_download_failed');
      }
      _setStatus(AppUpdateStatus.downloaded);
    } on _AppUpdateException catch (error) {
      _errorCode = error.code;
      _setStatus(AppUpdateStatus.error);
    } on Object {
      _errorCode = 'update_connection_failed';
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
    if (downloadUri.scheme != 'https' ||
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
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;

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
  Future<String> downloadApk({
    required Uri url,
    required String fileName,
    required int sizeBytes,
    required String sha256Hex,
  }) async {
    final path = await AppUpdateService._channel
        .invokeMethod<String>('downloadApk', {
          'url': url.toString(),
          'fileName': fileName,
          'sizeBytes': sizeBytes,
          'sha256': sha256Hex,
        });
    if (path == null || path.isEmpty) {
      throw const _AppUpdateException('update_download_failed');
    }
    return path;
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
