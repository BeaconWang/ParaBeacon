import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

String? _asString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return value is num ? value.toString() : null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

class AsfcAgency {
  const AsfcAgency({required this.id, required this.name});

  final int id;
  final String name;

  factory AsfcAgency.fromJson(Map<String, dynamic> json) {
    return AsfcAgency(
      id: _asInt(json['id']) ?? _asInt(json['agencyId']) ?? 0,
      name: _asString(json['agencyName']) ?? _asString(json['name']) ?? '',
    );
  }
}

class AsfcCoach {
  const AsfcCoach({
    required this.id,
    required this.name,
    this.agencyId = 0,
    this.agencyName = '',
    this.level = '',
  });

  final int id;
  final String name;
  final int agencyId;
  final String agencyName;
  final String level;

  factory AsfcCoach.fromJson(Map<String, dynamic> json) {
    return AsfcCoach(
      id: _asInt(json['id']) ?? _asInt(json['coachId']) ?? 0,
      name: _asString(json['fullName']) ??
          _asString(json['coachName']) ??
          _asString(json['name']) ??
          '',
      agencyId: _asInt(json['agencyId']) ??
          _asInt(json['coachAgencyId']) ??
          _asInt(json['agency_id']) ??
          0,
      agencyName: _asString(json['agencyName']) ?? '',
      level: _asString(json['level']) ?? '',
    );
  }

}

class AsfcFlightRecord {
  const AsfcFlightRecord({
    required this.id,
    required this.trainTime,
    required this.address,
    required this.brandNo,
    required this.taskName,
    required this.startTime,
    required this.endTime,
    required this.seatType,
    required this.takeoffMode,
    required this.sortie,
    required this.coachAgencyId,
    required this.coachId,
    this.userName = '',
    this.coachName = '',
    this.coachAgencyName = '',
    this.auditStatus = 0,
    this.seatTypeName = '',
    this.signinDescription = '',
    this.coachSigninStatus = 0,
  });

  final int id;
  final String trainTime;
  final String address;
  final String brandNo;
  final String taskName;
  final String startTime;
  final String endTime;
  final String seatType;
  final String takeoffMode;
  final String sortie;
  final int coachAgencyId;
  final int coachId;
  final String userName;
  final String coachName;
  final String coachAgencyName;
  final int auditStatus;
  final String seatTypeName;
  final String signinDescription;
  final int coachSigninStatus;

  factory AsfcFlightRecord.fromJson(Map<String, dynamic> json) {
    return AsfcFlightRecord(
      id: _asInt(json['id']) ?? 0,
      trainTime: _asString(json['trainTime']) ?? '',
      address: _asString(json['address']) ?? '',
      brandNo: _asString(json['brandNo']) ?? '',
      taskName: _asString(json['taskName']) ?? '',
      startTime: _asString(json['startTime']) ?? '',
      endTime: _asString(json['endTime']) ?? '',
      seatType: _asString(json['seatType']) ?? '',
      takeoffMode: _asString(json['takeoffMode']) ?? '',
      sortie: _asString(json['sortie']) ?? '',
      coachAgencyId: _asInt(json['coachAgencyId']) ?? 0,
      coachId: _asInt(json['coachId']) ?? 0,
      userName: _asString(json['userName']) ?? '',
      coachName: _asString(json['coachName']) ?? '',
      coachAgencyName: _asString(json['coachAgencyName']) ?? '',
      auditStatus: _asInt(json['audtiStatus']) ?? _asInt(json['auditStatus']) ?? 0,
      seatTypeName: _asString(json['seatTypeName']) ?? '',
      signinDescription: _asString(json['signinDescirption']) ??
          _asString(json['signinDescription']) ?? '',
      coachSigninStatus: _asInt(json['coachSigninStatus']) ?? 0,
    );
  }
}

enum AsfcCertificateState { none, pending, issued, rejected }

class AsfcCertificateStatus {
  const AsfcCertificateStatus({
    required this.state,
    this.application,
  });

  final AsfcCertificateState state;
  final Map<String, dynamic>? application;

