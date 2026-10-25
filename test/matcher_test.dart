import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:resq/core/geo.dart';
import 'package:resq/domain/dispatch/matcher.dart';
import 'package:resq/domain/models.dart';
import 'package:resq/domain/world.dart';

const _now = 1700000000000;
const _center = GeoPoint(19.076, 72.8777);

class FakeWorld implements WorldView {
  FakeWorld({required this.beacons, required this.sos, this.hazardList = const []});

  @override
  final Map<String, BeaconRecord> beacons;
  final List<SosRecord> sos;
  final List<HazardRecord> hazardList;

  @override
  int get nowMs => _now;
  @override
  String get selfId => 'observer';
  @override
  // No observer position: keeps the hop-plausibility check out of matcher tests.
  LocationFix? get selfLocation => null;
  @override
  Iterable<SosRecord> get sosRecords => sos;
  @override
  List<SosEventRecord> eventsFor(String sosId) => const [];
  @override
  Iterable<HazardRecord> get hazards => hazardList;
  @override
  List<VouchRecord> vouchesFor(String subject) => const [];
  @override
  Set<String> get anchors => const {};
  @override
  Set<String> get revokedCredentialIds => const {};
  @override
  Map<String, Set<String>> get directIdentitiesByEndpoint => const {};
  @override
  int? firstSeenMs(String identity) => _now - 3600000;
  @override
  Map<String, String> get penalties => const {};
}

BeaconRecord _responder(String id, Set<Capability> caps, GeoPoint at) => BeaconRecord(
      origin: id,
      role: NodeRole.responder,
      declaredCaps: caps,
      available: true,
      encKey: 'k' * 43,
      name: id,
      claimedAtMs: _now,
      receivedAtMs: _now,
      hop: 1,
      batteryPct: 80,
      location: LocationFix(point: at, accuracyM: 50, fixedAtMs: _now),
    );

SosRecord _sos(String id, Urgency u, Set<Need> needs, GeoPoint at) => SosRecord(
      id: id.padRight(32, '0'),
      origin: 'victim-$id',
      claimedAtMs: _now - 30000,
      receivedAtMs: _now - 25000,
      hopAtReceipt: 1,
      urgency: u,
      needs: needs,
      sealed: false,
      readable: true,
      location: LocationFix(point: at, accuracyM: 30, fixedAtMs: _now - 30000),
    );

void main() {
  const matcher = Matcher();

  test('opportunity cost: the only medic goes to the critical case, even if the minor one is closer', () {
    final minor = _sos('minor', Urgency.low, {Need.supplies}, _center.offset(50, 0));
    final critical = _sos('crit', Urgency.critical, {Need.medical}, _center.offset(900, 0));
    final world = FakeWorld(
      beacons: {
        'medic': _responder('medic', {Capability.medicalAdvanced}, _center),
        'driver': _responder('driver', {Capability.vehicle, Capability.supplies}, _center.offset(400, 0)),
      },
      sos: [minor, critical],
    );
    final plan = matcher.plan(openSos: [minor, critical], view: world, excluded: const {}, busyResponders: const {});
    expect(plan.assignments[critical.id]!.primary, 'medic');
    expect(plan.assignments[minor.id]!.primary, 'driver');
  });

  test('bystander: one primary per SOS, not everyone', () {
    final s = _sos('one', Urgency.high, {Need.trapped}, _center);
    final beacons = {
      for (var i = 0; i < 10; i++) 'r$i': _responder('r$i', {Capability.searchRescue}, _center.offset(i * 50.0, 0)),
    };
    final plan = matcher.plan(openSos: [s], view: FakeWorld(beacons: beacons, sos: [s]), excluded: const {}, busyResponders: const {});
    expect(plan.assignments.length, 1);
  });

  test('flood lure: SOS inside high-confidence flood zone is never offered to unequipped responders', () {
    final inFlood = _sos('flood', Urgency.critical, {Need.medical}, _center);
    final hazards = [
      for (var i = 0; i < 3; i++)
        HazardRecord(
          id: 'h$i',
          origin: 'reporter$i',
          kind: HazardKind.flood,
          center: _center,
          radiusM: 300,
          severity: 3,
          claimedAtMs: _now,
          receivedAtMs: _now,
        ),
    ];
    final world = FakeWorld(
      beacons: {
        'nurse-on-foot': _responder('nurse-on-foot', {Capability.medicalAdvanced}, _center.offset(500, 0)),
        'boat': _responder('boat', {Capability.boat}, _center.offset(800, 0)),
      },
      sos: [inFlood],
      hazardList: hazards,
    );
    final plan = matcher.plan(openSos: [inFlood], view: world, excluded: const {}, busyResponders: const {});
    expect(plan.assignments[inFlood.id]?.primary, 'boat');
    expect(plan.results[(inFlood.id, 'nurse-on-foot')]!.eligible, isFalse);
  });

  test('declined / lapsed responders are excluded and the offer rolls over', () {
    final s = _sos('roll', Urgency.high, {Need.trapped}, _center);
    final world = FakeWorld(beacons: {
      'a': _responder('a', {Capability.searchRescue}, _center),
      'b': _responder('b', {Capability.searchRescue}, _center.offset(300, 0)),
    }, sos: [s]);
    final first = matcher.plan(openSos: [s], view: world, excluded: const {}, busyResponders: const {});
    final second = matcher.plan(openSos: [s], view: world, excluded: {s.id: {first.assignments[s.id]!.primary}}, busyResponders: const {});
    expect(second.assignments[s.id]!.primary, isNot(first.assignments[s.id]!.primary));
  });

  test('evaluation chain stages run in the problem-statement order', () {
    final s = _sos('order', Urgency.high, {Need.trapped}, _center);
    final world = FakeWorld(beacons: {'a': _responder('a', {Capability.searchRescue}, _center)}, sos: [s]);
    final plan = matcher.plan(openSos: [s], view: world, excluded: const {}, busyResponders: const {});
    expect(plan.results[(s.id, 'a')]!.stages.map((x) => x.name).toList(), [
      'CLAIM VERIFICATION',
      'HAZARD AVOIDANCE',
      'TRUST SCORING',
      'BATTERY / ROUTING COST',
      'SAFE DISPATCH',
    ]);
  });
}
