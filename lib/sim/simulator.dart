import 'dart:math';
import 'dart:typed_data';

import '../core/canonical_json.dart';
import '../core/clock.dart';
import '../core/event_log.dart';
import '../core/geo.dart';
import '../core/ids.dart';
import '../crypto/identity.dart';
import '../crypto/signatures.dart';
import '../data/resq_store.dart';
import '../domain/chain/claim_verifier.dart';
import '../domain/models.dart';
import '../domain/reconcile/reconciler.dart';
import '../domain/trust/trust_agent.dart';
import '../mesh/sim_transport.dart';
import '../node/resq_node.dart';
import '../protocol/envelope.dart';
import '../protocol/limits.dart';

enum SimKind { victim, responder, relay, authority, attacker }

class SimNode {
  SimNode({required this.key, required this.node, required this.kind, required this.position, required this.label});

  final String key;
  final ResqNode node;
  final SimKind kind;
  GeoPoint position;
  final String label;

  /// Simulated-human state for responders.
  String? headingTo;
  int stepsOnScene = 0;
}

enum AttackOutcome { blocked, quarantined, flagged, notBlocked }

class RedTeamResult {
  const RedTeamResult(this.attack, this.outcome, this.details, this.atMs);

  final String attack;
  final AttackOutcome outcome;
  final List<String> details;
  final int atMs;
}

/// Simulated city running real ResqNode instances over a simulated radio.
/// Everything here is SIMULATION: separate in-memory stores, a virtual clock,
/// and labelled attacker nodes. Nothing touches the device's real records.
class Simulator {
  Simulator._(this.center, this.rng);

  final GeoPoint center;
  final Random rng;
  final ManualClock clock = ManualClock();
  final SimRadio radio = SimRadio();
  final SignatureService signatures = SignatureService(cacheCapacity: 20000);
  final List<SimNode> nodes = [];
  final EventLog log = EventLog(capacity: 400);
  final List<RedTeamResult> results = [];

  double radioRangeM = 320;
  bool partitioned = false;
  int steps = 0;
  bool autoResponders = true;
  late SimNode authority;
  GeoPoint? floodCenter;
  double floodRadiusM = 260;

  static const Duration stepDuration = Duration(seconds: 5);
  static const double responderSpeedMps = 6;

  static const NodeConfig simConfig = NodeConfig(
    offerWindow: Duration(seconds: 25),
    heartbeatInterval: Duration(seconds: 30),
    beaconIntervalOverride: Duration(seconds: 15),
    reconciler: Reconciler(orphanTimeout: Duration(minutes: 2), onSceneStaleTimeout: Duration(minutes: 10)),
  );

