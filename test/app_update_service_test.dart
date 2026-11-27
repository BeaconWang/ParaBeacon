import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/app_update_service.dart';

void main() {
  const baseUri = 'http://8.8.8.8:8080';
  final checksum = List.filled(64, 'a').join();

  test(
    'checks latest version on Android but never downloads off Wi-Fi',
    () async {
      final platform = _FakeAppUpdatePlatform()..wifi = false;
      var updateCheckCalls = 0;
      final client = MockClient((request) async {
        updateCheckCalls++;
        expect(request.method, 'GET');
        expect(request.url, Uri.parse('$baseUri/api/v1/app/releases/latest'));
        return http.Response(
          jsonEncode({
            'version_name': '1.2.3',
            'version_code': 18,
            'package_name': 'com.beacon.parabeacon',
            'size_bytes': 900,
            'sha256': checksum,
            'download_url': '/api/v1/app/releases/18/download',
          }),
          200,
        );
      });
      final service = AppUpdateService(
        apiBaseUri: Uri.parse(baseUri),
        httpClient: client,
        platform: platform,
        installedVersion: () async => const InstalledAppVersion(
          packageName: 'com.beacon.parabeacon',
          versionName: '1.2.2',
          versionCode: 17,
        ),
      );
      addTearDown(client.close);
      addTearDown(service.dispose);

      await service.checkForUpdate();

      expect(service.status, AppUpdateStatus.waitingForWifi);
      expect(service.availableRelease?.versionCode, 18);
      expect(platform.downloadCalls, 0);

      platform.wifi = true;
      await service.downloadAvailableUpdate();

      expect(updateCheckCalls, 1);
      expect(service.status, AppUpdateStatus.downloaded);
      expect(service.downloadProgress, 1);
      expect(platform.downloadCalls, 1);
      expect(platform.requestedSize, 900);
      expect(platform.requestedSha256, checksum);
      expect(platform.requestedFileName, 'parabeacon-18.apk');
      expect(platform.requestedServerBaseUri, Uri.parse(baseUri));

      platform.airplaneMode = true;
      expect(await service.isAirplaneModeEnabled(), isTrue);
      platform.airplaneMode = false;
      expect(await service.isAirplaneModeEnabled(), isFalse);

      await service.installPendingApk();
      expect(platform.installCalls, 1);
      expect(service.hasPendingInstall, isTrue);
    },
  );

  test('restores a completed APK for the next app startup', () async {
    final platform = _FakeAppUpdatePlatform()
      ..pendingApk = {
        'version_name': '1.2.3',
        'version_code': 18,
        'package_name': 'com.beacon.parabeacon',
        'size_bytes': 900,
        'sha256': checksum,
        'download_url': '/api/v1/app/releases/18/download',
        'file_path': r'C:\private\parabeacon-18.apk',
      };
    final client = MockClient(
      (_) async => throw StateError('unexpected request'),
    );
    final service = AppUpdateService(
      apiBaseUri: Uri.parse(baseUri),
      httpClient: client,
      platform: platform,
      installedVersion: () async => const InstalledAppVersion(
        packageName: 'com.beacon.parabeacon',
        versionName: '1.2.2',
        versionCode: 17,
      ),
    );
    addTearDown(client.close);
    addTearDown(service.dispose);

    await service.restorePendingUpdate();

    expect(service.status, AppUpdateStatus.downloaded);
    expect(service.hasPendingInstall, isTrue);
    expect(service.availableRelease?.versionCode, 18);
  });

  test('rejects a download URL outside the configured HTTPS origin', () async {
    final platform = _FakeAppUpdatePlatform()..wifi = true;
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'version_name': '1.2.3',
          'version_code': 18,
          'package_name': 'com.beacon.parabeacon',
          'size_bytes': 900,
          'sha256': checksum,
          'download_url': 'https://evil.example/apk',
        }),
        200,
      ),
    );
    final service = AppUpdateService(
      apiBaseUri: Uri.parse(baseUri),
      httpClient: client,
      platform: platform,
      installedVersion: () async => const InstalledAppVersion(
        packageName: 'com.beacon.parabeacon',
        versionName: '1.2.2',
        versionCode: 17,
      ),
    );
    addTearDown(client.close);
    addTearDown(service.dispose);

    await service.checkForUpdate();

    expect(service.status, AppUpdateStatus.error);
    expect(service.errorCode, 'invalid_update_download_url');
    expect(platform.downloadCalls, 0);
  });

  test('ignores newer metadata for a different Android package', () async {
    final platform = _FakeAppUpdatePlatform()..wifi = true;
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'version_name': '1.2.3',
          'version_code': 18,
          'package_name': 'com.someone.else',
          'size_bytes': 900,
          'sha256': checksum,
          'download_url': '/api/v1/app/releases/18/download',
        }),
        200,
      ),
    );
    final service = AppUpdateService(
      apiBaseUri: Uri.parse(baseUri),
      httpClient: client,
      platform: platform,
      installedVersion: () async => const InstalledAppVersion(
        packageName: 'com.beacon.parabeacon',
        versionName: '1.2.2',
        versionCode: 17,
      ),
    );
    addTearDown(client.close);
    addTearDown(service.dispose);

    await service.checkForUpdate();

    expect(service.status, AppUpdateStatus.error);
    expect(service.errorCode, 'update_package_mismatch');
    expect(platform.downloadCalls, 0);
  });
}

class _FakeAppUpdatePlatform implements AppUpdatePlatform {
  bool wifi = false;
  bool airplaneMode = false;
  Map<String, Object?>? pendingApk;
  int downloadCalls = 0;
  int installCalls = 0;
  int? requestedSize;
  String? requestedSha256;
  String? requestedFileName;
  Uri? requestedServerBaseUri;

  @override
  bool get isAndroid => true;

  @override
  Future<Map<String, Object?>?> getPendingApk() async => pendingApk;

  @override
  Future<bool> showUpdateReadyNotification({
    required String title,
    required String body,
  }) async => true;

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
    downloadCalls++;
    requestedSize = sizeBytes;
    requestedSha256 = sha256Hex;
    requestedFileName = fileName;
    requestedServerBaseUri = serverBaseUri;
    expect(url.host, '8.8.8.8');
    expect(versionName, '1.2.3');
    expect(versionCode, 18);
    expect(packageName, 'com.beacon.parabeacon');
    expect(serverBaseUri, Uri.parse('http://8.8.8.8:8080'));
    onProgress(0.5);
    return r'C:\private\parabeacon-18.apk';
  }

  @override
  Future<bool> isWifiConnected() async => wifi;

  @override
  Future<bool> isAirplaneModeEnabled() async => airplaneMode;

  @override
  Future<InstallApkResult> installApk({
    required String filePath,
    required int sizeBytes,
    required String sha256Hex,
    required String packageName,
    required int versionCode,
  }) async {
    installCalls++;
    expect(filePath, r'C:\private\parabeacon-18.apk');
    expect(sizeBytes, 900);
    expect(sha256Hex, List.filled(64, 'a').join());
    expect(packageName, 'com.beacon.parabeacon');
    expect(versionCode, 18);
    return InstallApkResult.launched;
  }
}
