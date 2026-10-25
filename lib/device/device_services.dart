import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/geo.dart';
import '../domain/models.dart';

/// Real battery telemetry. Read failures are reported as unknown (null), never
/// replaced with an invented value.
class BatteryService {
  final Battery _battery = Battery();

  Future<int?> level() async {
    try {
      final l = await _battery.batteryLevel;
      return l >= 0 && l <= 100 ? l : null;
    } on Object {
      return null;
    }
  }
}

enum LocationStatus {
  ok('LOCATION OK'),
  serviceOff('LOCATION SERVICES OFF'),
  denied('LOCATION NOT PROVIDED — PERMISSION DENIED'),
  deniedForever('LOCATION BLOCKED — ENABLE IN SETTINGS'),
  timeout('LOCATION UNAVAILABLE — NO FIX'),
  error('LOCATION ERROR');

  const LocationStatus(this.label);

  final String label;
}

/// Opt-in GPS. Returns accuracy and timestamp with every fix; missing location
/// is a supported state.
class LocationService {
  Future<(LocationFix?, LocationStatus)> currentFix({bool request = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return (null, LocationStatus.serviceOff);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && request) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return (null, LocationStatus.denied);
      if (perm == LocationPermission.deniedForever) return (null, LocationStatus.deniedForever);
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      return (
        LocationFix(
          point: GeoPoint(pos.latitude, pos.longitude),
          accuracyM: pos.accuracy,
          fixedAtMs: pos.timestamp.millisecondsSinceEpoch,
        ),
        LocationStatus.ok,
      );
    } on Object catch (e) {
      return (null, e.toString().toLowerCase().contains('timeout') ? LocationStatus.timeout : LocationStatus.error);
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}

class PermissionSummary {
  const PermissionSummary(this.statuses);

  final Map<Permission, PermissionStatus> statuses;

  bool _ok(Permission p) {
    final s = statuses[p];
    return s == null || s.isGranted || s.isLimited || s.isRestricted;
  }

  /// The Bluetooth permissions are the hard requirement for Nearby
  /// Connections (on Android 11 and below they report granted automatically).
  /// Location and Wi-Fi peers improve discovery but don't block the mesh;
  /// a missing one is surfaced as a warning instead.
  bool get radioGranted =>
      _ok(Permission.bluetoothScan) && _ok(Permission.bluetoothAdvertise) && _ok(Permission.bluetoothConnect);

  List<String> get warnings => [
        if (!_ok(Permission.locationWhenInUse)) 'LOCATION DENIED — discovery may fail on Android 11 and below',
        if (!_ok(Permission.nearbyWifiDevices)) 'NEARBY WI-FI DENIED — Bluetooth only, shorter range',
        if (!_ok(Permission.notification)) 'NOTIFICATIONS DENIED — no alert sound for new requests',
      ];

  bool get anyPermanentlyDenied => statuses.values.any((s) => s.isPermanentlyDenied);

  String get label => radioGranted
      ? (warnings.isEmpty ? 'NEARBY ACCESS GRANTED' : 'NEARBY ACCESS GRANTED (LIMITED)')
      : (anyPermanentlyDenied ? 'NEARBY ACCESS BLOCKED — OPEN SETTINGS' : 'NEARBY ACCESS NOT GRANTED');
}

/// Requests only what the mesh needs, at the moment the user turns it on.
class PermissionsService {
  static const List<Permission> meshPermissions = [
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.nearbyWifiDevices,
    Permission.locationWhenInUse,
    Permission.notification,
  ];

  Future<PermissionSummary> status() async =>
      PermissionSummary({for (final p in meshPermissions) p: await p.status});

  Future<PermissionSummary> requestMesh() async => PermissionSummary(await meshPermissions.request());

  Future<bool> openSettings() => openAppSettings();
}

/// Android foreground service (native, see MeshForegroundService.kt) that keeps
/// the process — and so the mesh — alive with the screen off. Where the OS or
/// OEM still stops it, the UI says BACKGROUND DISCOVERY NOT ACTIVE.
class ForegroundService {
  static const MethodChannel _channel = MethodChannel('resq/foreground');

  bool _running = false;
  bool get running => _running;

  Future<bool> start() async {
    try {
      _running = await _channel.invokeMethod<bool>('start') ?? false;
    } on Object {
      _running = false;
    }
    return _running;
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } on Object {
      // not running
    }
    _running = false;
  }
}