  /// A flooded riverside district: relays spread for connectivity, responders
  /// with a mix of verified and self-declared capabilities, and victims.
  static Future<Simulator> build({int seed = 7, int relays = 9, int responders = 9, int victims = 5}) async {
    final sim = Simulator._(const GeoPoint(19.0760, 72.8777), Random(seed));
    sim.authority = await sim._addNode(SimKind.authority, sim.center.offset(-60, 40), 'AUTH');
    final anchor = sim.authority.node.selfId;
    await sim.authority.node.setRole(NodeRole.diagnostics);
    await sim.authority.node.enableAuthority('SIM DISTRICT HEALTH OFFICE');
    await sim.authority.node.pinAnchor(anchor);

    // Relays on a jittered grid keep the mesh connected.
    final grid = sqrt(relays).ceil();
    for (var i = 0; i < relays; i++) {
      final gx = (i % grid) - (grid - 1) / 2, gy = (i ~/ grid) - (grid - 1) / 2;
      final p = sim.center.offset(gx * 260 + sim._jitter(60), gy * 260 + sim._jitter(60));
      final n = await sim._addNode(SimKind.relay, p, 'R$i', anchor: anchor);
      await n.node.setRole(NodeRole.diagnostics);
    }

    const profiles = [
      ('staff nurse at district hospital, insulin and first aid', true),
      ('I have a boat and can swim', true),
      ('firefighter with rope and ladder', true),
      ('doctor hoon, dialysis bhi kar sakta', true),
      ('tractor hai, strong, can lift stretcher', false),
      ('boat hai, tairna aata hai', false),
      ('first aid aata hai, car hai', false),
      ('civil defence volunteer search and rescue', false),
      ('food and water bottles, jeep', false),
    ];
    for (var i = 0; i < responders; i++) {
      final (profile, credentialed) = profiles[i % profiles.length];
      final p = sim.center.offset(sim._jitter(700), sim._jitter(700));
      final n = await sim._addNode(SimKind.responder, p, 'RSP$i', anchor: anchor);
      await n.node.setRole(NodeRole.responder);
      await n.node.setProfile(profile);
      n.node.setRealBattery(30 + sim.rng.nextInt(70));
      if (credentialed) {
        await sim.authority.node.issueCredential(n.node.selfId, n.node.profile.capabilities);
      }
    }

    for (var i = 0; i < victims; i++) {
      final p = sim.center.offset(sim._jitter(650), sim._jitter(650));
      final n = await sim._addNode(SimKind.victim, p, 'V$i', anchor: anchor);
      await n.node.setRole(NodeRole.victim);
      n.node.setRealBattery(10 + sim.rng.nextInt(60));
    }

    sim.floodCenter = sim.center.offset(220, -180);
    sim._log('SIM_BUILT', '${sim.nodes.length} nodes · radio range ${sim.radioRangeM.round()} m');
    await sim.step(); // form links, deliver credentials
    await sim.step();
    return sim;
  }

  double _jitter(double span) => (rng.nextDouble() - 0.5) * 2 * span;

  Future<SimNode> _addNode(SimKind kind, GeoPoint p, String label, {String? anchor}) async {
    final identity = await LocalIdentity.generate();
    final key = 'sim-$label';
    final node = await ResqNode.create(
      identity: identity,
      store: MemoryResqStore(),
      transport: radio.attach(key),
      clock: clock,
      signatures: signatures,
      config: simConfig,
      provisionedAnchors: anchor == null ? const {} : {anchor},
    );
    await node.setDisplayName(label);
    final sn = SimNode(key: key, node: node, kind: kind, position: p, label: label);
    node.setSelfLocation(LocationFix(point: p, accuracyM: 15, fixedAtMs: clock.nowMs(), source: 'sim'));
    await node.start();
    nodes.add(sn);
    return sn;
  }

  void _log(String code, [String detail = '']) => log.add(clock.nowMs(), LogCategory.sim, code, detail);

  // ---------------------------------------------------------------------
  // Stepping
  // ---------------------------------------------------------------------

  bool _crossesPartition(GeoPoint a, GeoPoint b) =>
      partitioned && ((a.lng < center.lng) != (b.lng < center.lng));

