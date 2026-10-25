import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/battery_cost_service.dart';

final batteryCostServiceProvider = Provider<BatteryCostService>((ref) {
  return BatteryCostService();
});

class BatteryStateData {
  final int level;
  final double routingCost;

  const BatteryStateData({required this.level, required this.routingCost});
}

final batteryStatusProvider = FutureProvider<BatteryStateData>((ref) async {
  final service = ref.watch(batteryCostServiceProvider);
  final level = await service.getBatteryLevel();
  final cost = await service.calculateRoutingCost();
  return BatteryStateData(level: level, routingCost: cost);
});
