import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_permissions.dart';
import 'ble_support.dart';
import 'ble_uuids.dart';
import 'sensor_readings.dart';

/// Bluetooth (BLE) external sensor service — a single shared instance.
///
/// Responsibilities: scan for nearby BLE devices, connect to the selected one,
/// discover GATT services and subscribe to notify/indicate characteristics,
/// decode standard GATT (battery/heart rate) and serial-style NMEA (LK8EX1)
/// sentences, and expose the latest [SensorReadings] to the UI.
///
/// Platform behavior:
/// - **iOS / Android**: full BLE functionality.
/// - **Windows / desktop / web**: every method is a guarded no-op so the app
///   compiles and runs without a native BLE plugin. [supported] is false and
///   the UI shows an "unsupported platform" notice instead of scan controls.
///
/// Design:
/// - Single-device model (a flight typically uses one external vario).
/// - The selected device's remoteId is persisted so it can auto-reconnect.
/// - The persisted device uses the platform's native `autoConnect`, so it
///   reconnects immediately the moment it becomes available again — even if it
///   was out of range for a long time (no fixed retry cap).
/// - Manual (user-tapped) connections use a fast, timed connect for a
///   responsive UI, then fall back to `autoConnect` if the device drops.
class BleSensorService extends ChangeNotifier {
  BleSensorService._();
  static final BleSensorService instance = BleSensorService._();

  static const _spDeviceId = 'pb.ble.sensor.device_id';
  static const _spDeviceName = 'pb.ble.sensor.device_name';
  static const _spEnabled = 'pb.ble.sensor.enabled';

  static const _maxReconnectAttempts = 5;
  static const _reconnectBaseDelayMs = 1000;

  /// Whether this platform has a real BLE implementation (iOS/Android only).
  bool get supported => BleSupport.isSupported;

  // ── Adapter / scan state ────────────────────────────────────────────────
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  bool get isAdapterOn => adapterState == BluetoothAdapterState.on;

  bool _scanning = false;
  bool get isScanning => _scanning;

  List<ScanResult> scanResults = const [];

  // ── Connection state ─────────────────────────────────────────────────────
  BluetoothDevice? _device;
  BluetoothDevice? get device => _device;

  /// Display name of the selected device (persisted).
  String? selectedName;

  /// The selected device's remoteId (persisted).
  String? selectedId;

  BluetoothConnectionState connectionState =
      BluetoothConnectionState.disconnected;
  bool get isConnected =>
      connectionState == BluetoothConnectionState.connected;

  /// Latest aggregated readings.
  SensorReadings readings = SensorReadings.empty();

  /// User-facing error (scan/connect failures, unsupported platform, ...).
  String? error;

  /// Master enable toggle (persisted).
  bool _enabled = false;
  bool get enabled => _enabled;

  /// Whether a device has been selected/persisted.
  bool get hasSavedDevice => selectedId != null;

  final StreamController<SensorReadings> _readingsCtrl =
      StreamController<SensorReadings>.broadcast();

  /// Emits whenever new readings arrive.
  Stream<SensorReadings> get readingsStream => _readingsCtrl.stream;

  // ── Internals ─────────────────────────────────────────────────────────────
  final StringBuffer _lineBuffer = StringBuffer();
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  final List<StreamSubscription<List<int>>> _valueSubs = [];

  bool _initialized = false;
  int _reconnectAttempts = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // On unsupported platforms we intentionally do nothing beyond flagging it.
    if (!supported) {
      notifyListeners();
      return;
    }

