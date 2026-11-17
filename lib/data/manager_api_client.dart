import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'parabeacon_server_config.dart';

const int maxManagerApkSizeBytes = 512 * 1024 * 1024;
const String managedPackageName = 'com.beacon.parabeacon';
const String managerApiBaseUrl = ParaBeaconServerConfig.baseUrl;

class ManagerRelease {
  const ManagerRelease({
    required this.versionName,
    required this.versionCode,
    required this.packageName,
    required this.sizeBytes,
    required this.sha256,
    required this.downloadUri,
    this.releaseNotes = '',
    this.createdAt,
  });

  final String versionName;
  final int versionCode;
  final String packageName;
  final int sizeBytes;
  final String sha256;
  final Uri downloadUri;
  final String releaseNotes;
  final DateTime? createdAt;

  factory ManagerRelease.fromJson(Object? value, Uri apiBaseUri) {
    if (value is! Map<String, dynamic>) {
      throw const ManagerApiException(
        'The server returned invalid release data.',
      );
    }

    final versionName = value['version_name'];
    final versionCode = value['version_code'];
    final packageName = value['package_name'];
    final sizeBytes = value['size_bytes'];
    final digest = value['sha256'];
    final downloadUrl = value['download_url'];
    final notes = value['release_notes'];
    final createdAtValue = value['created_at'];

    if (versionName is! String ||
        versionName.trim().isEmpty ||
        versionName.length > 64 ||
        versionCode is! int ||
        versionCode < 1 ||
        versionCode > 2100000000 ||
        packageName != managedPackageName ||
        sizeBytes is! int ||
        sizeBytes < 1 ||
        sizeBytes > maxManagerApkSizeBytes ||
        digest is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest) ||
        downloadUrl is! String ||
        (notes != null && notes is! String) ||
        (createdAtValue != null && createdAtValue is! String)) {
      throw const ManagerApiException(
        'The server returned invalid release data.',
      );
    }

    final downloadUri = apiBaseUri.resolve(downloadUrl);
    if (downloadUri.scheme != 'https' ||
        downloadUri.host.toLowerCase() != apiBaseUri.host.toLowerCase() ||
        downloadUri.port != apiBaseUri.port ||
        downloadUri.userInfo.isNotEmpty ||
        downloadUri.path != '/api/v1/app/releases/$versionCode/download' ||
        downloadUri.hasQuery ||
        downloadUri.hasFragment) {
      throw const ManagerApiException(
        'The release download URL is not trusted.',
      );
    }

    final createdAt = createdAtValue is String
        ? DateTime.tryParse(createdAtValue)?.toLocal()
        : null;
    return ManagerRelease(
      versionName: versionName,
      versionCode: versionCode,
      packageName: packageName as String,
      sizeBytes: sizeBytes,
      sha256: digest.toLowerCase(),
      downloadUri: downloadUri,
      releaseNotes: notes as String? ?? '',
      createdAt: createdAt,
    );
  }
}

