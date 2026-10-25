import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_services.dart';
import '../domain/models.dart';
import '../node/resq_node.dart';
import '../sim/simulator.dart';
import 'bootstrap.dart';
import 'mesh_runtime.dart';

/// Overridden in main() with the bootstrapped services.
final appServicesProvider = Provider<AppServices>((ref) => throw UnimplementedError('bootstrap first'));

final nodeProvider = Provider<ResqNode>((ref) => ref.watch(appServicesProvider).node);

final meshRuntimeProvider = Provider<MeshRuntime>((ref) => ref.watch(appServicesProvider).runtime);

/// Emits the node's version when its state changes, throttled to at most one
/// event per 250 ms (trailing edge) so a busy mesh doesn't rebuild the UI and
/// re-run the matcher on every received frame.
final nodeVersionProvider = StreamProvider<int>((ref) {
  final node = ref.watch(nodeProvider);
  final controller = StreamController<int>();
  Timer? pending;
  final sub = node.changes.listen((_) {
    pending ??= Timer(const Duration(milliseconds: 250), () {
      pending = null;
      if (!controller.isClosed) controller.add(node.version);
    });
  });
  ref.onDispose(() {
    pending?.cancel();
    unawaited(sub.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

/// Snapshot of the device runtime for the UI.
class DeviceState {
  const DeviceState({
    required this.meshOn,
    required this.permissions,
    required this.locationStatus,
    required this.lastFix,
    required this.foregroundRunning,
    required this.busy,
    required this.bluetoothOff,
    required this.locationServicesOff,
  });

  factory DeviceState.of(MeshRuntime r) => DeviceState(
        meshOn: r.meshOn,
        permissions: r.permissionSummary,
        locationStatus: r.locationStatus,
        lastFix: r.lastFix,
        foregroundRunning: r.foregroundRunning,
        busy: r.busy,
        bluetoothOff: r.bluetoothOff,
        locationServicesOff: r.locationServicesOff,
      );

  final bool meshOn;
  final PermissionSummary? permissions;
  final LocationStatus? locationStatus;
  final LocationFix? lastFix;
  final bool foregroundRunning;
  final bool busy;
  final bool bluetoothOff;
  final bool locationServicesOff;
}

/// Thin UI adapter over [MeshRuntime], which owns the mesh lifecycle outside
/// the widget tree.
class DeviceController extends Notifier<DeviceState> {
  MeshRuntime get _r => ref.read(meshRuntimeProvider);

  @override
  DeviceState build() {
    final runtime = ref.watch(meshRuntimeProvider);
    final sub = runtime.changes.listen((_) => state = DeviceState.of(runtime));
    ref.onDispose(() => unawaited(sub.cancel()));
    return DeviceState.of(runtime);
  }

  Future<void> enableMesh() => _r.enableMesh();

  Future<void> disableMesh() => _r.disableMesh();

  Future<LocationFix?> refreshLocation({bool request = true}) => _r.refreshLocation(request: request);

  Future<void> openSettings() => _r.openSettings();
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

  /// Kept outside `state` because Riverpod forbids reading state in onDispose.
  Simulator? _current;

  @override
  set state(SimState value) {
    _current = value.sim;
    super.state = value;
  }

  @override
  SimState build() {
    ref.onDispose(() {
      _auto?.cancel();
      unawaited(_current?.dispose());
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