  void _updateLinks() {
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final a = nodes[i], b = nodes[j];
        final up = a.position.distanceTo(b.position) <= radioRangeM && !_crossesPartition(a.position, b.position);
        radio.setLink(a.key, b.key, up);
      }
    }
  }

  Future<void> _settle() async {
    for (var round = 0; round < 60; round++) {
      final delivered = radio.pump();
      await Future<void>.delayed(Duration.zero);
      if (delivered == 0 && radio.queued == 0) {
        // Let async verification/apply chains finish, then stop if quiet.
        await Future<void>.delayed(Duration.zero);
        if (radio.queued == 0) break;
      }
    }
  }

  Future<void> step() async {
    steps++;
    clock.advance(stepDuration);
    _updateLinks();
    await _settle();
    for (final n in nodes) {
      await n.node.tick();
    }
    await _settle();
    if (autoResponders) await _simulatedHumans();
    await _settle();
  }

  /// Simulated human responders: they read the offer card and decide. They
  /// accept when the chain says it's reasonably safe and probably real, decline
  /// otherwise, then physically move toward the victim and report progress.
  Future<void> _simulatedHumans() async {
    for (final n in nodes.where((n) => n.kind == SimKind.responder)) {
      final node = n.node;
      for (final offer in node.myOffers) {
        final r = offer.assignment.primaryResult;
        final willing = r.hazard.pSafe >= 0.4 && r.claim.pReal >= 0.3;
        await node.respond(offer.assignment.sos.id, willing ? SosEventKind.accepted : SosEventKind.declined);
        _log(willing ? 'SIM_HUMAN_ACCEPTED' : 'SIM_HUMAN_DECLINED', '${n.label}: ${offer.justification}');
        if (willing) break;
      }
      for (final e in node.myEngagements) {
        if (e.standDown && e.myProgress < SosEventKind.onScene.progress) {
          await node.respond(e.sos.id, SosEventKind.standDown, note: 'reconciliation');
          n.headingTo = null;
          _log('SIM_STAND_DOWN', '${n.label} released ${e.sos.id.substring(0, 6)}');
          continue;
        }
        if (!e.isPrimary && !e.state.conflicts.contains('MULTIPLE_ON_SCENE')) continue;
        final target = e.sos.approxPoint;
        if (target == null) continue;
        if (e.myProgress == SosEventKind.accepted.progress) {
          await node.respond(e.sos.id, SosEventKind.enRoute);
          n.headingTo = e.sos.id;
        } else if (e.myProgress == SosEventKind.enRoute.progress) {
          final d = n.position.distanceTo(target);
          final stepM = responderSpeedMps * stepDuration.inSeconds;
          if (d <= 40) {
            await node.respond(e.sos.id, SosEventKind.onScene);
            n.stepsOnScene = 0;
          } else {
            final f = min(1.0, stepM / d);
            n.position = GeoPoint(n.position.lat + (target.lat - n.position.lat) * f,
                n.position.lng + (target.lng - n.position.lng) * f);
            node.setSelfLocation(LocationFix(point: n.position, accuracyM: 15, fixedAtMs: clock.nowMs(), source: 'sim'));
          }
        } else if (e.myProgress == SosEventKind.onScene.progress && ++n.stepsOnScene > 10) {
          await node.respond(e.sos.id, SosEventKind.resolved);
          n.headingTo = null;
        }
      }
    }
  }

  Future<void> run(int count) async {
    for (var i = 0; i < count; i++) {
      await step();
    }
  }

  // ---------------------------------------------------------------------
  // Scenario actions
  // ---------------------------------------------------------------------

  SimNode get observer => nodes.firstWhere((n) => n.kind == SimKind.relay);

  Future<void> reportFlood() async {
    final c = floodCenter!;
    final reporters = nodes.where((n) => n.kind == SimKind.relay || n.kind == SimKind.responder).toList()
      ..sort((a, b) => a.position.distanceTo(c).compareTo(b.position.distanceTo(c)));
    for (final r in reporters.take(3)) {
      await r.node.reportHazard(kind: HazardKind.flood, center: c.offset(_jitter(40), _jitter(40)), radiusM: floodRadiusM, severity: 3);
    }
    _log('SIM_FLOOD_REPORTED', '3 independent reporters');
    await _settle();
  }

  static const List<String> _sosTexts = [
    'Need insulin for dad, ground floor flooded',
    'Pani aa raha hai, bachao. Budhe dada chhat par hain',
    'trapped under debris, leg injured',
    'need food and drinking water for 4 kids',
    'please help',
  ];

  /// Victims send SOS. The first is the problem statement's example: drifting
  /// GPS (±120 m) and 12% battery, inside the flood zone.
  Future<void> seedEmergencies() async {
    final victims = nodes.where((n) => n.kind == SimKind.victim).toList();
    for (var i = 0; i < victims.length; i++) {
      final v = victims[i];
      LocationFix fix;
      if (i == 0 && floodCenter != null) {
        v.position = floodCenter!.offset(_jitter(60), _jitter(60));
        v.node.setRealBattery(12);
        fix = LocationFix(point: v.position.offset(_jitter(90), _jitter(90)), accuracyM: 120, fixedAtMs: clock.nowMs(), source: 'sim');
      } else {
        fix = LocationFix(point: v.position, accuracyM: 20 + rng.nextInt(40).toDouble(), fixedAtMs: clock.nowMs(), source: 'sim');
      }
      v.node.setSelfLocation(fix);
      await v.node.submitSos(text: _sosTexts[i % _sosTexts.length], location: fix, shareOpenlyIfNoKeys: true);
    }
    _log('SIM_SOS_SEEDED', '${victims.length} victims');
    await _settle();
  }

  Future<void> togglePartition() async {
    partitioned = !partitioned;
    _updateLinks();
    _log(partitioned ? 'SIM_PARTITION_ON' : 'SIM_PARTITION_OFF',
        partitioned ? 'OFFLINE: islands east/west of the river' : 'links restored; reconciling');
    await _settle();
    if (!partitioned) {
      final report = observer.node.reconciliationReport;
      results.add(RedTeamResult(
        'PARTITION MERGE',
        report.conflicts == 0 && report.standDownsIssued == 0 ? AttackOutcome.blocked : AttackOutcome.flagged,
        [
          'SOS known: ${report.sosCount}',
          'double dispatches detected: ${report.doubleDispatches}',
          'stand-downs issued: ${report.standDownsIssued} (never to a responder on scene)',
          'multiple on scene: ${report.multipleOnScene}',
          'orphaned assignments reopened: ${report.orphansReopened}',
        ],
        clock.nowMs(),
      ));
    }
  }

  /// Splits the city, puts one SOS on the dividing line visible to both
  /// islands, so each island can independently dispatch: the merge must clean up.
  Future<void> partitionDoubleDispatchScenario() async {
    final v = nodes.firstWhere((n) => n.kind == SimKind.victim);
    v.position = center.offset(5, 60);
    final fix = LocationFix(point: v.position, accuracyM: 25, fixedAtMs: clock.nowMs(), source: 'sim');
    v.node.setSelfLocation(fix);
    autoResponders = false;
    await v.node.submitSos(text: 'trapped in collapsed house, mother injured', location: fix, shareOpenlyIfNoKeys: true);
    await run(2);
    await togglePartition();
    // Each island accepts on its own: pick the best responder on each side.
    for (final westSide in [true, false]) {
      final side = nodes.where((n) => n.kind == SimKind.responder && (n.position.lng < center.lng) == westSide).toList();
      if (side.isEmpty) continue;
      final sosId = v.node.mySos.first.sos.id;
      side.sort((a, b) => a.position.distanceTo(v.position).compareTo(b.position.distanceTo(v.position)));
      await side.first.node.respond(sosId, SosEventKind.accepted);
      _log('SIM_ISLAND_ACCEPT', '${side.first.label} (${westSide ? 'west' : 'east'})');
    }
    autoResponders = true;
    await run(3);
  }

  // ---------------------------------------------------------------------
  // Red Team Hour — attacks inject real frames; outcomes are measured
  // ---------------------------------------------------------------------

  Future<SimNode> _attackerAt(GeoPoint p, String label) async {
    final a = await _addNode(SimKind.attacker, p, label);
    await a.node.setRole(NodeRole.victim);
    _updateLinks();
    await _settle();
    return a;
  }

  Future<Uint8List> _craft(LocalIdentity id, MsgType type, Map<String, Object?> body,
      {int ttl = Limits.maxTtl, int hop = 0, String? gh, String? urg, String? forcedSig}) async {
    final now = clock.nowMs();
    final msgId = newMessageId();
    final exp = now + type.maxLifetime.inMilliseconds;
    final fields = Envelope.signedFields(id: msgId, type: type, origin: id.id, ts: now, exp: exp, body: body, gh: gh, urg: urg);
    final sig = forcedSig ?? await signatures.sign(canonicalBytes(fields), id);
    return Envelope(
      id: msgId, type: type, origin: id.id, ts: now, exp: exp, ttl: ttl, hop: hop, body: body, sig: sig, gh: gh, urg: urg,
    ).toWire();
  }

  Future<void> _inject(SimNode attacker, Uint8List frame) async {
    final t = radio.attach(attacker.key);
    for (final peer in t.connectedPeers) {
      await t.send(peer, frame);
    }
  }

  List<SimNode> _neighboursOf(SimNode a) {
    final peers = radio.attach(a.key).connectedPeers;
    return nodes.where((n) => peers.contains(n.key)).toList();
  }

  /// "One node pretending to be 40 nurses."
  ///
  /// With [forgeHop] the attacker marks every fake as already relayed once
  /// (`hop` is unsigned), posing as an honest relay instead of their origin.
  /// With [spreadOut] the fakes claim positions hundreds of metres apart,
  /// dodging the co-location heuristic.
  Future<RedTeamResult> attackSybil({int identities = 40, bool forgeHop = false, bool spreadOut = false}) async {
    final attacker = await _attackerAt(center.offset(_jitter(200), _jitter(200)), 'ATK-SYBIL');
    final fakes = <LocalIdentity>[];
    for (var i = 0; i < identities; i++) {
      final id = await LocalIdentity.generate();
      fakes.add(id);
      await _inject(attacker, await _craft(id, MsgType.beacon, {
        'role': 'responder',
        'caps': ['medicalAdvanced'],
        'avail': true,
        'enc': id.public.encKey,
        'name': 'Nurse $i',
        'bat': 100,
        'loc': {
          ...attacker.position.offset(_jitter(spreadOut ? 250 : 10), _jitter(spreadOut ? 250 : 10)).toJson(),
          'acc': 10,
          'at': clock.nowMs(),
        },
      }, ttl: 4, hop: forgeHop ? 1 : 0));
    }
    await _settle();
    await run(3);

    final fakeIds = {for (final f in fakes) f.id};
    final neighbours = _neighboursOf(attacker);
    var suspicious = 0, maxTrust = 0.0;
    for (final n in neighbours) {
      for (final f in fakeIds) {
        final t = n.node.trustOf(f);
        if (t.level == TrustLevel.suspicious || t.level == TrustLevel.quarantined) suspicious++;
        final ct = t.capabilityTrust({Capability.medicalAdvanced});
        if (ct > maxTrust) maxTrust = ct;
      }
    }
    var assignedToFake = 0;
    for (final n in nodes) {
      for (final a in n.node.plan.assignments.values) {
        if (fakeIds.contains(a.primary)) assignedToFake++;
      }
    }
    final checks = neighbours.length * fakeIds.length;
    final result = RedTeamResult(
      'SYBIL: 1 NODE AS $identities NURSES${forgeHop ? ' (FORGED HOP)' : ''}',
      assignedToFake == 0 && suspicious == checks ? AttackOutcome.blocked : (assignedToFake == 0 ? AttackOutcome.flagged : AttackOutcome.notBlocked),
      [
        '$identities identities injected over ${neighbours.length} radio link(s)',
        'flagged suspicious at direct neighbours: $suspicious / $checks',
        'highest medical capability trust: ${(maxTrust * 100).round()}%',
        'dispatch assignments to fake identities (all nodes): $assignedToFake',
      ],
      clock.nowMs(),
    );
    results.add(result);
    _log('REDTEAM_SYBIL', result.outcome.name);
    return result;
  }

  /// Forged medical credential claiming to be signed by the pinned authority.
  Future<RedTeamResult> attackForgedCredential() async {
    final attacker = await _attackerAt(center.offset(_jitter(250), _jitter(250)), 'ATK-CRED');
    final fake = await LocalIdentity.generate();
    final now = clock.nowMs();
    final forged = Credential(
      cid: newMessageId(),
      subject: fake.id,
      roles: {Capability.medicalAdvanced},
      issuedAtMs: now,
      expiresAtMs: now + const Duration(days: 30).inMilliseconds,
      issuer: authority.node.selfId,
      issuerName: 'SIM DISTRICT HEALTH OFFICE',
      // Signed by the attacker, not the authority.
      sig: await signatures.sign(canonicalBytes({'forged': true}), fake),
    );
    await _inject(attacker, await _craft(fake, MsgType.beacon, {
      'role': 'responder',
      'caps': ['medicalAdvanced'],
      'avail': true,
      'enc': fake.public.encKey,
      'name': 'Dr. Totally Real',
      'loc': {...attacker.position.toJson(), 'acc': 10, 'at': now},
      'cred': forged.toJson(),
    }, ttl: 4));
    await _settle();
    await run(2);
    final observers = nodes.where((n) => n.node.beacons.containsKey(fake.id)).toList();
    final forgedSeen = observers.where((n) => n.node.trustOf(fake.id).credentialStatus == CredentialStatus.forged).length;
    final quarantined = observers.where((n) => n.node.trustOf(fake.id).quarantined).length;
    var assigned = 0;
    for (final n in nodes) {
      assigned += n.node.plan.assignments.values.where((a) => a.primary == fake.id).length;
    }
    final result = RedTeamResult(
      'FORGED MEDICAL CREDENTIAL',
      observers.isNotEmpty && quarantined == observers.length && assigned == 0 ? AttackOutcome.quarantined : AttackOutcome.notBlocked,
      [
        'credential claims issuer = pinned authority, signature by attacker',
        'nodes that received it: ${observers.length}',
        'detected as FORGED: $forgedSeen · quarantined: $quarantined',
        'dispatch assignments to forger: $assigned',
      ],
      clock.nowMs(),
    );
    results.add(result);
    _log('REDTEAM_FORGED_CREDENTIAL', result.outcome.name);
    return result;
  }

  /// SOS claiming to be 5 km away while arriving over a single hop.
  Future<RedTeamResult> attackSpoofedLocation() async {
    final attacker = await _attackerAt(center.offset(_jitter(200), _jitter(200)), 'ATK-GPS');
    final spoofed = attacker.position.offset(5000, 0);
    final fix = LocationFix(point: spoofed, accuracyM: 10, fixedAtMs: clock.nowMs(), source: 'spoofed');
    final id = await attacker.node.submitSos(text: 'heart attack, need doctor now', location: fix, shareOpenlyIfNoKeys: true);
    await _settle();
    await run(1);
    final neighbours = _neighboursOf(attacker);
    var flagged = 0;
    var minPLoc = 1.0;
    for (final n in neighbours) {
      final sos = n.node.sosRecords.where((s) => s.id == id).firstOrNull;
      if (sos == null) continue;
      final c = n.node.plan.results.values.where((r) => r.sosId == id).firstOrNull?.claim;
      final claim = c ?? const ClaimVerifier().verify(sos, n.node);
      if (claim.reasons.any((r) => r.startsWith('LOCATION_IMPLAUSIBLE'))) flagged++;
      if (claim.pLocation < minPLoc) minPLoc = claim.pLocation;
    }
    final result = RedTeamResult(
      'LOCATION SPOOFING',
      flagged > 0 ? AttackOutcome.flagged : AttackOutcome.notBlocked,
      [
        'claimed position ${formatDistance(5000)} from the attacker, delivered in 1 hop',
        'direct neighbours flagging LOCATION_IMPLAUSIBLE: $flagged / ${neighbours.length}',
        'lowest P(location): ${(minPLoc * 100).round()}%',
      ],
      clock.nowMs(),
    );
    results.add(result);
    _log('REDTEAM_SPOOFED_LOCATION', result.outcome.name);
    return result;
  }

  /// Decoy CRITICAL SOS deep inside the flood zone from a brand-new identity:
  /// tries to lure unequipped responders into rising water.
  Future<RedTeamResult> attackFloodLure() async {
    if (floodCenter == null || observer.node.hazardZones.isEmpty) await reportFlood();
    await run(1);
    final p = floodCenter!.offset(_jitter(30), _jitter(30));
    final attacker = await _attackerAt(p, 'ATK-LURE');
    final fix = LocationFix(point: p, accuracyM: 8, fixedAtMs: clock.nowMs(), source: 'sim');
    final id = await attacker.node.submitSos(text: 'URGENT child drowning come now!!', location: fix, shareOpenlyIfNoKeys: true);
    await _settle();
    await run(2);
    final unequippedAssigned = <String>[];
    final equippedAssigned = <String>[];
    var decoyFlags = 0;
    for (final n in nodes) {
      final a = n.node.plan.assignments[id];
      final r = n.node.plan.results.values.where((x) => x.sosId == id).firstOrNull;
      if (r != null && r.claim.suspectedDecoy) decoyFlags++;
      if (a == null) continue;
      final caps = n.node.beacons[a.primary]?.declaredCaps ?? {};
      final equipped = hazardCapabilities[HazardKind.flood]!.any(caps.contains);
      (equipped ? equippedAssigned : unequippedAssigned).add(a.primary);
    }
    final result = RedTeamResult(
      'FLOODWATER LURE (DECOY SOS IN FLOOD ZONE)',
      unequippedAssigned.isEmpty ? AttackOutcome.blocked : AttackOutcome.notBlocked,
      [
        'flood zone confidence at observer: ${observer.node.hazardZones.isEmpty ? 'none' : '${(observer.node.hazardZones.first.confidence * 100).round()}%'}',
        'nodes assigning an UNEQUIPPED responder: ${unequippedAssigned.length}',
        'nodes assigning only boat/swim-capable responders: ${equippedAssigned.length}',
        'nodes flagging SUSPECTED_DECOY: $decoyFlags',
        'human acceptance still required on every offer',
      ],
      clock.nowMs(),
    );
    results.add(result);
    _log('REDTEAM_FLOOD_LURE', result.outcome.name);
    return result;
  }

  /// Battery-drain attempt: floods neighbours with junk and replayed frames.
  Future<RedTeamResult> attackBatteryDrain({int frames = 600}) async {
    final attacker = await _attackerAt(center.offset(_jitter(150), _jitter(150)), 'ATK-DRAIN');
    final id = await LocalIdentity.generate();
    final replay = await _craft(id, MsgType.hazard,
        {...attacker.position.toJson(), 'kind': 'other', 'r': 50, 'sev': 1});
    final deliveredBefore = radio.framesDelivered;
    final t = radio.attach(attacker.key);
    for (var i = 0; i < frames; i++) {
      final frame = i.isEven ? replay : Uint8List.fromList(randomBytes(200 + rng.nextInt(800)));
      for (final peer in t.connectedPeers) {
        await t.send(peer, frame);
      }
    }
    await _settle();
    final injected = frames * t.connectedPeers.length;
    final networkFrames = radio.framesDelivered - deliveredBefore - injected;
    final neighbours = _neighboursOf(attacker);
    final quarantinedAt = neighbours.where((n) => n.node.counts.quarantinedLinks > 0).length;
    final result = RedTeamResult(
      'NETWORK BATTERY DRAIN',
      quarantinedAt == neighbours.length && neighbours.isNotEmpty ? AttackOutcome.quarantined : AttackOutcome.flagged,
      [
        '$injected frames injected (junk + replays) at ${neighbours.length} neighbour(s)',
        'neighbours that quarantined the link: $quarantinedAt',
        'extra frames that propagated beyond neighbours: ${networkFrames < 0 ? 0 : networkFrames}',
        'replays dropped by dedupe; junk rejected before signature checks',
      ],
      clock.nowMs(),
    );
    results.add(result);
    _log('REDTEAM_BATTERY_DRAIN', result.outcome.name);
    return result;
  }

  /// Simulated battery drain on all relays (diagnostics override, never the real reading).
  void setRelayBatteryOverride(int? level) {
    for (final n in nodes.where((n) => n.kind == SimKind.relay)) {
      n.node.setBatteryOverride(level);
    }
    _log(level == null ? 'SIM_BATTERY_OVERRIDE_CLEARED' : 'SIM_BATTERY_OVERRIDE', level == null ? '' : '$level%');
  }

  Future<void> dispose() async {
    for (final n in nodes) {
      await n.node.stop();
      await n.node.dispose();
    }
  }
}
