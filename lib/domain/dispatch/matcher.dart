import '../chain/claim_verifier.dart';
import '../chain/evaluation_chain.dart';
import '../models.dart';
import '../trust/trust_agent.dart';
import '../world.dart';

class Assignment {
  const Assignment({
    required this.sos,
    required this.primary,
    required this.primaryResult,
    required this.adjustedScore,
    required this.comparableResponders,
    this.backup,
  });

  final SosRecord sos;
  final String primary;
  final ChainResult primaryResult;
  final double adjustedScore;
  final String? backup;

  /// How many eligible responders could serve this SOS's needs well (fit >= 0.8).
  final int comparableResponders;
}

class MatchPlan {
  const MatchPlan(this.assignments, this.unmatched, this.results);

  final Map<String, Assignment> assignments;

  /// Open SOS ids with no eligible responder, with the reason.
  final Map<String, String> unmatched;

  /// Every evaluated (sosId, responderId) chain result, for diagnostics.
  final Map<(String, String), ChainResult> results;
}

/// Deterministic, scarcity-weighted distributed matcher (opportunity cost and
/// bystander effect). Every responder device runs this over its own view and
/// offers only what it is assigned, so the only medic isn't spent on a minor
/// case while a critical one waits, and not everyone waits for someone else.
class Matcher {
  const Matcher({this.chain = const EvaluationChain()});

  final EvaluationChain chain;

  static const double opportunityWeight = 0.15;
  static const double maxOpportunityPenalty = 0.6;

  MatchPlan plan({
    required List<SosRecord> openSos,
    required WorldView view,
    required Map<String, Set<String>> excluded,
    required Set<String> busyResponders,
  }) {
    final zones = chain.hazards.zones(view);
    final claims = <String, ClaimResult>{for (final s in openSos) s.id: chain.claims.verify(s, view)};
    final responders = view.beacons.values
        .where((b) => b.role == NodeRole.responder && b.available && !busyResponders.contains(b.origin))
        .toList()
      ..sort((a, b) => a.origin.compareTo(b.origin));
    final trusts = <String, TrustAssessment>{for (final r in responders) r.origin: chain.trust.assess(r.origin, view)};

    final results = <(String, String), ChainResult>{};
    for (final s in openSos) {
      for (final r in responders) {
        if (excluded[s.id]?.contains(r.origin) ?? false) continue;
        results[(s.id, r.origin)] =
            chain.evaluate(s, r, view, claim: claims[s.id], zones: zones, responderTrust: trusts[r.origin]);
      }
    }

    // Scarcity of each capability among eligible responders vs. demand from open SOS.
    final supply = <Capability, int>{};
    for (final r in responders) {
      for (final c in {...r.declaredCaps, ...trusts[r.origin]!.verifiedCaps}) {
        supply[c] = (supply[c] ?? 0) + 1;
      }
    }
    final demand = <Capability, int>{};
    for (final s in openSos) {
      for (final n in s.needs) {
        for (final e in (capabilityFit[n] ?? const <Capability, double>{}).entries) {
          if (e.value >= 0.8) demand[e.key] = (demand[e.key] ?? 0) + 1;
        }
      }
    }
    double scarcity(Capability c) => (demand[c] ?? 0) / ((supply[c] ?? 0) < 1 ? 1 : supply[c]!);

    final ordered = [...openSos]..sort((a, b) {
        final pa = a.urgency.weight * claims[a.id]!.pClaim, pb = b.urgency.weight * claims[b.id]!.pClaim;
        if (pa != pb) return pb.compareTo(pa);
        if (a.claimedAtMs != b.claimedAtMs) return a.claimedAtMs.compareTo(b.claimedAtMs);
        return a.id.compareTo(b.id);
      });

    final taken = <String>{};
    final assignments = <String, Assignment>{};
    final unmatched = <String, String>{};
    for (final s in ordered) {
      final candidates = <(String, double, ChainResult)>[];
      for (final r in responders) {
        if (taken.contains(r.origin)) continue;
        final res = results[(s.id, r.origin)];
        if (res == null || !res.eligible) continue;
        var penalty = 0.0;
        for (final c in {...r.declaredCaps, ...trusts[r.origin]!.verifiedCaps}) {
          final usefulHere = s.needs.any((n) => (capabilityFit[n]?[c] ?? 0) >= 0.5);
          if (!usefulHere) penalty += opportunityWeight * scarcity(c);
        }
        if (penalty > maxOpportunityPenalty) penalty = maxOpportunityPenalty;
        candidates.add((r.origin, res.score * (1 - penalty), res));
      }
      if (candidates.isEmpty) {
        unmatched[s.id] = responders.isEmpty ? 'NO_RESPONDERS_KNOWN' : 'NO_ELIGIBLE_RESPONDER';
        continue;
      }
      candidates.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
      final best = candidates.first;
      final comparable = candidates.where((c) => c.$3.fit >= 0.8).length;
      assignments[s.id] = Assignment(
        sos: s,
        primary: best.$1,
        primaryResult: best.$3,
        adjustedScore: best.$2,
        comparableResponders: comparable,
        backup: candidates.length > 1 ? candidates[1].$1 : null,
      );
      taken.add(best.$1);
    }
    return MatchPlan(assignments, unmatched, results);
  }
}
