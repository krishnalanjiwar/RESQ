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
  Timer? _arrival;
  StreamSubscription<void>? _nodeSub;

  // Alert bookkeeping: seeded on start so a restart doesn't re-alert old items.
  final Set<String> _alertedOffers = {};
  final Map<String, SosPhase> _knownPhases = {};
  final Set<String> _alertedStandDowns = {};
  bool _alertsSeeded = false;

  /// Offers ringing on this (responder) phone until accepted, declined,
  /// silenced or rolled over to someone else.
  final Set<String> _ringingOffers = {};

  /// This requester's SOS whose "help accepted" alarm is still ringing.
  final Set<String> ringingAccepted = {};
  final Map<int, Timer> _ringCaps = {};

  /// No alarm rings forever: it stops on its own after this long.
  static const Duration maxRing = Duration(minutes: 3);

  static const String _meshEnabledKey = 'mesh_enabled';

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Starts timers and restores the mesh if the user had it on.
  Future<void> start() async {
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(node.tick()));
    _battery = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(_readBattery()));
    _health = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_checkRadioHealth()));
    _arrival = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_checkArrival()));
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
    final offered = <String>{};
    for (final o in node.myOffers) {
      final s = o.assignment.sos;
      offered.add(s.id);
      if (_alertedOffers.add(s.id)) {
        final needs = s.needs.isEmpty ? 'NEED UNCLEAR' : s.needs.map((n) => n.label).join(' + ');
        _ringingOffers.add(s.id);
        _ring(_alertId(s.id, 1), '${s.urgency.sosClass} · $needs — RESPOND NOW', o.justification, tapStops: false);
      }
    }
    // Answered, declined or moved on to another responder: stop ringing.
    for (final id in _ringingOffers.where((id) => !offered.contains(id)).toList()) {
      silenceOffer(id);
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
      if (now == SosPhase.onScene) {
        ringingAccepted.add(m.sos.id);
        _ring(_alertId(m.sos.id, 0), 'YOUR VOLUNTEER HAS ARRIVED', 'They report being at your location. Make yourself seen or heard.');
        _changed();
        continue;
      }
      if (now == SosPhase.accepted) {
        final who = m.state.primary == null ? null : node.responderInfo(m.state.primary!);
        final job = who == null ? null : professionOf(who.caps);
        final role = who == null
            ? 'A volunteer'
            : 'A volunteer (${job == 'Volunteer' ? 'general help' : job}${who.verified ? ', verified' : ''})';
        ringingAccepted.add(m.sos.id);
        _ring(_alertId(m.sos.id, 0), 'HELP IS COMING', '$role accepted your SOS. Stay where you are if it is safe.');
        _changed();
        continue;
      }
      if (text != null) unawaited(alerts.notify(_alertId(m.sos.id, 2), 'RES-Q — ${now.label}', text));
    }
    for (final e in node.myEngagements) {
      if (e.standDown && _alertedStandDowns.add(e.sos.id)) {
        unawaited(alerts.notify(_alertId(e.sos.id, 3), 'STAND DOWN', 'Another responder has precedence for this request.'));
      }
    }
  }

  /// While this phone is heading to someone, track GPS and mark the arrival
  /// automatically, so both people know the moment help is at the door.
  Future<void> _checkArrival() async {
    final heading = node.myEngagements.any((e) =>
        e.state.isActive &&
        !e.standDown &&
        e.myProgress >= SosEventKind.accepted.progress &&
        e.myProgress < SosEventKind.onScene.progress);
    if (!heading || !meshOn) return;
    await refreshLocation(request: false);
    for (final id in await node.autoMarkArrivals()) {
      unawaited(alerts.notify(_alertId(id, 4), 'YOU HAVE ARRIVED',
          'Marked ON SCENE automatically from your GPS. The person who asked for help is being alerted.'));
    }
  }

  void _ring(int id, String title, String body, {bool tapStops = true}) {
    unawaited(alerts.ring(id, title, body, tapStops: tapStops));
    _ringCaps.remove(id)?.cancel();
    _ringCaps[id] = Timer(maxRing, () => _stopRing(id));
  }

  void _stopRing(int id) {
    _ringCaps.remove(id)?.cancel();
    unawaited(alerts.stopRing(id));
  }

  bool isOfferRinging(String sosId) => _ringingOffers.contains(sosId);

  /// Responder silenced the alarm (or answered). The offer itself stays.
  void silenceOffer(String sosId) {
    if (_ringingOffers.remove(sosId)) _stopRing(_alertId(sosId, 1));
    _changed();
  }

  /// Requester saw that help accepted.
  void acknowledgeAccepted(String sosId) {
    if (ringingAccepted.remove(sosId)) _stopRing(_alertId(sosId, 0));
    _changed();
  }

  int _alertId(String sosId, int kind) => (sosId.hashCode & 0x0FFFFFFF) * 8 + kind;

  Future<void> dispose() async {
    _tick?.cancel();
    _battery?.cancel();
    _health?.cancel();
    _arrival?.cancel();
    for (final t in _ringCaps.values) {
      t.cancel();
    }
    await _nodeSub?.cancel();
    await _changes.close();
  }
}