  bool get hasRecord => application != null;
  String? get auditStatus => _stringValue(application?['auditStatus']);
  String? get licenseNo => _stringValue(application?['licenseNo']);
  String? get fullName => _stringValue(application?['fullName']);
  String? get level => _stringValue(application?['level']);
  String? get country => _stringValue(application?['country']);
  String? get sexName => _stringValue(application?['sexName']) ??
      _stringValue(application?['sex']);
  String? get birthday => _stringValue(application?['birthday']);
  String? get cityName => _stringValue(application?['cityName']) ??
      _stringValue(application?['area']);
  String? get licenseStatusName =>
      _stringValue(application?['licenseStatusName']);
  String? get licenseValidStart =>
      _stringValue(application?['licenseValidStart']) ??
      _stringValue(application?['startTime']);
  String? get licenseValidEnd =>
      _stringValue(application?['licenseValidEnd']) ??
      _stringValue(application?['endTime']);
  String? get sportCode => _stringValue(application?['sportCode']);

  static String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return null;
  }
}

class AsfcAuthService extends ChangeNotifier {
  AsfcAuthService._();

  static final AsfcAuthService instance = AsfcAuthService._();

  static final Uri _loginUri = Uri.parse(
    'https://www.57fly.com/api/user/user/login',
  );
  static final Uri _captchaUri = Uri.parse(
    'https://www.57fly.com/api/files/user/imageValidateCode/loadImage',
  );
  static final Uri _sendSmsCodeUri = Uri.parse(
    'https://www.57fly.com/api/user/smsvcode/sendSmsCode',
  );
  static final Uri _profileUri = Uri.parse(
    'https://www.57fly.com/api/user/customeUser/onloadInfo',
  );
  static final Uri _certificateApplicationUri = Uri.parse(
    'https://www.57fly.com/api/train/parasailLicense/customerApply',
  );
  static final Uri _certificateUpgradeUri = Uri.parse(
    'https://www.57fly.com/api/train/parasailLicense/customerUpgradeLevelApply',
  );
  static final Uri _certificateInfoUri = Uri.parse(
    'https://www.57fly.com/api/train/parasailLicense/customerInfo',
  );
  static final Uri _certificateCoachesUri = Uri.parse(
    'https://www.57fly.com/api/train/parasailLicense/allCoach',
  );
  static final Uri _flightRecordListUri = Uri.parse(
    'https://www.57fly.com/api/train/trainFlyRecord/customer/list',
  );
  static final Uri _flightRecordDetailUri = Uri.parse(
    'https://www.57fly.com/api/train/trainFlyRecord/customer/detail',
  );
  static final Uri _flightRecordSaveUri = Uri.parse(
    'https://www.57fly.com/api/train/trainFlyRecord/saveOrUpdate',
  );
  static final Uri _flightRecordDeleteUri = Uri.parse(
    'https://www.57fly.com/api/train/trainFlyRecord/delete',
  );
  static final Uri _agenciesUri = Uri.parse(
    'https://www.57fly.com/api/train/trainAgency/authority',
  );
  static final Uri _certificateImageUploadUri = Uri.parse(
    'https://upload.57fly.com/api/imageUpload/0/upload',
  );
  static const _tokenKey = 'asfc_access_token';
  static const _circleTokenKey = 'asfc_circle_token';
  static const _usernameKey = 'asfc_username';
  static const _storage = FlutterSecureStorage();

