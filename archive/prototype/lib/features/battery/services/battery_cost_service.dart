import 'package:battery_plus/battery_plus.dart';
import '../../../core/utils/app_logger.dart';

class BatteryCostService {
  final Battery _battery = Battery();

  /// Gets current battery level (0 to 100)
  Future<int> getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      return level;
    } catch (e) {
      AppLogger.warning('Could not read battery level: $e');
      return 100; // default assumption
    }
  }

  /// Pure function: calculates routing cost for a given battery level.
  /// Extracted for testability without async Battery plugin dependency.
  static double costForLevel(int level) {
    if (level >= 80) {
      return 1.0;
    } else if (level >= 50) {
      return 2.0;
    } else if (level >= 20) {
      return 5.0;
    } else {
      return 15.0; // High routing penalty to conserve battery for survival
    }
  }

  /// Calculates dynamic routing cost based on current battery level.
  /// Higher cost = less preferred for relaying packets.
  Future<double> calculateRoutingCost() async {
    final level = await getBatteryLevel();
    return costForLevel(level);
  }

  /// Stream of battery state changes (charging, discharging, full)
  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;
}
