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

  /// Calculates dynamic routing cost based on battery level.
  /// Higher cost = less preferred for relaying packets.
  /// Battery > 80%: Cost 1.0 (Ideal relay)
  /// Battery 50-80%: Cost 2.0 (Normal relay)
  /// Battery 20-50%: Cost 5.0 (Conserve energy)
  /// Battery < 20%: Cost 10.0+ (Critical: do not relay unless destination)
  Future<double> calculateRoutingCost() async {
    final level = await getBatteryLevel();

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

  /// Stream of battery state changes (charging, discharging, full)
  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;
}
