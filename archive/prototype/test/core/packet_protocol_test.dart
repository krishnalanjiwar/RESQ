import 'package:flutter_test/flutter_test.dart';
import 'package:resq/core/network/packet_protocol.dart';

void main() {
  group('MeshPacket', () {
    test('creates a packet with correct values', () {
      final packet = MeshPacket(
        id: 'test-001',
        senderId: 'node-abc',
        recipientId: 'broadcast',
        type: PacketType.sosBeacon,
        payload: {'victimName': 'Test Victim'},
        ttl: 7,
        timestamp: 1700000000000,
      );

      expect(packet.id, 'test-001');
      expect(packet.senderId, 'node-abc');
      expect(packet.recipientId, 'broadcast');
      expect(packet.type, PacketType.sosBeacon);
      expect(packet.ttl, 7);
      expect(packet.hops, 0);
      expect(packet.payload['victimName'], 'Test Victim');
    });

    test('serializes to JSON and deserializes back correctly', () {
      final original = MeshPacket(
        id: 'pkt-round-trip',
        senderId: 'node-xyz',
        recipientId: 'node-target',
        type: PacketType.directMessage,
        payload: {'message': 'hello mesh'},
        ttl: 5,
        timestamp: 1700000000000,
      );

      final json = original.toJson();
      final restored = MeshPacket.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.senderId, original.senderId);
      expect(restored.recipientId, original.recipientId);
      expect(restored.type, original.type);
      expect(restored.ttl, original.ttl);
      expect(restored.payload['message'], 'hello mesh');
    });

    test('copyWithDecayedTtl decrements TTL and increments hops', () {
      final packet = MeshPacket(
        id: 'pkt-decay',
        senderId: 'node-1',
        recipientId: 'broadcast',
        type: PacketType.sosBeacon,
        payload: {},
        ttl: 7,
        timestamp: 1700000000000,
      );

      final decayed = packet.copyWithDecayedTtl();
      expect(decayed.ttl, 6);
      expect(decayed.hops, 1);
      expect(decayed.id, packet.id); // same ID preserved

      final doubleDecayed = decayed.copyWithDecayedTtl();
      expect(doubleDecayed.ttl, 5);
      expect(doubleDecayed.hops, 2);
    });

    test('packet at TTL 1 decays to TTL 0', () {
      final packet = MeshPacket(
        id: 'pkt-last-hop',
        senderId: 'node-1',
        recipientId: 'broadcast',
        type: PacketType.sosBeacon,
        payload: {},
        ttl: 1,
        timestamp: 1700000000000,
      );

      final decayed = packet.copyWithDecayedTtl();
      expect(decayed.ttl, 0);
      expect(decayed.hops, 1);
    });

    test('all PacketType values round-trip through JSON', () {
      for (final type in PacketType.values) {
        final packet = MeshPacket(
          id: 'type-${type.name}',
          senderId: 'node-test',
          recipientId: 'broadcast',
          type: type,
          payload: {},
          ttl: 3,
          timestamp: 1700000000000,
        );
        final restored = MeshPacket.fromJson(packet.toJson());
        expect(restored.type, type, reason: 'PacketType ${type.name} failed round-trip');
      }
    });

    test('fromMap handles missing fields with safe defaults', () {
      final minimal = MeshPacket.fromMap({
        'id': 'pkt-minimal',
      });

      expect(minimal.id, 'pkt-minimal');
      expect(minimal.senderId, '');
      expect(minimal.recipientId, 'broadcast');
      expect(minimal.ttl, 7);
      expect(minimal.hops, 0);
    });
  });
}