    // Load persisted state.
    try {
      final sp = await SharedPreferences.getInstance();
      _enabled = sp.getBool(_spEnabled) ?? false;
      selectedId = sp.getString(_spDeviceId);
      selectedName = sp.getString(_spDeviceName);
    } catch (_) {}

    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      adapterState = s;
      notifyListeners();
    });
    _isScanningSub = FlutterBluePlus.isScanning.listen((s) {
      _scanning = s;
      notifyListeners();
    });

    if (_enabled && selectedId != null) {
      // Don't block startup: best-effort background reconnect. Uses native
      // autoConnect so it links up the instant the sensor is available, even
      // if it isn't in range right now.
      unawaited(connectToId(selectedId!, autoConnect: true));
    }
    notifyListeners();
  }

  /// Enables/disables the sensor. Persists the choice and connects/disconnects.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_spEnabled, value);
    } catch (_) {}
    notifyListeners();

    if (!supported) return;
    if (value) {
      if (selectedId != null && !isConnected) {
        _reconnectAttempts = 0;
        // Link up as soon as the saved sensor is available.
        await connectToId(selectedId!, autoConnect: true);
      }
    } else {
      await disconnect();
    }
  }

  // ── Scan ──────────────────────────────────────────────────────────────────
  Future<bool> startScan() async {
    if (!_guard()) return false;

    error = null;
    notifyListeners();

    final granted = await BlePermissions.ensureGranted();
    if (!granted) {
      error = 'Bluetooth permission denied.';
      notifyListeners();
      return false;
    }
    if (await FlutterBluePlus.isSupported == false) {
      error = 'BLE is not supported on this device.';
      notifyListeners();
      return false;
    }
    if (!isAdapterOn) {
      error = 'Please turn on Bluetooth.';
      notifyListeners();
      return false;
    }

    scanResults = const [];
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final filtered = results.where((r) {
        final name = r.advertisementData.advName.trim().isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;
        return name.trim().isNotEmpty;
      }).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      scanResults = filtered;
      notifyListeners();
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      error = 'Scan failed: $e';
      notifyListeners();
    }
    return true;
  }

  Future<void> stopScan() async {
    if (!supported) return;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // ── Connect ─────────────────────────────────────────────────────────────
  /// Connects to [dev].
  ///
  /// When [autoConnect] is true the platform keeps a pending connection and
  /// links up the instant the device becomes available — ideal for the saved
  /// "last connected" sensor, which may currently be out of range. When false
  /// a fast, timed connect is used for a responsive UI (user-tapped devices).
  Future<void> connect(
    BluetoothDevice dev, {
    String? name,
    bool autoConnect = false,
  }) async {
    if (!_guard()) return;

    await stopScan();
    await _teardownConnection();

    _device = dev;
    selectedId = dev.remoteId.str;
    selectedName = name ??
        (dev.platformName.isNotEmpty ? dev.platformName : dev.remoteId.str);
    _reconnectAttempts = 0;
    error = null;
    notifyListeners();

    // Persist so the next launch can auto-reconnect.
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_spDeviceId, selectedId!);
      await sp.setString(_spDeviceName, selectedName!);
    } catch (_) {}

    _connSub = dev.connectionState.listen((s) async {
      connectionState = s;
      notifyListeners();
      if (s == BluetoothConnectionState.connected) {
        _reconnectAttempts = 0;
        await _onConnected();
      } else if (s == BluetoothConnectionState.disconnected) {
        _cancelValueSubs();
        _lineBuffer.clear();
        readings = SensorReadings.empty();
        notifyListeners();
        _maybeReconnect();
      }
    });

    try {
      if (autoConnect) {
        // Native persistent connect: no timeout — links up whenever the
        // device shows up. `mtu` must be null when autoConnect is true.
        await dev.connect(autoConnect: true, mtu: null);
      } else {
        await dev.connect(timeout: const Duration(seconds: 15));
      }
    } catch (e) {
      error = 'Connection failed: $e';
      notifyListeners();
      _maybeReconnect();
    }
  }

  /// Connect directly by remoteId (no scan needed; used for auto-reconnect).
  Future<void> connectToId(String id, {bool autoConnect = false}) async {
    if (!_guard()) return;
    final dev = BluetoothDevice.fromId(id);
    await connect(dev, name: selectedName, autoConnect: autoConnect);
  }

  Future<void> _onConnected() async {
    try {
      final dev = _device;
      if (dev == null) return;

      // A larger MTU lets serial-style sensors push longer NMEA sentences.
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await dev.requestMtu(247);
        } catch (_) {}
      }

      final services = await dev.discoverServices();
      _cancelValueSubs();

      for (final service in services) {
        for (final c in service.characteristics) {
          final props = c.properties;
          if (props.notify || props.indicate) {
            try {
              final sub =
                  c.onValueReceived.listen((value) => _handleValue(c, value));
              _valueSubs.add(sub);
              await c.setNotifyValue(true);
            } catch (e) {
              debugPrint('BleSensorService: subscribe ${c.uuid.str} failed: $e');
            }
          } else if (props.read &&
              BleUuids.same(c.uuid, BleUuids.batteryLevel)) {
            try {
              final value = await c.read();
              _handleValue(c, value);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      error = 'Service discovery failed: $e';
      notifyListeners();
    }
  }

  // ── Decode ────────────────────────────────────────────────────────────────
  void _handleValue(BluetoothCharacteristic c, List<int> value) {
    if (value.isEmpty) return;

    // 1) Standard GATT binary characteristics.
    if (BleUuids.same(c.uuid, BleUuids.batteryLevel)) {
      _apply(SensorParser.parseBatteryLevel(value));
      return;
    }
    if (BleUuids.same(c.uuid, BleUuids.heartRateMeasurement)) {
      _apply(SensorParser.parseHeartRate(value));
      return;
    }

    // 2) Serial / text stream: accumulate and parse complete lines.
    if (SensorParser.looksLikeText(value)) {
      _ingestText(SensorParser.bytesToText(value));
    }
  }

  void _ingestText(String text) {
    _lineBuffer.write(text);
    final buffered = _lineBuffer.toString();
    final lines = buffered.split(RegExp(r'[\r\n]+'));

    // Keep the last possibly-incomplete fragment.
    final incomplete = buffered.endsWith('\n') || buffered.endsWith('\r')
        ? ''
        : lines.removeLast();
    _lineBuffer
      ..clear()
      ..write(incomplete);

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parsed = SensorParser.parseNmeaLine(line);
      if (parsed != null) _apply(parsed);
    }
  }

  void _apply(SensorReadings? r) {
    if (r == null) return;
    readings = readings.merge(r);
    if (!_readingsCtrl.isClosed) _readingsCtrl.add(readings);
    notifyListeners();
  }

  // ── Auto-reconnect ─────────────────────────────────────────────────────────
  void _maybeReconnect() {
    if (!_enabled || _device == null) return;

    // After the quick timed retries are used up, hand off to the platform's
    // persistent autoConnect so the sensor links up the moment it reappears —
    // no matter how long it stays out of range.
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _startAutoConnect();
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: _reconnectBaseDelayMs * (1 << (_reconnectAttempts - 1)),
    );
    Future.delayed(delay, () async {
      if (!_enabled || isConnected || _device == null) return;
      try {
        await _device!.connect(timeout: const Duration(seconds: 15));
      } catch (_) {}
    });
  }

  /// Issues a native persistent connect that resolves whenever the device
  /// becomes available. Safe to call repeatedly.
  void _startAutoConnect() {
    final dev = _device;
    if (dev == null || !_enabled) return;
    () async {
      if (!_enabled || isConnected || _device == null) return;
      try {
        await dev.connect(autoConnect: true, mtu: null);
      } catch (_) {}
    }();
  }

  // ── Disconnect / forget ────────────────────────────────────────────────────
  /// Disconnect but keep the persisted device; stops auto-reconnect.
  Future<void> disconnect() async {
    if (!supported) return;
    _reconnectAttempts = _maxReconnectAttempts; // block auto-reconnect
    await _teardownConnection();
    readings = SensorReadings.empty();
    notifyListeners();
  }

  /// Disconnect and clear the persisted device (no more auto-reconnect).
  Future<void> forgetDevice() async {
    await disconnect();
    _device = null;
    selectedId = null;
    selectedName = null;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_spDeviceId);
      await sp.remove(_spDeviceName);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _teardownConnection() async {
    _cancelValueSubs();
    await _connSub?.cancel();
    _connSub = null;
    _lineBuffer.clear();
    try {
      await _device?.disconnect();
    } catch (_) {}
    connectionState = BluetoothConnectionState.disconnected;
  }

  void _cancelValueSubs() {
    for (final s in _valueSubs) {
      s.cancel();
    }
    _valueSubs.clear();
  }

  /// Guards mobile-only entry points; sets a user-facing error when called on
  /// an unsupported platform. Returns true when it is safe to proceed.
  bool _guard() {
    if (supported) return true;
    error = BleSupport.unsupportedReason;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _teardownConnection();
    _readingsCtrl.close();
    super.dispose();
  }
}
