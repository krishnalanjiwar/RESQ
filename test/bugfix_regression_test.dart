@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:resq/core/geo.dart';
import 'package:resq/domain/dispatch/matcher.dart';
import 'package:resq/domain/models.dart';
import 'package:resq/domain/trust/trust_agent.dart';
import 'package:resq/domain/world.dart';
import 'package:resq/protocol/flow_control.dart';
import 'package:resq/protocol/limits.dart';
import 'package:resq/sim/simulator.dart';

const _now = 1700000000000;
const _center = GeoPoint(19.076, 72.8777);

class _World implements WorldView {
  _World({
    required this.beacons,
    this.sos = const [],
    this.anchors = const {},
    this.firstSeen = const {},
  });

  @override
  final Map<String, BeaconRecord> beacons;
  final List<SosRecord> sos;
  @override
  final Set<String> anchors;
  final Map<String, int> firstSeen;

  @override
  int get nowMs => _now;
  @override
  String get selfId => 'observer';
  @override
  LocationFix? get selfLocation => null;
  @override
  Iterable<SosRecord> get sosRecords => sos;
  @override
  List<SosEventRecord> eventsFor(String sosId) => const [];
  @override
  Iterable<HazardRecord> get hazards => const [];
  @override
  List<VouchRecord> vouchesFor(String subject) => const [];
  @override
  Set<String> get revokedCredentialIds => const {};
  @override
  Map<String, Set<String>> get directIdentitiesByEndpoint => const {};
  @override
  int? firstSeenMs(String identity) => firstSeen[identity] ?? _now - 3600000;
  @override
  Map<String, String> get penalties => const {};
}

BeaconRecord _beacon(String id, Set<Capability> caps, GeoPoint at, {Credential? cred, String via = 'link-1'}) => BeaconRecord(
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
      location: LocationFix(point: at, accuracyM: 20, fixedAtMs: _now),
      credential: cred,
      credentialSignatureValid: cred != null,
      viaEndpoint: via,
    );

Credential _cred(String subject) => Credential(
      cid: subject.padRight(32, '0'),
      subject: subject,
      roles: {Capability.medicalAdvanced},
      issuedAtMs: _now - 1000,
      expiresAtMs: _now + 86400000,
      issuer: 'authority',
      issuerName: 'TEST AUTHORITY',
      sig: 'x',
    );

SosRecord _sos(String id, {String origin = 'victim', bool sealed = false}) => SosRecord(
      id: id.padRight(32, '0'),
      origin: origin,
      claimedAtMs: _now - 10000,
      receivedAtMs: _now - 9000,
      hopAtReceipt: 1,
      urgency: Urgency.critical,
      needs: {Need.medical},
      sealed: sealed,
      readable: !sealed,
      location: LocationFix(point: _center, accuracyM: 20, fixedAtMs: _now - 10000),
    );

void main() {
  const matcher = Matcher();

  test('C1: a full store-and-forward replay from an honest peer is not treated as flooding', () {
    final guard = FloodGuard(
      capacity: Limits.linkBurst,
      refillPerSecond: Limits.linkMessagesPerSecond,
      strikesBeforeQuarantine: Limits.linkStrikesBeforeQuarantine,
      quarantine: Limits.linkQuarantine,
    );
    // hello + full sync batch, all in the same instant.
    for (var i = 0; i < Limits.syncBatchMax + 2; i++) {
      expect(guard.check('honest-peer', _now), isNull, reason: 'frame $i');
    }
    expect(guard.isQuarantined('honest-peer', _now), isFalse);
  });

  test('C4: a sealed SOS is never offered to an unverified responder', () {
    final sealed = _sos('sealed', sealed: true);
    final world = _World(
      beacons: {
        'unverified': _beacon('unverified', {Capability.medicalAdvanced}, _center),
        'verified': _beacon('verified', {Capability.medicalAdvanced}, _center.offset(600, 0), cred: _cred('verified')),
      },
      sos: [sealed],
      anchors: {'authority'},
    );
    final plan = matcher.plan(openSos: [sealed], view: world, excluded: const {}, busyResponders: const {});
    expect(plan.assignments[sealed.id]!.primary, 'verified');
    expect(plan.results[(sealed.id, 'unverified')]!.eligible, isFalse);
  });

  test('L1: a responder is never matched to their own SOS', () {
    final own = _sos('own', origin: 'medic');
    final world = _World(beacons: {'medic': _beacon('medic', {Capability.medicalAdvanced}, _center)}, sos: [own]);
    final plan = matcher.plan(openSos: [own], view: world, excluded: const {}, busyResponders: const {});
    expect(plan.assignments.containsKey(own.id), isFalse);
  });

  group('M4: co-location Sybil heuristic', () {
    test('identical unverified clones near each other are flagged', () {
      final beacons = {
        for (var i = 0; i < 5; i++) 'clone$i': _beacon('clone$i', {Capability.medicalAdvanced}, _center.offset(i * 2.0, 0)),
      };
      final world = _World(beacons: beacons, firstSeen: {for (final k in beacons.keys) k: _now - 60000});
      expect(const TrustAgent().assess('clone0', world).sybilFactor, lessThan(1));
    });

    test('a verified rescue team arriving together is not flagged', () {
      final beacons = {
        for (var i = 0; i < 5; i++)
          'team$i': _beacon('team$i', {Capability.medicalAdvanced}, _center.offset(i * 2.0, 0), cred: _cred('team$i')),
      };
      final world = _World(beacons: beacons, anchors: {'authority'}, firstSeen: {for (final k in beacons.keys) k: _now - 60000});
      expect(const TrustAgent().assess('team0', world).sybilFactor, 1);
    });

    test('a mixed team with different skills is not flagged', () {
      final caps = [
        {Capability.medicalAdvanced},
        {Capability.boat},
        {Capability.vehicle},
        {Capability.searchRescue},
        {Capability.carry},
      ];
      final beacons = {for (var i = 0; i < 5; i++) 'v$i': _beacon('v$i', caps[i], _center.offset(i * 2.0, 0))};
      final world = _World(beacons: beacons, firstSeen: {for (final k in beacons.keys) k: _now - 60000});
      expect(const TrustAgent().assess('v0', world).sybilFactor, 1);
    });
  });

  test('C5: when every candidate lets the offer window pass, a new offer round starts', () async {
    final sim = await Simulator.build(relays: 6, responders: 6, victims: 3);
    try {
      sim.autoResponders = false; // nobody answers: every offer lapses
      await sim.seedEmergencies();
      await sim.run(4);
      // Measure on the node that currently sees the most matched requests.
      final observer = (sim.nodes.map((n) => n.node).toList()
            ..sort((a, b) => b.plan.assignments.length.compareTo(a.plan.assignments.length)))
          .first;
      final assignedAtStart = observer.plan.assignments.keys.toSet();
      expect(assignedAtStart, isNotEmpty, reason: 'scenario must start with at least one matched SOS');
      // Far longer than (candidates x offer window).
      await sim.run(40);
      final stillOpen = {for (final s in observer.states.values) if (s.isOpen) s.sosId};
      for (final id in assignedAtStart.intersection(stillOpen)) {
        expect(observer.plan.assignments.containsKey(id), isTrue, reason: 'SOS $id was abandoned after offers lapsed');
      }
    } finally {
      await sim.dispose();
    }
  });
}
