import '../../core/geo.dart';
import '../world.dart';

class RoutingResult {
  const RoutingResult({required this.cost, required this.distanceM, required this.reasons});

  /// >= 1. Higher means more expensive to dispatch this responder.
  final double cost;
  final double? distanceM;
  final List<String> reasons;
}

/// Stage 4 — Battery / Routing Cost: distance, responder battery, how far away
/// in the mesh the responder is, and how stale its presence beacon is.
class RoutingCost {
  const RoutingCost();

  RoutingResult cost({required GeoPoint? target, required BeaconRecord responder, required int nowMs}) {
    final reasons = <String>[];
    var cost = 1.0;
    double? distance;
    final from = responder.location?.point;
    if (target != null && from != null) {
      distance = from.distanceTo(target);
      cost += distance / 2000;
      reasons.add('DISTANCE_${formatDistance(distance)}');
    } else {
      cost += 0.5;
      reasons.add('DISTANCE_UNKNOWN');
    }
    final bat = responder.batteryPct;
    if (bat == null) {
      cost += 0.2;
      reasons.add('BATTERY_UNKNOWN');
    } else if (bat < 15) {
      cost += 1.5;
      reasons.add('BATTERY_CRITICAL_$bat%');
    } else if (bat < 30) {
      cost += 0.5;
      reasons.add('BATTERY_LOW_$bat%');
    }
    cost += 0.08 * responder.hop;
    if (responder.hop > 2) reasons.add('MESH_HOPS_${responder.hop}');
    final ageMin = (nowMs - responder.receivedAtMs) / 60000;
    if (ageMin > 3) {
      cost += 0.3;
      reasons.add('PRESENCE_STALE_${ageMin.round()}min');
    }
    return RoutingResult(cost: cost, distanceM: distance, reasons: reasons);
  }
}
