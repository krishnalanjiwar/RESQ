import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../core/ids.dart';
import 'b64.dart';
import 'identity.dart';

/// Multi-recipient sealed payload following the age v1 X25519 recipient design:
/// a random file key encrypts the payload once; for each recipient an ephemeral
/// X25519 agreement + HKDF-SHA256 derives a wrap key that encrypts the file key.
///
/// Recipients are not named in the stanzas (trial decryption), so relays learn
/// only how many recipients there are. Established primitives from
/// `package:cryptography`; the composition is documented in ADR-002 and still
/// needs independent review before any real-world deployment claim.
class SealedBox {
  static const int maxRecipients = 8;
  static const String _wrapInfo = 'resq/v1/x25519-wrap';

  static final X25519 _x = X25519();
  static final Xchacha20 _aead = Xchacha20.poly1305Aead();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Seals [plaintext] for [recipientEncKeys]. [aad] binds the ciphertext to its
  /// envelope (the message id) so it cannot be transplanted into another message.
  static Future<Map<String, Object?>> seal(
    List<int> plaintext,
    List<String> recipientEncKeys, {
    required List<int> aad,
  }) async {
    if (recipientEncKeys.isEmpty || recipientEncKeys.length > maxRecipients) {
      throw ArgumentError('1..$maxRecipients recipients required');
    }
    final fileKey = SecretKeyData(randomBytes(32));
    final stanzas = <Map<String, String>>[];
    for (final keyText in recipientEncKeys) {
      final recipientBytes = unb64(keyText);
      if (recipientBytes == null || recipientBytes.length != 32) continue;
      final recipient = SimplePublicKey(recipientBytes, type: KeyPairType.x25519);
      final ephemeral = await _x.newKeyPair();
      final ephPub = await ephemeral.extractPublicKey();
      final shared = await _x.sharedSecretKey(keyPair: ephemeral, remotePublicKey: recipient);
      final wrapKey = await _hkdf.deriveKey(
        secretKey: shared,
        nonce: [...ephPub.bytes, ...recipientBytes],
        info: utf8.encode(_wrapInfo),
      );
      final wrapped = await _aead.encrypt(await fileKey.extractBytes(), secretKey: wrapKey);
      stanzas.add({'e': b64(ephPub.bytes), 'w': b64(wrapped.concatenation())});
    }
    if (stanzas.isEmpty) throw ArgumentError('no valid recipient keys');
    final box = await _aead.encrypt(plaintext, secretKey: fileKey, aad: aad);
    return {'v': 1, 'r': stanzas, 'p': b64(box.concatenation())};
  }

  /// Returns the plaintext if [identity] is one of the recipients, else null.
  static Future<List<int>?> open(Map<String, Object?> sealed, LocalIdentity identity, {required List<int> aad}) async {
    try {
      if (sealed['v'] != 1) return null;
      final stanzas = (sealed['r'] as List).cast<Map<String, Object?>>();
      final payload = unb64(sealed['p'] as String);
      if (payload == null || stanzas.length > maxRecipients) return null;
      final myEncPub = unb64(identity.public.encKey)!;

      for (final stanza in stanzas) {
        final ephBytes = unb64(stanza['e'] as String);
        final wrappedBytes = unb64(stanza['w'] as String);
        if (ephBytes == null || wrappedBytes == null) continue;
        final shared = await _x.sharedSecretKey(
          keyPair: identity.encPair,
          remotePublicKey: SimplePublicKey(ephBytes, type: KeyPairType.x25519),
        );
        final wrapKey = await _hkdf.deriveKey(
          secretKey: shared,
          nonce: [...ephBytes, ...myEncPub],
          info: utf8.encode(_wrapInfo),
        );
        try {
          final fileKeyBytes = await _aead.decrypt(_split(wrappedBytes), secretKey: wrapKey);
          return await _aead.decrypt(_split(payload), secretKey: SecretKeyData(fileKeyBytes), aad: aad);
        } on SecretBoxAuthenticationError {
          continue; // not our stanza
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  static SecretBox _split(List<int> concatenated) => SecretBox.fromConcatenation(
        concatenated,
        nonceLength: _aead.nonceLength,
        macLength: _aead.macAlgorithm.macLength,
      );
}