class ManagerApiException implements Exception {
  const ManagerApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ManagerApiClient {
  ManagerApiClient({required Uri apiBaseUri, http.Client? httpClient})
    : _apiBaseUri = apiBaseUri,
      _httpClient = httpClient ?? http.Client() {
    if (!_isAllowedApiBase(apiBaseUri)) {
      throw ArgumentError.value(
        apiBaseUri,
        'apiBaseUri',
        'The manager API must use a public HTTPS host.',
      );
    }
  }

  final Uri _apiBaseUri;
  final http.Client _httpClient;

  Uri get apiBaseUri => _apiBaseUri;

  Future<List<ManagerRelease>> listReleases(String bearerToken) async {
    final request =
        http.Request('GET', _apiBaseUri.resolve('/api/v1/admin/app/releases'))
          ..followRedirects = false
          ..headers.addAll(_authorizedHeaders(bearerToken));
    final response = await _send(request);
    if (response.statusCode != 200) _throwForStatus(response.statusCode);

    final body = _decodeObject(response.body);
    final items = body['releases'];
    if (items is! List) {
      throw const ManagerApiException(
        'The server returned an invalid release list.',
      );
    }
    final releases =
        items.map((item) => ManagerRelease.fromJson(item, _apiBaseUri)).toList()
          ..sort((a, b) => b.versionCode.compareTo(a.versionCode));
    return releases;
  }

  Future<ManagerRelease> uploadRelease({
    required String bearerToken,
    required String versionName,
    required int versionCode,
    required String releaseNotes,
    required String fileName,
    required Uint8List apkBytes,
  }) async {
    _validateUpload(
      versionName: versionName,
      versionCode: versionCode,
      releaseNotes: releaseNotes,
      fileName: fileName,
      apkBytes: apkBytes,
    );

    final request =
        http.MultipartRequest(
            'POST',
            _apiBaseUri.resolve('/api/v1/admin/app/releases'),
          )
          ..followRedirects = false
          ..headers.addAll(_authorizedHeaders(bearerToken))
          ..fields.addAll({
            'version_name': versionName.trim(),
            'version_code': '$versionCode',
            'package_name': managedPackageName,
            'release_notes': releaseNotes.trim(),
          })
          ..files.add(
            http.MultipartFile.fromBytes(
              'apk',
              apkBytes,
              filename: fileName,
              contentType: http.MediaType(
                'application',
                'vnd.android.package-archive',
              ),
            ),
          );

    final response = await _send(request);
    if (response.statusCode != 201) _throwForStatus(response.statusCode);
    final release = ManagerRelease.fromJson(
      _decodeObject(response.body)['release'],
      _apiBaseUri,
    );
    final uploadedDigest = sha256.convert(apkBytes).toString();
    if (release.versionName != versionName.trim() ||
        release.versionCode != versionCode ||
        release.packageName != managedPackageName ||
        release.sizeBytes != apkBytes.length ||
        release.sha256 != uploadedDigest) {
      throw const ManagerApiException(
        'The server’s release metadata does not match the uploaded APK.',
      );
    }
    return release;
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      return await http.Response.fromStream(
        await _httpClient.send(request).timeout(const Duration(minutes: 5)),
      ).timeout(const Duration(minutes: 5));
    } on TimeoutException {
      throw const ManagerApiException('The server request timed out.');
    } on http.ClientException {
      throw const ManagerApiException('Unable to reach the manager API.');
    }
  }

  Map<String, String> _authorizedHeaders(String bearerToken) {
    final token = bearerToken.trim();
    if (token.isEmpty || token.contains(RegExp(r'\s'))) {
      throw const ManagerApiException('Enter a valid access token.');
    }
    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Report only a safe, stable error to the UI.
    }
    throw const ManagerApiException('The server returned an invalid response.');
  }

  Never _throwForStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      throw const ManagerApiException(
        'Access denied. Check the manager access token.',
      );
    }
    if (statusCode == 409) {
      throw const ManagerApiException(
        'That version code already exists or is not newer.',
      );
    }
    if (statusCode == 413) {
      throw const ManagerApiException(
        'The APK exceeds the server upload limit.',
      );
    }
    throw ManagerApiException('The manager API returned HTTP $statusCode.');
  }

  static void _validateUpload({
    required String versionName,
    required int versionCode,
    required String releaseNotes,
    required String fileName,
    required Uint8List apkBytes,
  }) {
    if (versionName.trim().isEmpty || versionName.trim().length > 64) {
      throw const ManagerApiException('Version name must be 1–64 characters.');
    }
    if (versionCode < 1 || versionCode > 2100000000) {
      throw const ManagerApiException(
        'Version code is outside the supported range.',
      );
    }
    if (releaseNotes.length > 2000) {
      throw const ManagerApiException(
        'Release notes must be 2,000 characters or fewer.',
      );
    }
    if (!fileName.toLowerCase().endsWith('.apk') ||
        apkBytes.isEmpty ||
        apkBytes.length > maxManagerApkSizeBytes ||
        !_hasZipSignature(apkBytes)) {
      throw const ManagerApiException(
        'Choose a valid APK no larger than 512 MiB.',
      );
    }
  }

  static bool _hasZipSignature(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) return false;
    return (bytes[2] == 0x03 && bytes[3] == 0x04) ||
        (bytes[2] == 0x05 && bytes[3] == 0x06) ||
        (bytes[2] == 0x07 && bytes[3] == 0x08);
  }

  static bool _isAllowedApiBase(Uri uri) =>
      ParaBeaconServerConfig.isValidOrigin(uri);
}
