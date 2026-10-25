import 'dart:math';
import 'dart:typed_data';

final Random _secure = Random.secure();

Uint8List randomBytes(int length) =>
    Uint8List.fromList(List<int>.generate(length, (_) => _secure.nextInt(256)));

String toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// 128-bit random identifier as 32 lowercase hex chars.
String newMessageId() => toHex(randomBytes(16));

final RegExp messageIdPattern = RegExp(r'^[0-9a-f]{32}$');