  bool _loaded = false;
  bool _loading = false;
  bool _captchaLoading = false;
  bool _smsCodeLoading = false;
  bool _profileLoading = false;
  bool _certificateInfoLoading = false;
  bool _certificateCoachesLoading = false;
  bool _flightRecordsLoading = false;
  bool _flightRecordSubmitting = false;
  bool _agenciesLoading = false;
  Uint8List? _captchaImageBytes;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _certificateApplication;
  List<AsfcCoach>? _certificateCoaches;
  List<AsfcAgency>? _agencies;
  List<AsfcFlightRecord>? _flightRecords;
  String? _profileErrorCode;
  String? _profileErrorMessage;
  String? _token;
  String? _circleToken;
  String? _username;
  String? _errorCode;
  String? _errorMessage;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  bool get isCaptchaLoading => _captchaLoading;
  bool get isSmsCodeLoading => _smsCodeLoading;
  bool get isProfileLoading => _profileLoading;
  bool get isCertificateInfoLoading => _certificateInfoLoading;
  bool get isCertificateCoachesLoading => _certificateCoachesLoading;
  bool get isFlightRecordsLoading => _flightRecordsLoading;
  bool get isFlightRecordSubmitting => _flightRecordSubmitting;
  bool get isAgenciesLoading => _agenciesLoading;
  Uint8List? get captchaImageBytes => _captchaImageBytes;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;
  String? get username => _username;
  String? get errorCode => _errorCode;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get profile =>
      _profile == null ? null : Map.unmodifiable(_profile!);
  Map<String, dynamic>? get certificateApplication => _certificateApplication == null
      ? null
      : Map.unmodifiable(_certificateApplication!);
  List<AsfcCoach> get certificateCoaches =>
      List.unmodifiable(_certificateCoaches ?? const <AsfcCoach>[]);
  List<AsfcAgency> get agencies =>
      List.unmodifiable(_agencies ?? const <AsfcAgency>[]);
  List<AsfcFlightRecord> get flightRecords =>
      List.unmodifiable(_flightRecords ?? const <AsfcFlightRecord>[]);
  AsfcCertificateStatus get certificateStatus {
    final application = _certificateApplication;
    if (application == null) {
      return const AsfcCertificateStatus(state: AsfcCertificateState.none);
    }
    final status = _stringValue(application['auditStatus'])?.toUpperCase();
    final hasCertificate = status == 'ADOPT';
    final isRejected = status == 'REJECT' || status == 'REFUSE';
    return AsfcCertificateStatus(
      application: Map.unmodifiable(application),
      state: hasCertificate
          ? AsfcCertificateState.issued
          : isRejected
              ? AsfcCertificateState.rejected
              : AsfcCertificateState.pending,
    );
  }
  static String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return null;
  }

  String? get profileErrorCode => _profileErrorCode;
  String? get profileErrorMessage => _profileErrorMessage;
  String? get avatarUrl {
    final user = _profile?['user'];
    final raw = user is Map<String, dynamic> ? user['headPortrait'] : null;
    if (raw is! String || raw.trim().isEmpty) return null;
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      return uri.host == 'upload.57fly.com' ? uri.toString() : null;
    }
    if (value.startsWith('/')) {
      return Uri.parse('https://upload.57fly.com$value').toString();
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) return;
    _token = await _storage.read(key: _tokenKey);
    _circleToken = await _storage.read(key: _circleTokenKey);
    _username = await _storage.read(key: _usernameKey);
    _loaded = true;
    notifyListeners();
  }

  Future<bool> loadProfile({bool force = false}) async {
    if (!isSignedIn) {
      _profileErrorCode = 'profileNotSignedIn';
      _profileErrorMessage = null;
      notifyListeners();
      return false;
    }
    if (_profileLoading || (!force && _profile != null)) return true;

    _profileLoading = true;
    _profileErrorCode = null;
    _profileErrorMessage = null;
    notifyListeners();
    try {
      final response = await http
          .get(
            _profileUri,
            headers: {'Accept': 'application/json', 'token': _token!},
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final status = decoded?['status']?.toString().toLowerCase();
      final code = decoded?['code']?.toString();
      final data = decoded?['data'];
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == 'success' || status == '200' || code == '200');
      if (!success || data is! Map<String, dynamic>) {
        _profileErrorCode = 'profileLoadFailed';
        _profileErrorMessage = decoded == null
            ? _responseFallbackReason(response)
            : _extractResponseReason(decoded) ??
                  _responseFallbackReason(response, status: status, code: code);
        return false;
      }
      _profile = data;
      return true;
    } on Exception {
      _profileErrorCode = 'profileConnectionFailed';
      _profileErrorMessage = null;
      return false;
    } finally {
      _profileLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> loadCertificateApplication({
    bool force = false,
  }) async {
    if (!isSignedIn) return null;
    if (_certificateInfoLoading || (!force && _certificateApplication != null)) {
      return certificateApplication;
    }

    _certificateInfoLoading = true;
    notifyListeners();
    try {
      final response = await http
          .get(
            _certificateInfoUri,
            headers: {'Accept': 'application/json', 'token': _token!},
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final status = decoded?['status']?.toString().toLowerCase();
      final code = decoded?['code']?.toString();
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == 'success' || status == '200' || code == '200');
      final data = decoded?['data'];
      if (success) {
        _certificateApplication = data is Map<String, dynamic> ? data : null;
      }
      return certificateApplication;
    } on Exception {
      return null;
    } finally {
      _certificateInfoLoading = false;
      notifyListeners();
    }
  }

  Future<List<AsfcCoach>> loadCertificateCoaches({
    bool force = false,
  }) async {
    if (!isSignedIn) return const <AsfcCoach>[];
    if (_certificateCoachesLoading || (!force && _certificateCoaches != null)) {
      return certificateCoaches;
    }

    _certificateCoachesLoading = true;
    notifyListeners();
    try {
      final response = await http
          .get(
            _certificateCoachesUri,
            headers: {'Accept': 'application/json', 'token': _token!},
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final status = decoded?['status']?.toString().toLowerCase();
      final code = decoded?['code']?.toString();
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == 'success' || status == '200' || code == '200');
      final data = decoded?['data'];
      if (success && data is List) {
        _certificateCoaches = data
            .whereType<Map<String, dynamic>>()
            .map(AsfcCoach.fromJson)
            .where((coach) => coach.id > 0 && coach.name.isNotEmpty)
            .toList(growable: false);
      }
      return certificateCoaches;
    } on Exception {
      return const <AsfcCoach>[];
    } finally {
      _certificateCoachesLoading = false;
      notifyListeners();
    }
  }

  Future<List<AsfcAgency>> loadAgencies({bool force = false}) async {
    if (!isSignedIn) return const <AsfcAgency>[];
    if (_agenciesLoading || (!force && _agencies != null)) return agencies;
    _agenciesLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        _agenciesUri,
        headers: {'Accept': 'application/json', 'token': _token!},
      ).timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final data = decoded?['data'];
      final success = _isSuccessful(response.statusCode, decoded);
      if (success && data is List) {
        _agencies = data
            .whereType<Map<String, dynamic>>()
            .map(AsfcAgency.fromJson)
            .where((agency) => agency.id > 0 && agency.name.isNotEmpty)
            .toList(growable: false);
      }
      return agencies;
    } on Exception {
      return const <AsfcAgency>[];
    } finally {
      _agenciesLoading = false;
      notifyListeners();
    }
  }

  Future<List<AsfcFlightRecord>> loadFlightRecords({
    int page = 1,
    bool force = false,
  }) async {
    if (!isSignedIn) return const <AsfcFlightRecord>[];
    if (_flightRecordsLoading || (!force && _flightRecords != null)) {
      return flightRecords;
    }
    _flightRecordsLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        _flightRecordListUri.replace(
          queryParameters: {'page': '$page', 'type': 'CUSTOMER'},
        ),
        headers: {'Accept': 'application/json', 'token': _token!},
      ).timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final data = decoded?['data'];
      final rows = data is Map<String, dynamic> ? data['rows'] : data;
      if (_isSuccessful(response.statusCode, decoded) && rows is List) {
        _flightRecords = rows
            .whereType<Map<String, dynamic>>()
            .map(AsfcFlightRecord.fromJson)
            .where((record) => record.id > 0)
            .toList(growable: false);
      }
      return flightRecords;
    } on Exception {
      return const <AsfcFlightRecord>[];
    } finally {
      _flightRecordsLoading = false;
      notifyListeners();
    }
  }

  Future<AsfcFlightRecord?> loadFlightRecordDetail(int id) async {
    if (!isSignedIn || id <= 0) return null;
    try {
      final response = await http.get(
        _flightRecordDetailUri.replace(queryParameters: {'id': '$id'}),
        headers: {'Accept': 'application/json', 'token': _token!},
      ).timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final data = decoded?['data'];
      if (_isSuccessful(response.statusCode, decoded) &&
          data is Map<String, dynamic>) {
        return AsfcFlightRecord.fromJson(data);
      }
    } on Exception {
      return null;
    }
    return null;
  }

  Future<bool> saveFlightRecord({
    int? id,
    required String trainTime,
    required String address,
    required String brandNo,
    required String taskName,
    required String startTime,
    required String endTime,
    required String seatType,
    required String takeoffMode,
    required String sortie,
    required int coachAgencyId,
    required int coachId,
  }) async {
    if (!isSignedIn || coachAgencyId <= 0 || coachId <= 0) {
      _errorCode = 'flightRecordSelectionRequired';
      _errorMessage = null;
      notifyListeners();
      return false;
    }
    final values = [
      trainTime,
      address,
      brandNo,
      taskName,
      startTime,
      endTime,
      seatType,
      takeoffMode,
      sortie,
    ];
    if (values.any((value) => value.trim().isEmpty) ||
        values.any((value) => value.length > 100)) {
      _errorCode = 'flightRecordFieldsInvalid';
      _errorMessage = null;
      notifyListeners();
      return false;
    }
    _flightRecordSubmitting = true;
    notifyListeners();
    try {
      final payload = <String, dynamic>{
        'trainTime': trainTime.trim(),
        'address': address.trim(),
        'brandNo': brandNo.trim(),
        'taskName': taskName.trim(),
        'startTime': startTime.trim(),
        'endTime': endTime.trim(),
        'seatType': seatType.trim(),
        'takeoffMode': takeoffMode.trim(),
        'sortie': sortie.trim(),
        'coachAgencyId': coachAgencyId,
        'coachId': coachId,
      };
      if (id != null && id > 0) payload['id'] = id;
      final response = await http.post(
        _flightRecordSaveUri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
          'token': _token!,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));
      final decoded = _decodeMap(response.body);
      final success = _isSuccessful(response.statusCode, decoded);
      if (!success) {
        _errorCode = 'flightRecordSaveFailed';
        _errorMessage = decoded == null
            ? 'HTTP ${response.statusCode}'
            : _extractResponseReason(decoded);
        return false;
      }
      _errorCode = null;
      _errorMessage = null;
      await loadFlightRecords(force: true);
      return true;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      return false;
    } finally {
      _flightRecordSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteFlightRecord(int id) async {
    if (!isSignedIn || id <= 0) return false;
    try {
      final response = await http.get(
        _flightRecordDeleteUri.replace(queryParameters: {'id': '$id'}),
        headers: {'Accept': 'application/json', 'token': _token!},
      ).timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final success = _isSuccessful(response.statusCode, decoded);
      if (success) {
        _flightRecords?.removeWhere((record) => record.id == id);
        notifyListeners();
      }
      return success;
    } on Exception {
      return false;
    }
  }

  bool _isSuccessful(int statusCode, Map<String, dynamic>? decoded) {
    final status = decoded?['status']?.toString().toLowerCase();
    final code = decoded?['code']?.toString();
    return statusCode >= 200 &&
        statusCode < 300 &&
        (status == 'success' || status == '200' || code == '200');
  }

  Future<bool> loadCaptcha({required String mobile}) async {
    final normalizedMobile = mobile.trim();
    if (normalizedMobile.isEmpty) {
      _errorCode = 'smsMobileRequired';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    _captchaLoading = true;
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await http
          .get(
            _captchaUri.replace(queryParameters: {'mobile': normalizedMobile}),
            headers: const {'Accept': 'image/*, application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        _errorCode = 'captchaLoadFailed';
        _errorMessage =
            _responseReasonFromBody(response) ??
            _responseFallbackReason(response);
        return false;
      }
      _captchaImageBytes = response.bodyBytes;
      return true;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      return false;
    } finally {
      _captchaLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendSmsCode({
    required String mobile,
    required String captcha,
  }) async {
    final normalizedMobile = mobile.trim();
    final normalizedCaptcha = captcha.trim();
    if (normalizedMobile.isEmpty || normalizedCaptcha.isEmpty) {
      _errorCode = normalizedMobile.isEmpty
          ? 'smsMobileRequired'
          : 'captchaRequired';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    _smsCodeLoading = true;
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await http
          .get(
            _sendSmsCodeUri.replace(
              queryParameters: {
                'type': 'login',
                'mobile': normalizedMobile,
                'verificationCode': normalizedCaptcha,
              },
            ),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final status = decoded?['status']?.toString().toLowerCase();
      final code = decoded?['code']?.toString();
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == 'success' || status == '200' || code == '200');
      if (!success) {
        _errorCode = 'smsCodeSendFailed';
        _errorMessage = decoded == null
            ? _responseFallbackReason(response)
            : _extractResponseReason(decoded) ??
                  _responseFallbackReason(response, status: status, code: code);
        return false;
      }
      return true;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      return false;
    } finally {
      _smsCodeLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    String? smsCode,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedSmsCode = smsCode?.trim();
    final isSmsLogin = normalizedSmsCode != null;
    final hasMissingCredentials =
        normalizedUsername.isEmpty ||
        (isSmsLogin ? normalizedSmsCode.isEmpty : password.isEmpty);
    if (hasMissingCredentials) {
      _errorCode = isSmsLogin ? 'smsCredentialsRequired' : 'missingCredentials';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    _loading = true;
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .post(
            _loginUri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
            // Matches GoFly's password-login request. Nullable optional fields
            // are omitted, as they are by its JSON converter.
            body: jsonEncode({
              'username': normalizedUsername,
              'sys': 'portal',
              if (isSmsLogin) ...{
                'code': normalizedSmsCode,
                'loginType': 'sms_login',
              } else
                'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        _errorCode = 'loginFailed';
        _errorMessage = _responseFallbackReason(response);
        return false;
      }
      if (decoded is! Map<String, dynamic>) {
        _errorCode = 'loginFailed';
        _errorMessage = _responseFallbackReason(response);
        return false;
      }

      final status = decoded['status']?.toString().toUpperCase();
      final code = decoded['code']?.toString();
      final responseReason = _extractResponseReason(decoded);
      final isSuccess =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == 'success' ||
              status == '200' ||
              status == 'SUCCESS' ||
              code == '200');
      final data = decoded['data'];
      final token = data is Map<String, dynamic> ? data['token'] : null;
      final circleToken = data is Map<String, dynamic>
          ? data['circleToken']
          : null;

      if (!isSuccess || token is! String || token.isEmpty) {
        _errorCode = 'loginFailed';
        _errorMessage =
            responseReason ??
            _responseFallbackReason(response, status: status, code: code);
        return false;
      }

      _token = token;
      _circleToken = circleToken is String ? circleToken : null;
      _username = normalizedUsername;
      _profile = null;
      _certificateApplication = null;
      _certificateCoaches = null;
      _agencies = null;
      _flightRecords = null;
      _profileErrorCode = null;
      _profileErrorMessage = null;
      await _storage.write(key: _tokenKey, value: _token);
      if (_circleToken == null || _circleToken!.isEmpty) {
        await _storage.delete(key: _circleTokenKey);
      } else {
        await _storage.write(key: _circleTokenKey, value: _circleToken);
      }
      await _storage.write(key: _usernameKey, value: _username);
      return true;
    } on FormatException {
      _errorCode = 'loginFailed';
      _errorMessage = null;
      return false;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      return false;
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  Future<String?> uploadCertificateImage({
    required List<int> bytes,
    required String filename,
  }) async {
    if (!isSignedIn) {
      _errorCode = 'certificateNotSignedIn';
      _errorMessage = null;
      notifyListeners();
      return null;
    }
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      _errorCode = 'certificateImageInvalid';
      _errorMessage = null;
      notifyListeners();
      return null;
    }

    try {
      final request = http.MultipartRequest('POST', _certificateImageUploadUri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'filedata',
            bytes,
            filename: filename,
          ),
        );
      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final body = await response.stream.bytesToString();
      final decoded = _decodeMap(body);
      final status = decoded?['status']?.toString().toLowerCase();
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == null || status == 'success' || status == '200');
      final url = decoded?['url'] ??
          (decoded?['data'] is Map<String, dynamic>
              ? (decoded!['data'] as Map<String, dynamic>)['url']
              : null);
      final normalizedUrl = url is String ? url.trim() : '';
      final parsedUrl = Uri.tryParse(normalizedUrl);
      final allowedUrl = normalizedUrl.startsWith('/') ||
          (parsedUrl != null &&
              parsedUrl.scheme == 'https' &&
              parsedUrl.host == 'upload.57fly.com');
      if (!success || normalizedUrl.isEmpty || !allowedUrl) {
        _errorCode = 'certificateImageUploadFailed';
        _errorMessage = decoded == null
            ? 'HTTP ${response.statusCode}'
            : _extractResponseReason(decoded);
        notifyListeners();
        return null;
      }
      return normalizedUrl;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      notifyListeners();
      return null;
    }
  }

  Future<bool> applyParagliderCertificate({
    required String licensePhoto,
    required String fullName,
    required String sex,
    required String birthday,
    required String country,
    required String ethnicityCode,
    required String credentialsNumber,
    required String mobile,
    required String email,
    required String address,
    required String area,
    required String agencyName,
    required String groupPhoto,
    required String urgentContactName,
    required String urgentContactPhone,
    required String urgentBloodType,
    String licenseNo = '',
    String auditTime = '',
    String licenseValidStart = '',
    String licenseValidEnd = '',
    String areaCode = '',
    String credentialsType = 'ID_CARD',
    int parasailLicenseId = 0,
    int coachId = 0,
  }) async {
    if (!isSignedIn) {
      _errorCode = 'certificateNotSignedIn';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    final requiredValues = <String>[
      licensePhoto,
      fullName,
      sex,
      birthday,
      country,
      ethnicityCode,
      credentialsNumber,
      mobile,
      email,
      address,
      area,
      groupPhoto,
      urgentContactName,
      urgentContactPhone,
      urgentBloodType,
    ];
    if (requiredValues.any((value) => value.trim().isEmpty)) {
      _errorCode = 'certificateFieldsRequired';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    try {
      final response = await http
          .post(
            parasailLicenseId > 0
                ? _certificateUpgradeUri
                : _certificateApplicationUri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
              'token': _token!,
            },
            body: jsonEncode({
              'parasailLicenseId': parasailLicenseId,
              'licensePhoto': licensePhoto.trim(),
              'fullName': fullName.trim(),
              'sex': sex.trim(),
              'birthday': birthday.trim(),
              'country': country.trim(),
              'ethnicityCode': ethnicityCode.trim(),
              'licenseNo': licenseNo.trim(),
              'auditTime': auditTime.trim(),
              'licenseValidStart': licenseValidStart.trim(),
              'licenseValidEnd': licenseValidEnd.trim(),
              'credentialsType': credentialsType.trim(),
              'credentialsNumber': credentialsNumber.trim(),
              'mobile': mobile.trim(),
              'email': email.trim(),
              'address': address.trim(),
              'areaCode': areaCode.trim(),
              'area': area.trim(),
              'agencyName': agencyName.trim(),
              'coachId': coachId,
              'groupPhoto': groupPhoto.trim(),
              'urgentContactName': urgentContactName.trim(),
              'urgentContactPhone': urgentContactPhone.trim(),
              'urgentBloodType': urgentBloodType.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      final decoded = _decodeMap(response.body);
      final status = decoded?['status']?.toString().toLowerCase();
      final code = decoded?['code']?.toString();
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == 'success' || status == '200' || code == '200');
      if (!success) {
        _errorCode = 'certificateApplicationFailed';
        _errorMessage = decoded == null
            ? 'HTTP ${response.statusCode}'
            : _extractResponseReason(decoded);
        notifyListeners();
        return false;
      }
      _errorCode = null;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String? _responseReasonFromBody(http.Response response) {
    final decoded = _decodeMap(response.body);
    return decoded == null ? null : _extractResponseReason(decoded);
  }

  String _responseFallbackReason(
    http.Response response, {
    String? status,
    String? code,
  }) {
    final details = <String>[
      'HTTP ${response.statusCode}',
      if (status != null && status.isNotEmpty) 'status=$status',
      if (code != null && code.isNotEmpty) 'code=$code',
    ];
    return details.join(' · ');
  }

  String? _extractResponseReason(Map<String, dynamic> response) {
    final candidates = <Object?>[
      response['message'],
      response['msg'],
      response['error'],
      response['bizStatus'],
    ];
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      candidates.addAll([data['message'], data['msg'], data['error']]);
    }
    for (final candidate in candidates) {
      if (candidate is String) {
        final reason = candidate.trim();
        if (reason.isNotEmpty) {
          return reason.length <= 200 ? reason : '${reason.substring(0, 200)}…';
        }
      }
    }
    return null;
  }

  Future<void> logout() async {
    _token = null;
    _circleToken = null;
    _username = null;
    _profile = null;
    _certificateApplication = null;
    _certificateCoaches = null;
    _agencies = null;
    _flightRecords = null;
    _profileErrorCode = null;
    _profileErrorMessage = null;
    _errorCode = null;
    _errorMessage = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _circleTokenKey);
    await _storage.delete(key: _usernameKey);
    notifyListeners();
  }
}
