import 'package:flutter_test/flutter_test.dart';
import 'package:resq/features/storage/models/sos_message.dart';

void main() {
  group('SosMessage', () {
    test('creates with correct default status', () {
      final sos = SosMessage(
        id: 'sos-001',
        senderId: 'node-abc',
        victimName: 'John Doe',
        emergencyType: 'Medical',
        description: 'Chest pain',
        severity: 'Critical',
        timestamp: 1700000000000,
      );

      expect(sos.status, SosStatus.active);
      expect(sos.acknowledgedBy, isNull);
      expect(sos.isRelayed, false);
      expect(sos.hopCount, 0);
    });

    test('serializes and deserializes with status and acknowledgedBy', () {
      final original = SosMessage(
        id: 'sos-rt',
        senderId: 'node-xyz',
        victimName: 'Jane',
        emergencyType: 'Trapped',
        description: 'Building collapse',
        latitude: 18.5204,
        longitude: 73.8567,
        severity: 'Critical',
        timestamp: 1700000000000,
        status: SosStatus.acknowledged,
        acknowledgedBy: 'responder-42',
      );

      final map = original.toMap();
      final restored = SosMessage.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.status, SosStatus.acknowledged);
      expect(restored.acknowledgedBy, 'responder-42');
      expect(restored.latitude, 18.5204);
      expect(restored.longitude, 73.8567);
    });

    test('copyWith preserves existing fields and overrides specified ones', () {
      final sos = SosMessage(
        id: 'sos-copy',
        senderId: 'node-1',
        victimName: 'Victim',
        emergencyType: 'Fire',
        description: 'House fire',
        severity: 'Urgent',
        timestamp: 1700000000000,
      );

      final acknowledged = sos.copyWith(
        status: SosStatus.acknowledged,
        acknowledgedBy: 'responder-7',
      );

      expect(acknowledged.id, sos.id); // preserved
      expect(acknowledged.victimName, sos.victimName); // preserved
      expect(acknowledged.status, SosStatus.acknowledged); // overridden
      expect(acknowledged.acknowledgedBy, 'responder-7'); // overridden
    });

    test('fromMap defaults to active status when field is missing', () {
      final map = {
        'id': 'sos-legacy',
        'senderId': 'node-old',
        'victimName': 'Legacy User',
        'emergencyType': 'Flood',
        'description': 'Water rising',
        'severity': 'Moderate',
        'timestamp': 1700000000000,
        // no 'status' or 'acknowledgedBy' fields
      };

      final sos = SosMessage.fromMap(map);
      expect(sos.status, SosStatus.active);
      expect(sos.acknowledgedBy, isNull);
    });

    test('all SosStatus values round-trip through toMap/fromMap', () {
      for (final status in SosStatus.values) {
        final sos = SosMessage(
          id: 'sos-${status.name}',
          senderId: 'node-test',
          victimName: 'Test',
          emergencyType: 'Test',
          description: 'Test',
          severity: 'Moderate',
          timestamp: 1700000000000,
          status: status,
        );
        final restored = SosMessage.fromMap(sos.toMap());
        expect(restored.status, status,
            reason: 'SosStatus ${status.name} failed round-trip');
      }
    });
  });
}
