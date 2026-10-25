import 'package:flutter_test/flutter_test.dart';
import 'package:resq/features/battery/services/battery_cost_service.dart';

void main() {
  group('BatteryCostService — Routing Cost Tiers', () {
    test('Tier 1: battery >= 80% → cost 1.0 (Ideal relay)', () {
      expect(BatteryCostService.costForLevel(100), 1.0);
      expect(BatteryCostService.costForLevel(80), 1.0);
    });

    test('Tier 2: battery 50-79% → cost 2.0 (Normal relay)', () {
      expect(BatteryCostService.costForLevel(79), 2.0);
      expect(BatteryCostService.costForLevel(50), 2.0);
    });

    test('Tier 3: battery 20-49% → cost 5.0 (Conserve energy)', () {
      expect(BatteryCostService.costForLevel(49), 5.0);
      expect(BatteryCostService.costForLevel(20), 5.0);
    });

    test('Tier 4: battery < 20% → cost 15.0 (Critical)', () {
      expect(BatteryCostService.costForLevel(19), 15.0);
      expect(BatteryCostService.costForLevel(5), 15.0);
      expect(BatteryCostService.costForLevel(0), 15.0);
    });
  });
}
