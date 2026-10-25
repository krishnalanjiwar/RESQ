import 'dart:math';

import '../../core/geo.dart';
import '../models.dart';
import '../trust/trust_agent.dart';
import '../world.dart';

class HazardZone {
  const HazardZone(this.kind, this.center, this.radiusM, this.confidence, this.reporters);

  final HazardKind kind;
  final GeoPoint center;
  final double radiusM;
  final double confidence;
  final int reporters;
}

class HazardResult {
  const HazardResult({required this.pSafe, required this.gatePassed, required this.reasons, required this.atTarget});

  final double pSafe;

  /// False when the responder lacks the capability a high-confidence hazard requires.
  final bool gatePassed;
  final List<String> reasons;
  final List<HazardZone> atTarget;
}

/// Stage 2 — Hazard Avoidance. Hazard zones come only from signed hazard
/// reports on the mesh, merged by independent corroboration and decayed over
/// time. With no reports the stage says so; it never implies a route is safe.
class HazardAgent {
  const HazardAgent({this.trust = const TrustAgent()});

  final TrustAgent trust;

  static const Duration halfLife = Duration(hours: 1);
  static const double gateConfidence = 0.6;

  List<HazardZone> zones(WorldView view) {
    final records = view.hazards.toList();
    final used = <int>{};
    final zones = <HazardZone>[];
    for (var i = 0; i < records.length; i++) {
      if (used.contains(i)) continue;
      final anchor = records[i];
      final members = <HazardRecord>[anchor];
      used.add(i);
      for (var j = i + 1; j < records.length; j++) {
        final r = records[j];
        if (used.contains(j) || r.kind != anchor.kind) continue;
        if (r.center.distanceTo(anchor.center) <= max(r.radiusM, anchor.radiusM)) {
          members.add(r);
          used.add(j);
        }
      }
      // Independent reporters only: one weight per origin identity.
      final byOrigin = <String, double>{};
      for (final m in members) {
        final t = trust.assess(m.origin, view);
        if (t.quarantined) continue;
        final w = (t.credentialStatus == CredentialStatus.verified ? 0.8 : 0.45) * t.sybilFactor;
        final age = max(0, view.nowMs - m.claimedAtMs);
        final decay = pow(0.5, age / halfLife.inMilliseconds).toDouble();
        final weight = w * decay * (0.7 + 0.15 * m.severity.clamp(1, 3));
        byOrigin[m.origin] = max(byOrigin[m.origin] ?? 0, weight.clamp(0, 0.95).toDouble());
      }
      if (byOrigin.isEmpty) continue;
      final conf = 1 - byOrigin.values.fold<double>(1, (acc, w) => acc * (1 - w));
      final radius = members.map((m) => m.radiusM).reduce(max);
      zones.add(HazardZone(anchor.kind, anchor.center, radius, conf, byOrigin.length));
    }
    return zones;
  }

  HazardResult assess({
    required GeoPoint? target,
    required GeoPoint? responder,
    required Set<Capability> responderCaps,
    required List<HazardZone> zones,
  }) {
    final reasons = <String>[];
    if (target == null) {
      return const HazardResult(pSafe: 0.5, gatePassed: true, reasons: ['HAZARD_UNKNOWN_NO_LOCATION'], atTarget: []);
    }
    if (zones.isEmpty) {
      return const HazardResult(
        pSafe: 0.9,
        gatePassed: true,
        reasons: ['NO_HAZARD_REPORTS_KNOWN (not a safety guarantee)'],
        atTarget: [],
      );
    }
    var pSafe = 1.0;
    var gate = true;
    final atTarget = <HazardZone>[];
    for (final z in zones) {
      final inside = z.center.distanceTo(target) <= z.radiusM;
      final equipped = hazardCapabilities[z.kind]!.any(responderCaps.contains);
      if (inside) {
        atTarget.add(z);
        if (equipped) {
          pSafe *= 1 - 0.3 * z.confidence;
          reasons.add('TARGET_IN_${z.kind.name.toUpperCase()}_ZONE (equipped)');
        } else {
          pSafe *= 1 - z.confidence;
          reasons.add('TARGET_IN_${z.kind.name.toUpperCase()}_ZONE (${(z.confidence * 100).round()}% conf, not equipped)');
          if (z.confidence >= gateConfidence) gate = false;
        }
      } else if (responder != null && segmentIntersectsCircle(responder, target, z.center, z.radiusM)) {
        pSafe *= 1 - (equipped ? 0.2 : 0.7) * z.confidence;
        reasons.add('PATH_CROSSES_${z.kind.name.toUpperCase()}_ZONE (route around)');
      }
    }
    if (reasons.isEmpty) reasons.add('NO_KNOWN_HAZARD_ON_PATH');
    if (!gate) reasons.add('HAZARD_REQUIRES_CAPABILITY');
    return HazardResult(pSafe: pSafe.clamp(0.01, 1.0).toDouble(), gatePassed: gate, reasons: reasons, atTarget: atTarget);
  }
}
