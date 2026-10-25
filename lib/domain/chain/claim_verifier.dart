import '../../core/geo.dart';
import '../trust/trust_agent.dart';
import '../world.dart';

class ClaimResult {
  const ClaimResult({
    required this.pReal,
    required this.pLocation,
    required this.corroborations,
    required this.reasons,
    required this.locationLabel,
  });

  /// Probability the emergency is genuine rather than a decoy.
  final double pReal;

  /// Probability the claimed location is approximately right.
  final double pLocation;
  final int corroborations;
  final List<String> reasons;
  final String locationLabel;

  double get pClaim => pReal * pLocation;
  bool get suspectedDecoy => pReal < ClaimVerifier.decoyThreshold;
}

/// Stage 1 — Claim Verification. Location is checked for physical plausibility
/// against the hop count it arrived with; realness against independent
/// corroboration, reporter trust and behaviour.
class ClaimVerifier {
  const ClaimVerifier({this.trust = const TrustAgent()});

  final TrustAgent trust;

  static const double decoyThreshold = 0.35;

  /// Generous per-hop radio range (Wi-Fi Direct / BLE long range).
  static const double maxHopRangeM = 300;
  static const Duration freshForHopCheck = Duration(minutes: 3);
  static const double corroborationRadiusM = 600;
  static const Duration corroborationWindow = Duration(minutes: 45);
  static const double maxPlausibleSpeedMps = 40; // ~145 km/h

  ClaimResult verify(SosRecord sos, WorldView view) {
    final reasons = <String>[];
    final reporter = trust.assess(sos.origin, view);

    // ---- Location plausibility ----
    double pLoc;
    String label;
    final loc = sos.location;
    if (loc == null) {
      if (sos.geohash != null) {
        pLoc = 0.55;
        label = 'APPROX. AREA ONLY (~5 km cell)';
        reasons.add('LOCATION_COARSE');
      } else {
        pLoc = 0.5;
        label = 'LOCATION NOT PROVIDED';
        reasons.add('LOCATION_NOT_PROVIDED');
      }
    } else {
      pLoc = loc.accuracyM <= 50 ? 1.0 : (loc.accuracyM <= 500 ? 0.85 : 0.6);
      final ageMin = (view.nowMs - loc.fixedAtMs) / 60000;
      label = '±${loc.accuracyM.round()} m';
      if (ageMin > 30) {
        pLoc *= 0.8;
        label += ' · MAY BE STALE';
        reasons.add('LOCATION_STALE');
      }
      if (loc.accuracyM > 500) reasons.add('LOCATION_LOW_ACCURACY');

      // A message that reached us in h hops within minutes can't be from farther
      // than (h+1) radio ranges away. Store-and-forward (old messages) is exempt.
      final self = view.selfLocation;
      final transitMs = sos.receivedAtMs - sos.claimedAtMs;
      if (self != null && transitMs >= 0 && transitMs < freshForHopCheck.inMilliseconds) {
        final maxDist = (sos.hopAtReceipt + 1) * maxHopRangeM + loc.accuracyM + self.accuracyM;
        final dist = self.point.distanceTo(loc.point);
        if (dist > maxDist) {
          pLoc *= 0.15;
          label += ' · IMPLAUSIBLE';
          reasons.add('LOCATION_IMPLAUSIBLE(${formatDistance(dist)} away after ${sos.hopAtReceipt} hops)');
        }
      }
      // Velocity check against the same origin's other reports.
      for (final other in view.sosRecords) {
        if (other.id == sos.id || other.origin != sos.origin || other.location == null) continue;
        final dt = (sos.location!.fixedAtMs - other.location!.fixedAtMs).abs() / 1000;
        if (dt < 1) continue;
        final speed = other.location!.point.distanceTo(loc.point) / dt;
        if (speed > maxPlausibleSpeedMps) {
          pLoc *= 0.3;
          reasons.add('LOCATION_JUMP(${speed.round()} m/s between reports)');
          break;
        }
      }
    }

    // ---- Realness / decoy likelihood ----
    var pReal = 0.6 * reporter.reporterTrust / 0.7;
    if (reporter.quarantined) reasons.add('REPORTER_QUARANTINED');
    if (reporter.sybilFactor < 1) reasons.add('REPORTER_SYBIL_INDICATORS');

    final here = sos.approxPoint;
    final corroborators = <String>{};
    if (here != null) {
      for (final other in view.sosRecords) {
        if (other.origin == sos.origin) continue;
        final p = other.approxPoint;
        if (p == null || (other.claimedAtMs - sos.claimedAtMs).abs() > corroborationWindow.inMilliseconds) continue;
        if (p.distanceTo(here) <= corroborationRadiusM && !trust.assess(other.origin, view).quarantined) {
          corroborators.add(other.origin);
        }
      }
      for (final h in view.hazards) {
        if (h.origin == sos.origin) continue;
        if (h.center.distanceTo(here) <= h.radiusM + corroborationRadiusM) corroborators.add(h.origin);
      }
    }
    final corr = corroborators.length > 3 ? 3 : corroborators.length;
    pReal += 0.12 * corr;
    if (corr > 0) reasons.add('CORROBORATED_BY_$corr');

    final ownReports = view.sosRecords
        .where((s) => s.origin == sos.origin && (s.claimedAtMs - sos.claimedAtMs).abs() < 600000)
        .length;
    if (ownReports > 3) {
      pReal *= 0.6;
      reasons.add('REPEATED_REPORTS($ownReports in 10 min)');
    }
    if (reasons.any((r) => r.startsWith('LOCATION_IMPLAUSIBLE')) || pLoc < 0.2) pReal *= 0.7;

    pReal = pReal.clamp(0.02, 0.98).toDouble();
    if (pReal < decoyThreshold) reasons.add('SUSPECTED_DECOY');

    return ClaimResult(
      pReal: pReal,
      pLocation: pLoc.clamp(0.02, 1.0).toDouble(),
      corroborations: corr,
      reasons: reasons,
      locationLabel: label,
    );
  }
}
