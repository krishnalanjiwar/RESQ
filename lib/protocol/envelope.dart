import 'dart:convert';
import 'dart:typed_data';

import '../core/canonical_json.dart';
import '../core/ids.dart';
import '../crypto/b64.dart';
import 'limits.dart';

enum MsgType {
  /// Link-local: binds a radio endpoint to an identity. Never relayed.
  hello('hello', Limits.linkLifetime),

  /// Link-local: "I have your message". Never relayed.
  ack('ack', Limits.linkLifetime),

  /// Periodic presence: role, capabilities, credential, battery, coarse location.
  beacon('beacon', Limits.beaconLifetime),
  sos('sos', Limits.sosLifetime),

  /// Signed state change on an SOS (accept, en route, on scene, cancel, ...).
  event('event', Limits.eventLifetime),
  hazard('hazard', Limits.hazardLifetime),

  /// Credential delivered from an authority to its subject.
  credential('credential', Limits.credentialLifetime),
  revocation('revocation', Limits.revocationLifetime),
  vouch('vouch', Limits.vouchLifetime);

  const MsgType(this.wire, this.maxLifetime);

  final String wire;
  final Duration maxLifetime;

  bool get isLinkLocal => this == hello || this == ack;

  static MsgType? fromWire(Object? value) {
    for (final t in values) {
      if (t.wire == value) return t;
    }
    return null;
  }
}

/// The signed unit of the RESQ protocol.
///
/// `ttl` and `hop` change at every relay, so they are excluded from the
/// signature; everything else is covered. Optional cleartext routing hints
/// (`gh` coarse geohash, `urg` urgency class) are deliberate, documented leakage
/// so relays can prioritise without reading sealed bodies.
class Envelope {
  Envelope({
    required this.id,
    required this.type,
    required this.origin,
    required this.ts,
    required this.exp,
    required this.ttl,
    required this.hop,
    required this.body,
    required this.sig,
    this.gh,
    this.urg,
    this.v = Limits.protocolVersion,
  });

  final int v;
  final String id;
  final MsgType type;
  final String origin;
  final int ts;
  final int exp;
  final int ttl;
  final int hop;
  final String? gh;
  final String? urg;
  final Map<String, Object?> body;
  final String sig;

  static Map<String, Object?> signedFields({
    required String id,
    required MsgType type,
    required String origin,
    required int ts,
    required int exp,
    required Map<String, Object?> body,
    String? gh,
    String? urg,
  }) =>
      {
        'v': Limits.protocolVersion,
        'id': id,
        't': type.wire,
        'o': origin,
        'ts': ts,
        'exp': exp,
        'gh': ?gh,
        'urg': ?urg,
        'b': body,
      };

  List<int> get signingBytes => canonicalBytes(
        signedFields(id: id, type: type, origin: origin, ts: ts, exp: exp, body: body, gh: gh, urg: urg),
      );

  Map<String, Object?> toJson() => {
        ...signedFields(id: id, type: type, origin: origin, ts: ts, exp: exp, body: body, gh: gh, urg: urg),
        'ttl': ttl,
        'hop': hop,
        'sig': sig,
      };

  Uint8List toWire() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  String toStorage() => jsonEncode(toJson());

  Envelope relayed() => Envelope(
        id: id, type: type, origin: origin, ts: ts, exp: exp, ttl: ttl - 1, hop: hop + 1,
        body: body, sig: sig, gh: gh, urg: urg, v: v,
      );

  /// Same envelope with a different remaining hop budget (used for store-and-forward replays).
  Envelope withTtl(int newTtl) => Envelope(
        id: id, type: type, origin: origin, ts: ts, exp: exp, ttl: newTtl, hop: hop,
        body: body, sig: sig, gh: gh, urg: urg, v: v,
      );

  bool isExpired(int nowMs) => nowMs >= exp;
}

/// Outcome of decoding an untrusted frame. Signature checks happen later.
class DecodeResult {
  const DecodeResult.ok(Envelope this.envelope) : error = null;
  const DecodeResult.fail(String this.error) : envelope = null;

  final Envelope? envelope;
  final String? error;
}

/// Strict schema validation of an inbound frame.
DecodeResult decodeFrame(List<int> bytes, {required int nowMs}) {
  if (bytes.length > Limits.maxFrameBytes) return const DecodeResult.fail('FRAME_TOO_LARGE');
  Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return const DecodeResult.fail('FRAME_NOT_JSON');
  }
  return decodeJson(json, nowMs: nowMs);
}

DecodeResult decodeJson(Object? json, {required int nowMs}) {
  if (json is! Map<String, dynamic>) return const DecodeResult.fail('FRAME_NOT_OBJECT');
  if (jsonDepth(json) > Limits.maxJsonDepth) return const DecodeResult.fail('FRAME_TOO_DEEP');
  if (json['v'] != Limits.protocolVersion) return const DecodeResult.fail('UNSUPPORTED_VERSION');

  final id = json['id'], origin = json['o'], ts = json['ts'], exp = json['exp'];
  final ttl = json['ttl'], hop = json['hop'], body = json['b'], sig = json['sig'];
  final gh = json['gh'], urg = json['urg'];
  final type = MsgType.fromWire(json['t']);

  if (id is! String || !messageIdPattern.hasMatch(id)) return const DecodeResult.fail('BAD_ID');
  if (type == null) return const DecodeResult.fail('UNKNOWN_TYPE');
  if (origin is! String || !key32Pattern.hasMatch(origin)) return const DecodeResult.fail('BAD_ORIGIN');
  if (ts is! int || exp is! int || exp <= ts) return const DecodeResult.fail('BAD_TIMES');
  if (exp - ts > type.maxLifetime.inMilliseconds) return const DecodeResult.fail('LIFETIME_TOO_LONG');
  if (ts > nowMs + Limits.maxFutureSkew.inMilliseconds) return const DecodeResult.fail('FROM_THE_FUTURE');
  if (exp <= nowMs) return const DecodeResult.fail('EXPIRED');
  if (ttl is! int || ttl < 0 || hop is! int || hop < 0 || hop > 64) return const DecodeResult.fail('BAD_HOPS');
  // `hop` is unsigned, and the claim verifier widens the plausible distance per
  // hop. Every relay moves one unit from ttl to hop, so an honest frame always
  // has hop + ttl <= maxTtl; a larger claim is forged.
  if (hop + (ttl > Limits.maxTtl ? Limits.maxTtl : ttl) > Limits.maxTtl) {
    return const DecodeResult.fail('HOPS_EXCEED_BUDGET');
  }
  if (body is! Map<String, dynamic>) return const DecodeResult.fail('BAD_BODY');
  if (sig is! String || sig.length > 100) return const DecodeResult.fail('BAD_SIG_FIELD');
  if (gh != null && (gh is! String || gh.length > 8)) return const DecodeResult.fail('BAD_GEOHASH');
  if (urg != null && (urg is! String || urg.length > 12)) return const DecodeResult.fail('BAD_URGENCY');

  return DecodeResult.ok(Envelope(
    id: id,
    type: type,
    origin: origin,
    ts: ts,
    exp: exp,
    // Clamp rather than reject: a relay inflating TTL gains nothing beyond the cap.
    ttl: ttl > Limits.maxTtl ? Limits.maxTtl : ttl,
    hop: hop,
    body: body,
    sig: sig,
    gh: gh as String?,
    urg: urg as String?,
  ));
}
