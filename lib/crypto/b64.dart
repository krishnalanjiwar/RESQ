import 'dart:convert';
import 'dart:typed_data';

/// Unpadded base64url, used for every key, signature and ciphertext on the wire.
String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List? unb64(String text) {
  try {
    return base64Url.decode(base64Url.normalize(text));
  } on FormatException {
    return null;
  }
}

/// A 32-byte key encodes to exactly 43 unpadded base64url chars.
final RegExp key32Pattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
