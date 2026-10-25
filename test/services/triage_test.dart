import 'package:flutter_test/flutter_test.dart';
import 'package:resq/features/ai_triage/services/offline_ai_service.dart';
import 'package:resq/features/ai_triage/models/triage_result.dart';

void main() {
  group('OfflineAiService — START Triage Protocol', () {
    late OfflineAiService service;

    setUp(() {
      service = OfflineAiService();
    });

    test('Black (Expectant) — not breathing', () async {
      final result = await service.triageVictim(
        symptoms: 'Unresponsive',
        canWalk: false,
        isBreathing: false,
        respirationRate: 0,
        hasRadialPulse: false,
        followsCommands: false,
      );

      expect(result.category, TriageCategory.expectant);
      expect(result.requiresEvacuation, false);
    });

    test('Green (Minor) — ambulatory, can walk', () async {
      final result = await service.triageVictim(
        symptoms: 'Minor cuts',
        canWalk: true,
        isBreathing: true,
        respirationRate: 16,
        hasRadialPulse: true,
        followsCommands: true,
      );

      expect(result.category, TriageCategory.minimal);
      expect(result.requiresEvacuation, false);
    });

    test('Red (Immediate) — breathing but high respiratory rate > 30', () async {
      final result = await service.triageVictim(
        symptoms: 'Severe trauma',
        canWalk: false,
        isBreathing: true,
        respirationRate: 35,
        hasRadialPulse: true,
        followsCommands: true,
      );

      expect(result.category, TriageCategory.immediate);
      expect(result.requiresEvacuation, true);
    });

    test('Red (Immediate) — no radial pulse', () async {
      final result = await service.triageVictim(
        symptoms: 'Bleeding',
        canWalk: false,
        isBreathing: true,
        respirationRate: 20,
        hasRadialPulse: false,
        followsCommands: true,
      );

      expect(result.category, TriageCategory.immediate);
      expect(result.requiresEvacuation, true);
    });

    test('Red (Immediate) — cannot follow commands', () async {
      final result = await service.triageVictim(
        symptoms: 'Head injury',
        canWalk: false,
        isBreathing: true,
        respirationRate: 20,
        hasRadialPulse: true,
        followsCommands: false,
      );

      expect(result.category, TriageCategory.immediate);
      expect(result.requiresEvacuation, true);
    });

    test('Red (Immediate) — low respiratory rate < 10', () async {
      final result = await service.triageVictim(
        symptoms: 'Respiratory distress',
        canWalk: false,
        isBreathing: true,
        respirationRate: 8,
        hasRadialPulse: true,
        followsCommands: true,
      );

      expect(result.category, TriageCategory.immediate);
      expect(result.requiresEvacuation, true);
    });

    test('Yellow (Delayed) — stable vitals, non-ambulatory', () async {
      final result = await service.triageVictim(
        symptoms: 'Fractured leg',
        canWalk: false,
        isBreathing: true,
        respirationRate: 18,
        hasRadialPulse: true,
        followsCommands: true,
      );

      expect(result.category, TriageCategory.delayed);
      expect(result.requiresEvacuation, true);
    });
  });
}
