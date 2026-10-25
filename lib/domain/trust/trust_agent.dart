import '../../protocol/limits.dart';
import '../models.dart';
import '../world.dart';

enum CredentialStatus {
  none('SELF-DECLARED'),
  verified('VERIFIED CREDENTIAL'),
  unknownIssuer('UNKNOWN ISSUER'),
  expired('CREDENTIAL EXPIRED'),
  revoked('CREDENTIAL REVOKED'),
  forged('FORGED CREDENTIAL');

  const CredentialStatus(this.label);

  final String label;
}

enum TrustLevel { verified, vouched, selfDeclared, suspicious, quarantined }

class TrustAssessment {
  const TrustAssessment({
    required this.identity,
    required this.level,
    required this.credentialStatus,
    required this.verifiedCaps,
    required this.vouchCount,
    required this.sybilFactor,
    required this.identityFactor,
    required this.reasons,
  });

  final String identity;
  final TrustLevel level;
  final CredentialStatus credentialStatus;
  final Set<Capability> verifiedCaps;
  final int vouchCount;

  /// Multiplier in (0,1]: 1 = no Sybil indicators.
  final double sybilFactor;

  /// Multiplier for identity age and local penalties.
  final double identityFactor;
  final List<String> reasons;

  bool get quarantined => level == TrustLevel.quarantined;

  /// Trust that this identity really has a capability serving [needs].
  /// Receiver-computed only; never taken from any field the sender supplies.
  double capabilityTrust(Set<Capability> claimed) {
    if (quarantined) return 0.05;
    double base;
    if (claimed.isNotEmpty && claimed.every(verifiedCaps.contains)) {
      base = 0.95;
    } else if (vouchCount > 0) {
      base = (0.45 + 0.12 * vouchCount).clamp(0, 0.8).toDouble();
    } else {
      base = 0.35;
    }
    return (base * sybilFactor * identityFactor).clamp(0.01, 1.0);
  }

  /// Trust in the identity as a reporter (victim or hazard reporter).
  double get reporterTrust {
    if (quarantined) return 0.05;
    final base = credentialStatus == CredentialStatus.verified ? 0.9 : 0.7;
    return (base * sybilFactor * identityFactor).clamp(0.01, 1.0);
  }
}

/// Receiver-side trust scoring (FR-035): credentials checked against pinned
/// trust anchors, bounded vouching, Sybil heuristics from radio-link evidence,
/// identity age and local penalties.
class TrustAgent {
  const TrustAgent();

  static const Duration newIdentityWindow = Duration(minutes: 3);
  static const Duration clusterWindow = Duration(minutes: 15);
  static const int maxCountedVouches = 3;

  CredentialStatus credentialStatus(BeaconRecord? beacon, WorldView view) {
    final cred = beacon?.credential;
    if (beacon == null || cred == null) return CredentialStatus.none;
    if (!beacon.credentialSignatureValid || cred.subject != beacon.origin) return CredentialStatus.forged;
    if (!view.anchors.contains(cred.issuer)) return CredentialStatus.unknownIssuer;
    if (view.revokedCredentialIds.contains(cred.cid)) return CredentialStatus.revoked;
    if (cred.expiresAtMs <= view.nowMs) return CredentialStatus.expired;
    return CredentialStatus.verified;
  }

  TrustAssessment assess(String identity, WorldView view) {
    final reasons = <String>[];
    final beacon = view.beacons[identity];
    final status = credentialStatus(beacon, view);
    final verifiedCaps = status == CredentialStatus.verified ? beacon!.credential!.roles : <Capability>{};

    var quarantined = false;
    final penalty = view.penalties[identity];
    if (penalty != null) {
      quarantined = true;
      reasons.add(penalty);
    }
    if (status == CredentialStatus.forged) {
      quarantined = true;
      reasons.add('FORGED_CREDENTIAL');
    } else if (status != CredentialStatus.none && status != CredentialStatus.verified) {
      reasons.add(status.name.toUpperCase());
    }

    // Sybil: many identities originating traffic over one radio link.
    var sybil = 1.0;
    for (final entry in view.directIdentitiesByEndpoint.entries) {
      if (entry.value.contains(identity) && entry.value.length >= Limits.sybilIdentitiesPerLink) {
        sybil = 0.2;
        reasons.add('SYBIL_LINK_COLLAPSE(${entry.value.length} identities on one radio link)');
        break;
      }
    }
    // Sybil: a tight cluster of brand-new identities reported through the same neighbour.
    if (sybil == 1.0 && beacon?.location != null) {
      final cluster = _colocatedCluster(beacon!, view);
      if (cluster >= Limits.colocatedClusterSize) {
        sybil = 0.4;
        reasons.add('SYBIL_COLOCATED_CLUSTER($cluster new identities within ${Limits.colocatedRadiusM.round()} m)');
      }
    }

    var identityFactor = 1.0;
    final first = view.firstSeenMs(identity);
    if (first == null || view.nowMs - first < newIdentityWindow.inMilliseconds) {
      identityFactor = 0.85;
      reasons.add('NEW_IDENTITY');
    }

    final vouchers = <String>{
      for (final v in view.vouchesFor(identity))
        if (v.voucher != identity && !view.penalties.containsKey(v.voucher)) v.voucher,
    };
    final vouchCount = vouchers.length > maxCountedVouches ? maxCountedVouches : vouchers.length;

    final TrustLevel level;
    if (quarantined) {
      level = TrustLevel.quarantined;
    } else if (sybil < 1.0) {
      level = TrustLevel.suspicious;
    } else if (status == CredentialStatus.verified) {
      level = TrustLevel.verified;
    } else if (vouchCount > 0) {
      level = TrustLevel.vouched;
    } else {
      level = TrustLevel.selfDeclared;
    }

    return TrustAssessment(
      identity: identity,
      level: level,
      credentialStatus: status,
      verifiedCaps: verifiedCaps,
      vouchCount: vouchCount,
      sybilFactor: sybil,
      identityFactor: identityFactor,
      reasons: reasons,
    );
  }

  int _colocatedCluster(BeaconRecord subject, WorldView view) {
    final p = subject.location!.point;
    var count = 0;
    for (final b in view.beacons.values) {
      final loc = b.location;
      if (loc == null || b.viaEndpoint != subject.viaEndpoint) continue;
      final first = view.firstSeenMs(b.origin);
      if (first == null || view.nowMs - first > clusterWindow.inMilliseconds) continue;
      if (loc.point.distanceTo(p) <= Limits.colocatedRadiusM) count++;
    }
    return count;
  }
}
