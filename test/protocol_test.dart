import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resq/core/canonical_json.dart';
import 'package:resq/core/geo.dart';
import 'package:resq/core/ids.dart';
import 'package:resq/crypto/identity.dart';
import 'package:resq/crypto/sealed_box.dart';
import 'package:resq/crypto/signatures.dart';
import 'package:resq/protocol/envelope.dart';
import 'package:resq/protocol/flow_control.dart';
import 'package:resq/protocol/limits.dart';

Future<Envelope> _signed(LocalIdentity id, SignatureService sig, {int? now, Map<String, Object?>? body, int ttl = 5}) async {
  final t = now ?? 1700000000000;
  final msgId = newMessageId();
  final b = body ?? {'hello': 'world'};
  final fields = Envelope.signedFields(id: msgId, type: MsgType.hazard, origin: id.id, ts: t, exp: t + 60000, body: b);
  final s = await sig.sign(canonicalBytes(fields), id);
  return Envelope(id: msgId, type: MsgType.hazard, origin: id.id, ts: t, exp: t + 60000, ttl: ttl, hop: 0, body: b, sig: s);
}

void main() {
  const now = 1700000000000;

  test('canonical JSON is key-order independent', () {
    expect(canonicalJson({'b': 1, 'a': {'d': 2, 'c': 3}}), canonicalJson({'a': {'c': 3, 'd': 2}, 'b': 1}));
  });

  test('signed envelope round-trips and verifies; relay mutation of ttl/hop keeps signature valid', () async {
    final id = await LocalIdentity.generate();
    final sig = SignatureService();
    final env = await _signed(id, sig);
    final decoded = decodeFrame(env.relayed().toWire(), nowMs: now).envelope!;
    expect(decoded.ttl, env.ttl - 1);
    expect(await sig.verify(decoded.signingBytes, decoded.sig, decoded.origin), isTrue);
  });

  test('tampered body fails verification', () async {
    final id = await LocalIdentity.generate();
    final sig = SignatureService();
    final env = await _signed(id, sig);
    final json = env.toJson()..['b'] = {'hello': 'tampered'};
    final decoded = decodeJson(json, nowMs: now).envelope!;
    expect(await sig.verify(decoded.signingBytes, decoded.sig, decoded.origin), isFalse);
  });

  group('frame validation rejects hostile input', () {
    test('oversized', () => expect(decodeFrame(List.filled(Limits.maxFrameBytes + 1, 32), nowMs: now).error, 'FRAME_TOO_LARGE'));
    test('not json', () => expect(decodeFrame(utf8.encode('{nope'), nowMs: now).error, 'FRAME_NOT_JSON'));
    test('deep nesting', () {
      Object deep = 1;
      for (var i = 0; i < 20; i++) {
        deep = {'x': deep};
      }
      expect(decodeJson({'v': 1, 'b': deep}, nowMs: now).error, 'FRAME_TOO_DEEP');
    });
    test('unknown version', () => expect(decodeJson({'v': 99}, nowMs: now).error, 'UNSUPPORTED_VERSION'));
    test('hop count beyond the ttl budget (forged relay distance)', () async {
      final id = await LocalIdentity.generate();
      final env = await _signed(id, SignatureService(), ttl: 0);
      final json = env.toJson()..['hop'] = Limits.maxTtl + 1;
      expect(decodeJson(json, nowMs: now).error, 'HOPS_EXCEED_BUDGET');
      json
        ..['hop'] = 3
        ..['ttl'] = Limits.maxTtl;
      expect(decodeJson(json, nowMs: now).error, 'HOPS_EXCEED_BUDGET');
    });
    test('honest relays stay within the ttl budget all the way down', () async {
      final id = await LocalIdentity.generate();
      var env = await _signed(id, SignatureService(), ttl: Limits.maxTtl);
      while (env.ttl > 0) {
        env = decodeFrame(env.relayed().toWire(), nowMs: now).envelope!;
      }
      expect(env.hop, Limits.maxTtl);
    });
    test('expired', () async {
      final id = await LocalIdentity.generate();
      final env = await _signed(id, SignatureService(), now: now - 120000);
      expect(decodeFrame(env.toWire(), nowMs: now).error, 'EXPIRED');
    });
    test('ttl inflation is clamped', () async {
      final id = await LocalIdentity.generate();
      final env = await _signed(id, SignatureService(), ttl: 500);
      expect(decodeFrame(env.toWire(), nowMs: now).envelope!.ttl, Limits.maxTtl);
    });
  });

  test('sealed box: recipient opens, others cannot, aad binds to message id', () async {
    final alice = await LocalIdentity.generate();
    final bob = await LocalIdentity.generate();
    final eve = await LocalIdentity.generate();
    final aad = utf8.encode('msg-1');
    final sealed = await SealedBox.seal(utf8.encode('secret'), [alice.public.encKey, bob.public.encKey], aad: aad);
    expect(utf8.decode((await SealedBox.open(sealed, bob, aad: aad))!), 'secret');
    expect(await SealedBox.open(sealed, eve, aad: aad), isNull);
    expect(await SealedBox.open(sealed, bob, aad: utf8.encode('msg-2')), isNull);
    expect(jsonEncode(sealed).contains('secret'), isFalse);
  });

  test('dedupe and flood guard', () {
    final seen = SeenCache(capacity: 3);
    expect(seen.add('a', now + 1000), isTrue);
    expect(seen.add('a', now + 1000), isFalse);
    final guard = FloodGuard(capacity: 5, refillPerSecond: 1, strikesBeforeQuarantine: 3, quarantine: const Duration(minutes: 1));
    final results = [for (var i = 0; i < 10; i++) guard.check('peer', now)];
    expect(results.take(5).every((r) => r == null), isTrue);
    expect(results, contains('QUARANTINED_NOW'));
    expect(guard.isQuarantined('peer', now), isTrue);
  });

  test('geohash centre lies within ~5 km of the point', () {
    const p = GeoPoint(19.076, 72.8777);
    expect(geohashCenter(geohash(p))!.distanceTo(p), lessThan(5000));
  });

  test('fingerprints are stable and differ per key', () async {
    final a = await LocalIdentity.generate();
    final b = await LocalIdentity.generate();
    expect(a.public.fingerprint, PublicIdentity.fingerprintOf(a.id));
    expect(a.public.fingerprint, isNot(b.public.fingerprint));
  });
}
