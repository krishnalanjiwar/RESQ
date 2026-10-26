@Timeout(Duration(minutes: 10))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:resq/sim/simulator.dart';

/// End-to-end Red Team Hour scenarios on the simulator. Each runs real
/// ResqNode instances over the simulated radio and asserts measured outcomes.
void main() {
  late Simulator sim;

  setUp(() async => sim = await Simulator.build(relays: 6, responders: 6, victims: 3));
  tearDown(() => sim.dispose());

  test('SOS propagates multi-hop and a responder accepts after a human-style decision', () async {
    await sim.reportFlood();
    await sim.seedEmergencies();
    await sim.run(12);
    final states = sim.observer.node.states.values;
    expect(states, isNotEmpty);
    expect(states.any((s) => s.primary != null || s.phase.name == 'resolved'), isTrue);
  });

  test('Sybil: 40 fake nurses are never assigned', () async {
    await sim.seedEmergencies();
    final r = await sim.attackSybil();
    expect(r.outcome, isNot(AttackOutcome.notBlocked), reason: r.details.join('\n'));
  });

  test('Sybil posing as a relay (forged hop count) is never assigned', () async {
    await sim.seedEmergencies();
    final r = await sim.attackSybil(forgeHop: true);
    expect(r.outcome, isNot(AttackOutcome.notBlocked), reason: r.details.join('\n'));
  });

  test('forged credential is quarantined', () async {
    final r = await sim.attackForgedCredential();
    expect(r.outcome, AttackOutcome.quarantined, reason: r.details.join('\n'));
  });

  test('spoofed location is flagged', () async {
    final r = await sim.attackSpoofedLocation();
    expect(r.outcome, AttackOutcome.flagged, reason: r.details.join('\n'));
  });

  test('floodwater lure never sends unequipped responders', () async {
    final r = await sim.attackFloodLure();
    expect(r.outcome, AttackOutcome.blocked, reason: r.details.join('\n'));
  });

  test('battery-drain flood is quarantined at the link', () async {
    final r = await sim.attackBatteryDrain();
    expect(r.outcome, AttackOutcome.quarantined, reason: r.details.join('\n'));
  });

  test('partition double-dispatch converges after merge', () async {
    await sim.partitionDoubleDispatchScenario();
    await sim.togglePartition(); // heal
    await sim.run(4);
    for (final s in sim.observer.node.states.values) {
      final active = s.tracks.values
          .where((t) => t.progress > 0 && !t.withdrawn && !s.orphaned.contains(t.responder))
          .toList();
      if (active.length <= 1) continue;
      // More than one responder holds the SOS: either all but one were told to
      // stand down, or several are already on scene (kept, reported as conflict).
      expect(
        s.standDown.length == active.length - 1 || s.conflicts.contains('MULTIPLE_ON_SCENE'),
        isTrue,
        reason: '${s.sosId}: ${s.conflicts}',
      );
      for (final t in active.where((t) => t.progress >= 3)) {
        expect(s.standDown.contains(t.responder), isFalse, reason: 'never cancel a responder at the door');
      }
    }
  });
}
