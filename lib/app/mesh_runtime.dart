import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

import '../device/alerts.dart';
import '../device/device_services.dart';
import '../domain/models.dart';
import '../domain/reconcile/reconciler.dart';
import '../node/resq_node.dart';

/// Device-side runtime for the mesh. It deliberately lives outside the widget
/// tree: when Android restarts the process for the foreground service there is
/// no screen, yet the mesh, its timers and alerts must keep working.
class MeshRuntime {
  MeshRuntime({
    required this.node,
    required this.battery,
    required this.location,
    required this.permissions,
    required this.foreground,
    required this.alerts,
  });

  final ResqNode node;
  final BatteryService battery;
  final LocationService location;
  final PermissionsService permissions;
  final ForegroundService foreground;
  final AlertService alerts;

  bool meshOn = false;
  bool busy = false;
  bool foregroundRunning = false;
  PermissionSummary? permissionSummary;
  LocationStatus? locationStatus;
  LocationFix? lastFix;

  /// Phone radios switched off; Nearby can't work until they're on.
  bool bluetoothOff = false;
  bool locationServicesOff = false;

  final StreamController<void> _changes = StreamController.broadcast();
  Stream<void> get changes => _changes.stream;

  Timer? _tick;
  Timer? _battery;
  Timer? _health;
  StreamSubscription<void>? _nodeSub;

  // Alert bookkeeping: seeded on start so a restart doesn't re-alert old items.
  final Set<String> _alertedOffers = {};
  final Map<String, SosPhase> _knownPhases = {};
  final Set<String> _alertedStandDowns = {};
  bool _alertsSeeded = false;

  static const String _meshEnabledKey = 'mesh_enabled';

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Starts timers and restores the mesh if the user had it on.
  Future<void> start() async {
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(node.tick()));
    _battery = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(_readBattery()));
    _health = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_checkRadioHealth()));
    _nodeSub = node.changes.listen((_) => _checkAlerts());
    await _readBattery();
    permissionSummary = await permissions.status();
    await _checkRadioHealth();
    _seedAlerts();
    if (node.store.getMeta(_meshEnabledKey) == 'true' && (permissionSummary?.radioGranted ?? false)) {
      await _startMesh();
    }
    _changed();
  }

  Future<void> _readBattery() async => node.setRealBattery(await battery.level());

  Future<void> _checkRadioHealth() async {
    try {
      bluetoothOff = await Permission.bluetooth.serviceStatus == ServiceStatus.disabled;
      locationServicesOff = await Permission.location.serviceStatus == ServiceStatus.disabled;
    } on Object {
      // Service status unavailable on this platform: don't claim either way.
    }
    _changed();
  }

  /// Turns the mesh on. Permissions are requested here, when the user asks
  /// for the feature, never silently at first launch.
  Future<void> enableMesh() async {
    busy = true;
    _changed();
    permissionSummary = await permissions.requestMesh();
    if (permissionSummary!.radioGranted) {
      await node.store.putMeta(_meshEnabledKey, 'true');
      await _startMesh();
      unawaited(refreshLocation(request: false));
    }
    busy = false;
    await _checkRadioHealth();
    _changed();
  }

  Future<void> _startMesh() async {
    await node.start();
    foregroundRunning = await foreground.start();
    meshOn = true;
    await node.tick();
  }

  Future<void> disableMesh() async {
    await node.store.putMeta(_meshEnabledKey, 'false');
    await node.stop();
    await foreground.stop();
    meshOn = false;
    foregroundRunning = false;
    _changed();
  }

  Future<LocationFix?> refreshLocation({bool request = true}) async {
    final (fix, status) = await location.currentFix(request: request);
    if (fix != null) lastFix = fix;
    node.setSelfLocation(lastFix);
    locationStatus = status;
    _changed();
    return fix;
  }

  Future<void> openSettings() => permissions.openSettings();

  // ---------------------------------------------------------------------
  // Alerts: new offer for a responder, status changes for a victim,
  // stand-down notices. Phone alerts work even with the screen off.
  // ---------------------------------------------------------------------

  void _seedAlerts() {
    _alertedOffers.addAll(node.myOffers.map((o) => o.assignment.sos.id));
    for (final m in node.mySos) {
      _knownPhases[m.sos.id] = m.state.phase;
    }
    _alertedStandDowns.addAll(node.myEngagements.where((e) => e.standDown).map((e) => e.sos.id));
    _alertsSeeded = true;
  }

  void _checkAlerts() {
    if (!_alertsSeeded) return;
    for (final o in node.myOffers) {
      final s = o.assignment.sos;
      if (_alertedOffers.add(s.id)) {
        final needs = s.needs.isEmpty ? 'NEED UNCLEAR' : s.needs.map((n) => n.label).join(' + ');
        unawaited(alerts.notify(_alertId(s.id, 1), 'SOS MATCHED TO YOU — ${s.urgency.label} · $needs', o.justification));
      }
    }
    for (final m in node.mySos) {
      final before = _knownPhases[m.sos.id];
      final now = m.state.phase;
      _knownPhases[m.sos.id] = now;
      if (before == null || before == now) continue;
      final text = switch (now) {
        SosPhase.accepted => 'A responder accepted. Departure not confirmed yet.',
        SosPhase.enRoute => 'Your responder reports they are on the way.',
        SosPhase.onScene => 'Your responder reports they are on scene.',
        SosPhase.searching => 'Responder lost contact. Searching for another responder.',
        _ => null,
      };
      if (text != null) unawaited(alerts.notify(_alertId(m.sos.id, 2), 'RESQ — ${now.label}', text));
    }
    for (final e in node.myEngagements) {
      if (e.standDown && _alertedStandDowns.add(e.sos.id)) {
        unawaited(alerts.notify(_alertId(e.sos.id, 3), 'STAND DOWN', 'Another responder has precedence for this request.'));
      }
    }
  }

  int _alertId(String sosId, int kind) => (sosId.hashCode & 0x0FFFFFFF) * 4 + kind;

  Future<void> dispose() async {
    _tick?.cancel();
    _battery?.cancel();
    _health?.cancel();
    await _nodeSub?.cancel();
    await _changes.close();
  }
}
