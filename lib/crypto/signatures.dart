import 'dart:collection';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../core/ids.dart';
import 'b64.dart';
import 'identity.dart';

/// Ed25519 signing/verification. Verification is a pure function, so results
/// can be memoised; the simulator shares one cache across all virtual nodes.
class SignatureService {
  SignatureService({this.cacheCapacity = 4096});

  final int cacheCapacity;
  final Ed25519 _ed = Ed25519();
  final LinkedHashMap<String, bool> _cache = LinkedHashMap();

  Future<String> sign(List<int> message, LocalIdentity identity) async {
    final sig = await _ed.sign(message, keyPair: identity.signPair);
    return b64(sig.bytes);
  }

  Future<bool> verify(List<int> message, String signature, String signKey) async {
    final sigBytes = unb64(signature);
    final keyBytes = unb64(signKey);
    if (sigBytes == null || sigBytes.length != 64 || keyBytes == null || keyBytes.length != 32) {
      return false;
    }
    final cacheKey = toHex(const DartSha256().hashSync([...message, ...sigBytes, ...keyBytes]).bytes);
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    bool ok;
    try {
      ok = await _ed.verify(
        message,
        signature: Signature(sigBytes, publicKey: SimplePublicKey(keyBytes, type: KeyPairType.ed25519)),
      );
    } on Object {
      ok = false;
    }
    _cache[cacheKey] = ok;
    if (_cache.length > cacheCapacity) _cache.remove(_cache.keys.first);
    return ok;
  }
}
