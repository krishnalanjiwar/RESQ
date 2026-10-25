import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_services.dart';
import '../domain/models.dart';
import '../node/resq_node.dart';
import '../sim/simulator.dart';
import 'bootstrap.dart';

/// Overridden in main() with the bootstrapped services.
final appServicesProvider = Provider<AppServices>((ref) => throw UnimplementedError('bootstrap first'));

final nodeProvider = Provider<ResqNode>((ref) => ref.watch(appServicesProvider).node);

/// Emits the node's version on every state change; widgets watch this to rebuild.
final nodeVersionProvider = StreamProvider<int>((ref) {
  final node = ref.watch(nodeProvider);
  return node.changes.map((_) => node.version);
});

class DeviceState {
  const DeviceState({
    this.meshOn = false,
    this.permissions,
    this.locationStatus,
    this.lastFix,
    this.foregroundRunning = false,
    this.busy = false,
  });

  final bool meshOn;
  final PermissionSummary? permissions;
  final LocationStatus? locationStatus;
  final LocationFix? lastFix;
  final bool foregroundRunning;
  final bool busy;

  DeviceState copyWith({
    bool? meshOn,
    PermissionSummary? permissions,
    LocationStatus? locationStatus,
    LocationFix? lastFix,
    bool? foregroundRunning,
    bool? busy,
  }) =>
      DeviceState(
        meshOn: meshOn ?? this.meshOn,
        permissions: permissions ?? this.permissions,
        locationStatus: locationStatus ?? this.locationStatus,
        lastFix: lastFix ?? this.lastFix,
        foregroundRunning: foregroundRunning ?? this.foregroundRunning,
        busy: busy ?? this.busy,
      );
}

/// Owns device timers (node tick, battery polling) and the mesh on/off flow.
class DeviceController extends Notifier<DeviceState> {
  Timer? _tick;
  Timer? _battery;

  AppServices get _s => ref.read(appServicesProvider);

  @override
  DeviceState build() {
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_s.node.tick()));
    _battery = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(_readBattery()));
    unawaited(_readBattery());
    unawaited(_loadPermissions());
    ref.onDispose(() {
      _tick?.cancel();
      _battery?.cancel();
    });
    return const DeviceState();
  }

  Future<void> _readBattery() async => _s.node.setRealBattery(await _s.battery.level());

  Future<void> _loadPermissions() async {
    state = state.copyWith(permissions: await _s.permissions.status());
  }

  /// Turns the radio mesh on. Permissions are requested here, when the user
  /// asks for the feature, never silently at first launch.
  Future<void> enableMesh() async {
    state = state.copyWith(busy: true);
    final perms = await _s.permissions.requestMesh();
    state = state.copyWith(permissions: perms);
    if (!perms.radioGranted) {
      state = state.copyWith(busy: false);
      return;
    }
    await _s.node.start();
    final fg = await _s.foreground.start();
    state = state.copyWith(meshOn: true, foregroundRunning: fg, busy: false);
    unawaited(refreshLocation(request: false));
    await _s.node.tick();
  }

  Future<void> disableMesh() async {
    await _s.node.stop();
    await _s.foreground.stop();
    state = state.copyWith(meshOn: false, foregroundRunning: false);
  }

  Future<LocationFix?> refreshLocation({bool request = true}) async {
    final (fix, status) = await _s.location.currentFix(request: request);
    _s.node.setSelfLocation(fix ?? state.lastFix);
    state = state.copyWith(locationStatus: status, lastFix: fix);
    return fix;
  }

  Future<void> openSettings() => _s.permissions.openSettings();
}

final deviceControllerProvider = NotifierProvider<DeviceController, DeviceState>(DeviceController.new);

// ---------------------------------------------------------------------------
// Simulator (Diagnostics only)
// ---------------------------------------------------------------------------

class SimState {
  const SimState({this.sim, this.running = false, this.busy = false, this.version = 0, this.error});

  final Simulator? sim;
  final bool running;
  final bool busy;
  final int version;
  final String? error;

  SimState copyWith({Simulator? sim, bool? running, bool? busy, int? version, String? error, bool clearSim = false}) =>
      SimState(
        sim: clearSim ? null : (sim ?? this.sim),
        running: running ?? this.running,
        busy: busy ?? this.busy,
        version: version ?? this.version,
        error: error,
      );
}

class SimController extends Notifier<SimState> {
  Timer? _auto;
  bool _stepping = false;

  @override
  SimState build() {
    ref.onDispose(() {
      _auto?.cancel();
      unawaited(state.sim?.dispose());
    });
    return const SimState();
  }

  void _bump() => state = state.copyWith(version: state.version + 1);

  Future<void> _guard(Future<void> Function(Simulator sim) action) async {
    final sim = state.sim;
    if (sim == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await action(sim);
    } on Object catch (e) {
      state = state.copyWith(error: e.toString());
    }
    state = state.copyWith(busy: false, version: state.version + 1);
  }

  Future<void> buildCity() async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    await state.sim?.dispose();
    try {
      final sim = await Simulator.build();
      state = SimState(sim: sim, version: state.version + 1);
    } on Object catch (e) {
      state = SimState(error: 'build failed: $e');
    }
  }

  Future<void> step() => _guard((s) => s.step());

  void toggleRun() {
    if (state.running) {
      _auto?.cancel();
      state = state.copyWith(running: false);
      return;
    }
    state = state.copyWith(running: true);
    _auto = Timer.periodic(const Duration(milliseconds: 900), (_) async {
      final sim = state.sim;
      if (sim == null || _stepping || state.busy) return;
      _stepping = true;
      await sim.step();
      _stepping = false;
      _bump();
    });
  }

  Future<void> reportFlood() => _guard((s) => s.reportFlood());
  Future<void> seedEmergencies() => _guard((s) => s.seedEmergencies());
  Future<void> togglePartition() => _guard((s) => s.togglePartition());
  Future<void> partitionScenario() => _guard((s) => s.partitionDoubleDispatchScenario());
  Future<void> sybil() => _guard((s) async => s.attackSybil());
  Future<void> forgedCredential() => _guard((s) async => s.attackForgedCredential());
  Future<void> spoofedLocation() => _guard((s) async => s.attackSpoofedLocation());
  Future<void> floodLure() => _guard((s) async => s.attackFloodLure());
  Future<void> batteryDrainAttack() => _guard((s) async => s.attackBatteryDrain());
  Future<void> drainRelayBatteries(int? level) => _guard((s) async => s.setRelayBatteryOverride(level));

  Future<void> reset() async {
    _auto?.cancel();
    await state.sim?.dispose();
    state = SimState(version: state.version + 1);
  }
}

final simControllerProvider = NotifierProvider<SimController, SimState>(SimController.new);
