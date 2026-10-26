@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:resq/core/clock.dart';
import 'package:resq/core/geo.dart';
import 'package:resq/crypto/identity.dart';
import 'package:resq/crypto/signatures.dart';
import 'package:resq/data/resq_store.dart';
import 'package:resq/domain/models.dart';
import 'package:resq/domain/triage/capability_parser.dart';
import 'package:resq/mesh/sim_transport.dart';
import 'package:resq/node/resq_node.dart';

/// Medical card sharing, SOS severity classes, ordering and professions.
void main() {
  group('SOS severity classes', () {
    test('map urgency to SOS-A..D, unclear above minor', () {
      expect(Urgency.critical.sosClass, 'SOS-A');
      expect(Urgency.high.sosClass, 'SOS-B');
      expect(Urgency.unknown.sosClass, 'SOS-C');
      expect(Urgency.low.sosClass, 'SOS-D');
    });
  });

  group('medical card', () {
    test('round-trips, trims long fields and drops an invalid blood group', () {
      final card = MedicalCard.fromJson({'bg': 'Z+', 'cond': 'x' * 500, 'alg': ' penicillin '})!;
      expect(card.bloodGroup, '');
      expect(card.conditions.length, MedicalCard.maxFieldChars);
      expect(card.allergies, 'penicillin');
      expect(MedicalCard.fromJson(card.toJson())!.allergies, 'penicillin');
      expect(const MedicalCard().isEmpty, isTrue);
      expect(MedicalCard.fromJson('not a map'), isNull);
    });
  });

  test('profession: police and security claims parse to SECURITY', () {
    final caps = const CapabilityParser().parse('police officer, can drive').capabilities;
    expect(caps, contains(Capability.security));
    expect(professionOf(caps), 'Security');
    expect(professionOf({Capability.medicalAdvanced, Capability.security}), 'Medical');
    expect(professionOf({}), 'Volunteer');
  });

  test('accepting an SOS delivers the medical card to that responder only, through a relay', () async {
    final clock = ManualClock();
    final radio = SimRadio();
    final signatures = SignatureService();
    Future<ResqNode> node(String key) async => ResqNode.create(
          identity: await LocalIdentity.generate(),
          store: MemoryResqStore(),
          transport: radio.attach(key),
          clock: clock,
          signatures: signatures,
        );
    final victim = await node('victim');
    final relay = await node('relay');
    final medic = await node('medic');
    final all = [victim, relay, medic];

    Future<void> settle() async {
      for (var i = 0; i < 80; i++) {
        radio.pump();
        await Future<void>.delayed(Duration.zero);
        if (radio.queued == 0) await Future<void>.delayed(Duration.zero);
      }
    }

    Future<void> tickAll() async {
      for (final n in all) {
        await n.tick();
      }
      await settle();
    }

    for (final n in all) {
      await n.start();
    }
    radio.setLink('victim', 'relay', true);
    radio.setLink('relay', 'medic', true);
    await victim.setRole(NodeRole.victim);
    await relay.setRole(NodeRole.diagnostics);
    await medic.setRole(NodeRole.responder);
    await medic.setProfile('doctor');
    await victim.setMedicalCard(const MedicalCard(bloodGroup: 'O+', allergies: 'penicillin'));
    await settle();
    await tickAll();

    const home = GeoPoint(19.0760, 72.8777);
    final sosId = await victim.submitSos(
      text: 'dad collapsed, not breathing',
      location: LocationFix(point: home, accuracyM: 10, fixedAtMs: clock.nowMs()),
      shareOpenlyIfNoKeys: true,
    );
    await settle();
    await tickAll();
    expect(medic.sosRecords.any((s) => s.id == sosId), isTrue, reason: 'SOS reached the medic over 2 hops');

    await medic.respond(sosId, SosEventKind.accepted);
    await settle();
    await tickAll();
    await tickAll();

    expect(victim.medicalCardSentFor(sosId), isTrue);
    final received = medic.receivedCardFor(sosId);
    expect(received, isNotNull, reason: 'the accepting responder can read the card');
    expect(received!.bloodGroup, 'O+');
    expect(received.allergies, 'penicillin');
    expect(relay.receivedCardFor(sosId), isNull, reason: 'the relay forwarded it but cannot read it');

    // The requester learns who is coming and their profession.
    final who = victim.responderInfo(medic.selfId);
    expect(who, isNotNull);
    expect(professionOf(who!.caps), 'Medical');

    // Arrival: nothing happens 400 m away; within the radius it is marked
    // ON SCENE automatically and the requester sees it.
    medic.setSelfLocation(LocationFix(point: home.offset(400, 0), accuracyM: 10, fixedAtMs: clock.nowMs()));
    expect(await medic.autoMarkArrivals(), isEmpty);
    medic.setSelfLocation(LocationFix(point: home.offset(20, 5), accuracyM: 10, fixedAtMs: clock.nowMs()));
    expect(await medic.autoMarkArrivals(), [sosId]);
    await settle();
    await tickAll();
    expect(victim.mySos.single.state.phase.name, 'onScene', reason: 'the requester learns the volunteer arrived');
    expect(await medic.autoMarkArrivals(), isEmpty, reason: 'marked once only');

    for (final n in all) {
      await n.stop();
    }
  });
}
