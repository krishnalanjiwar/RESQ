import '../../core/geo.dart';
import '../models.dart';
import '../trust/trust_agent.dart';
import '../world.dart';
import 'claim_verifier.dart';
import 'hazard_agent.dart';
import 'routing_cost.dart';

class StageResult {
  const StageResult(this.name, this.score, this.passed, this.reasons);

  final String name;
  final double score;
  final bool passed;
  final List<String> reasons;
}

class ChainResult {
  const ChainResult({
    required this.sosId,
    required this.responderId,
    required this.stages,
    required this.fit,
    required this.score,
    required this.eligible,
    required this.claim,
    required this.hazard,
    required this.trust,
    required this.routing,
  });

  final String sosId;
  final String responderId;

  /// In fixed order: Claim Verification, Hazard Avoidance, Trust Scoring,
  /// Battery/Routing Cost, Safe Dispatch.
  final List<StageResult> stages;
  final double fit;
  final double score;
  final bool eligible;
  final ClaimResult claim;
  final HazardResult hazard;
  final TrustAssessment trust;
  final RoutingResult routing;

  List<String> get blockingReasons => [
        for (final s in stages)
          if (!s.passed) ...s.reasons,
      ];
}

/// The probabilistic evaluation chain from the problem statement, run as one
/// domain pipeline for every (SOS, responder) pair. Deterministic: the same
/// view yields the same result on every device.
class EvaluationChain {
  const EvaluationChain({
    this.claims = const ClaimVerifier(),
    this.hazards = const HazardAgent(),
    this.trust = const TrustAgent(),
    this.routing = const RoutingCost(),
  });

  final ClaimVerifier claims;
  final HazardAgent hazards;
  final TrustAgent trust;
  final RoutingCost routing;

  static const List<String> stageNames = [
    'CLAIM VERIFICATION',
    'HAZARD AVOIDANCE',
    'TRUST SCORING',
    'BATTERY / ROUTING COST',
    'SAFE DISPATCH',
  ];

  static const Duration beaconFreshness = Duration(minutes: 5);

  ChainResult evaluate(
    SosRecord sos,
    BeaconRecord responder,
    WorldView view, {
    ClaimResult? claim,
    List<HazardZone>? zones,
    TrustAssessment? responderTrust,
  }) {
    // Stage 1 — Claim Verification.
    final c = claim ?? claims.verify(sos, view);
    final claimPassed = !c.reasons.contains('REPORTER_QUARANTINED');
    final s1 = StageResult(stageNames[0], c.pClaim, claimPassed, [
      'P(real) ${_pct(c.pReal)}',
      'P(location) ${_pct(c.pLocation)} · ${c.locationLabel}',
      ...c.reasons,
    ]);

    // Stage 2 — Hazard Avoidance.
    final t = responderTrust ?? trust.assess(responder.origin, view);
    final caps = {...responder.declaredCaps, ...t.verifiedCaps};
    final h = hazards.assess(
      target: sos.approxPoint,
      responder: responder.location?.point,
      responderCaps: caps,
      zones: zones ?? hazards.zones(view),
    );
    final s2 = StageResult(stageNames[1], h.pSafe, h.gatePassed, ['P(safe) ${_pct(h.pSafe)}', ...h.reasons]);

    // Stage 3 — Trust Scoring (receiver-computed; sender claims ignored).
    final relevant = _relevantCaps(sos.needs, caps);
    final tScore = t.capabilityTrust(relevant.isEmpty ? caps : relevant);
    final s3 = StageResult(stageNames[2], tScore, !t.quarantined, [
      t.credentialStatus.label,
      if (t.vouchCount > 0) '${t.vouchCount} VOUCH(ES)',
      ...t.reasons,
    ]);

    // Stage 4 — Battery / Routing Cost.
    final r = routing.cost(target: sos.approxPoint, responder: responder, nowMs: view.nowMs);
    final s4 = StageResult(stageNames[3], 1 / r.cost, true, ['COST ${r.cost.toStringAsFixed(2)}', ...r.reasons]);

    // Stage 5 — Safe Dispatch.
    final fit = capabilityFitFor(sos.needs, caps);
    final dispatchReasons = <String>[];
    var available = true;
    if (responder.role != NodeRole.responder) {
      available = false;
      dispatchReasons.add('NOT_A_RESPONDER');
    }
    if (!responder.available) {
      available = false;
      dispatchReasons.add('RESPONDER_UNAVAILABLE');
    }
    if (responder.engagedSos.any((id) => id != sos.id)) {
      available = false;
      dispatchReasons.add('RESPONDER_ENGAGED_ELSEWHERE');
    }
    if (view.nowMs - responder.receivedAtMs > beaconFreshness.inMilliseconds) {
      available = false;
      dispatchReasons.add('PRESENCE_EXPIRED');
    }
    if (fit < 0.2) dispatchReasons.add('NO_CAPABILITY_MATCH (general help only)');
    final score = sos.urgency.weight * c.pClaim * h.pSafe * tScore * fit / r.cost;
    final eligible = claimPassed && h.gatePassed && !t.quarantined && available;
    final s5 = StageResult(stageNames[4], score, eligible, [
      'URGENCY ${sos.urgency.label} × FIT ${_pct(fit)}',
      'SCORE ${score.toStringAsFixed(3)}',
      'HUMAN ACCEPTANCE REQUIRED',
      ...dispatchReasons,
    ]);

    return ChainResult(
      sosId: sos.id,
      responderId: responder.origin,
      stages: [s1, s2, s3, s4, s5],
      fit: fit,
      score: eligible ? score : 0,
      eligible: eligible,
      claim: c,
      hazard: h,
      trust: t,
      routing: r,
    );
  }

