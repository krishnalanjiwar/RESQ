import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../core/ids.dart';
import 'b64.dart';

/// Public half of a node identity: an Ed25519 signing key (the identity itself)
/// and an X25519 key that others use to seal data to this node.
class PublicIdentity {
  const PublicIdentity({required this.signKey, required this.encKey});

  final String signKey;
  final String encKey;

  /// Human-comparable fingerprint, e.g. `A1B2-C3D4-E5F6-0718`. Two people confirm
  /// it in person before pinning an authority or vouching for someone.
  String get fingerprint => fingerprintOf(signKey);

  static String fingerprintOf(String signKey) {
    final digest = const DartSha256().hashSync(utf8.encode('resq-fp-v1:$signKey')).bytes;
    final hex = toHex(digest.sublist(0, 8)).toUpperCase();
    return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }
}

/// Private identity held only on this device. Seeds live in OS-backed secure
/// storage (see key_store.dart), never in Hive.
class LocalIdentity {
  LocalIdentity._(this.signPair, this.encPair, this.public, this._signSeed, this._encSeed);

  final SimpleKeyPair signPair;
  final SimpleKeyPair encPair;
  final PublicIdentity public;
  final List<int> _signSeed;
  final List<int> _encSeed;

  String get id => public.signKey;

  static Future<LocalIdentity> generate() => fromSeeds(randomBytes(32), randomBytes(32));

  static Future<LocalIdentity> fromSeeds(List<int> signSeed, List<int> encSeed) async {
    final signPair = await Ed25519().newKeyPairFromSeed(signSeed);
    final encPair = await X25519().newKeyPairFromSeed(encSeed);
    final signPub = await signPair.extractPublicKey();
    final encPub = await encPair.extractPublicKey();
    return LocalIdentity._(
      signPair,
      encPair,
      PublicIdentity(signKey: b64(signPub.bytes), encKey: b64(encPub.bytes)),
      List.unmodifiable(signSeed),
      List.unmodifiable(encSeed),
    );
  }

  /// Serialized seeds for secure storage only.
  String exportSeeds() => jsonEncode({'s': b64(_signSeed), 'e': b64(_encSeed)});

  static Future<LocalIdentity?> importSeeds(String json) async {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final s = unb64(map['s'] as String), e = unb64(map['e'] as String);
      if (s == null || e == null || s.length != 32 || e.length != 32) return null;
      return await fromSeeds(s, e);
    } on Object {
      return null;
    }
  }
}
