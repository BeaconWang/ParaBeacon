/// The `device` block of the `POST /api/flight` body.
///
/// In the APK this is `TracklogWriter$IGCSystemInfo`, a nested structure, not
/// a flat string map:
///   IGCSystemInfo { deviceId, device: DeviceInfo, os: OSInfo, app: XCTrackInfo }
/// built in live/c1.smali:3446-3462 and declared in
/// rest/apis/LivetrackApi$FlightOptions.smali:26-35.
///
/// Gson serialises every non-null field, so the server sees all of them; a
/// flat `{manufacturer, model, os, app}` map is rejected with 400.
library;

/// util/SystemInfo$DeviceInfo$Display - `{w, h, mm}`.
class DisplayInfo {
  final int w;
  final int h;
  final double mm;

  const DisplayInfo({this.w = 0, this.h = 0, this.mm = 0});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'w': w,
        'h': h,
        'mm': mm,
      };
}

/// util/SystemInfo$MemInfo - the ActivityManager.MemoryInfo fields Gson sees.
class MemInfo {
  final int availMem;
  final int totalMem;
  final int threshold;
  final bool lowMemory;

  const MemInfo({
    this.availMem = 0,
    this.totalMem = 0,
    this.threshold = 0,
    this.lowMemory = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'availMem': availMem,
        'totalMem': totalMem,
        'threshold': threshold,
        'lowMemory': lowMemory,
      };
}

/// util/SystemInfo$DeviceInfo.
class DeviceInfo {
  final String model;
  final String manufacturer;
  final String deviceString;
  final String fingerprint;
  final String buildId;
  final String hardware;
  final String product;
  final String cpuABI;
  final String devQueueBuild;
  final DisplayInfo display;
  final MemInfo memory;

  const DeviceInfo({
    this.model = 'xcshare',
    this.manufacturer = 'XCTrack',
    this.deviceString = 'xcshare',
    this.fingerprint = 'xcshare/demo',
    this.buildId = 'demo',
    this.hardware = 'unknown',
    this.product = 'xcshare',
    this.cpuABI = 'arm64-v8a',
    this.devQueueBuild = '',
    this.display = const DisplayInfo(w: 1080, h: 2400, mm: 6.5),
    this.memory = const MemInfo(),
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'model': model,
        'manufacturer': manufacturer,
        'deviceString': deviceString,
        'fingerprint': fingerprint,
        'buildId': buildId,
        'hardware': hardware,
        'product': product,
        'cpuABI': cpuABI,
        'devQueueBuild': devQueueBuild,
        'display': display.toJson(),
        'memory': memory.toJson(),
      };
}

/// util/SystemInfo$OSInfo - `sdk` is `Build.VERSION.SDK_INT`.
class OsInfo {
  final int sdk;
  final String type;
  final String version;
  final String timezone;

  const OsInfo({
    this.sdk = 34,
    this.type = 'Android',
    this.version = '14',
    this.timezone = 'GMT',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sdk': sdk,
        'type': type,
        'version': version,
        'timezone': timezone,
      };
}

/// util/SystemInfo$XCTrackInfo.
class XCTrackInfo {
  final String name;
  final String versionName;
  final int versionCode;

  const XCTrackInfo({
    this.name = 'XCTrack',
    this.versionName = '0.9.12.6',
    this.versionCode = 1,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'versionName': versionName,
        'versionCode': versionCode,
      };
}

/// TracklogWriter$IGCSystemInfo. `deviceId` is pref t0.o0 in the APK
/// (TracklogWriter$IGCSystemInfo.smali:110-131).
class IgcSystemInfo {
  final String deviceId;
  final DeviceInfo device;
  final OsInfo os;
  final XCTrackInfo app;

  const IgcSystemInfo({
    this.deviceId = 'xcshare-demo',
    this.device = const DeviceInfo(),
    this.os = const OsInfo(),
    this.app = const XCTrackInfo(),
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'device': device.toJson(),
        'os': os.toJson(),
        'app': app.toJson(),
      };
}