  /// Average best capability fit across the SOS needs. Unknown needs: any
  /// responder may review (0.6).
  static double capabilityFitFor(Set<Need> needs, Set<Capability> caps) {
    if (needs.isEmpty) return 0.6;
    var total = 0.0;
    for (final n in needs) {
      var best = 0.0;
      for (final c in caps) {
        final f = capabilityFit[n]?[c] ?? 0;
        if (f > best) best = f;
      }
      total += best;
    }
    final avg = total / needs.length;
    return avg < 0.15 ? 0.15 : avg;
  }

  static Set<Capability> _relevantCaps(Set<Need> needs, Set<Capability> caps) => {
        for (final c in caps)
          if (needs.any((n) => (capabilityFit[n]?[c] ?? 0) >= 0.5)) c,
      };

  static String _pct(double v) => '${(v * 100).round()}%';
}

/// Builds the one-line, plain-language justification shown on an offer.
class Justifier {
  const Justifier();

  String build(
    SosRecord sos,
    ChainResult r, {
    required GeoPoint? responderPoint,
    required int comparableResponders,
    required String capabilityPhrase,
  }) {
    final parts = <String>[];
    final needs = sos.needs.isEmpty ? 'unclear need (review)' : sos.needs.map((n) => n.label.toLowerCase()).join(' + ');
    parts.add('${sos.urgency.label} $needs');

    final target = sos.approxPoint;
    if (target != null && responderPoint != null) {
      parts.add('${formatDistance(responderPoint.distanceTo(target))} ${compassPoint(responderPoint.bearingTo(target))}');
    } else {
      parts.add('distance unknown');
    }

    if (comparableResponders <= 1) {
      parts.add('you are the only $capabilityPhrase in range');
    } else {
      parts.add('best match of $comparableResponders $capabilityPhrase responders');
    }

    final hz = r.hazard.reasons.where((x) => x.contains('ZONE')).length;
    if (r.hazard.atTarget.isNotEmpty) {
      parts.add('victim inside ${r.hazard.atTarget.first.kind.label.toLowerCase()} zone — you are equipped');
    } else if (hz > 0) {
      parts.add('route crosses $hz hazard zone(s) — go around');
    } else if (r.hazard.reasons.any((x) => x.startsWith('NO_HAZARD_REPORTS'))) {
      parts.add('no hazard reports known');
    } else {
      parts.add('no known hazard on path');
    }

    if (r.claim.corroborations > 0) {
      parts.add('${r.claim.corroborations} nearby report(s) corroborate');
    } else if (r.claim.suspectedDecoy) {
      parts.add('UNCORROBORATED — possible decoy');
    }
    return parts.join(' · ');
  }
}
