import 'dart:convert';

enum PacketType {
  sosBeacon,
  directMessage,
  triageReport,
  meshTelemetry,
  acknowledgement,
}

class MeshPacket {
  final String id;
  final String senderId;
  final String recipientId; // empty string or 'broadcast' for public mesh
  final PacketType type;
  final int ttl;
  final int hops;
  final int timestamp;
  final Map<String, dynamic> payload;

  const MeshPacket({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.type,
    this.ttl = 7, // Bitchat controlled flood initial TTL
    this.hops = 0,
    required this.timestamp,
    required this.payload,
  });

  /// Decays TTL by 1 and increments hop count for mesh forwarding
  MeshPacket copyWithDecayedTtl() {
    return MeshPacket(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      type: type,
      ttl: ttl - 1,
      hops: hops + 1,
      timestamp: timestamp,
      payload: payload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'type': type.name,
      'ttl': ttl,
      'hops': hops,
      'timestamp': timestamp,
      'payload': payload,
    };
  }

  factory MeshPacket.fromMap(Map<String, dynamic> map) {
    return MeshPacket(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? 'broadcast',
      type: PacketType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PacketType.directMessage,
      ),
      ttl: map['ttl'] ?? 7,
      hops: map['hops'] ?? 0,
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MeshPacket.fromJson(String source) =>
      MeshPacket.fromMap(jsonDecode(source));
}
