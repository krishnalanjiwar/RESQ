import '../core/geo.dart';
import 'models.dart';
import 'triage/triage_agent.dart';

/// An SOS as known locally. Sender-supplied fields are claims.
class SosRecord {
  SosRecord({
    required this.id,
    required this.origin,
    required this.claimedAtMs,
    required this.receivedAtMs,
    required this.hopAtReceipt,
    required this.urgency,
    required this.needs,
    required this.sealed,
    required this.readable,
    this.viaEndpoint,
    this.geohash,
    this.text,
    this.location,
    this.batteryPct,
    this.displayName,
    this.triage,
    this.recipientCount = 0,
  });

  final String id;
  final String origin;
  final int claimedAtMs;
  final int receivedAtMs;
  final int hopAtReceipt;
  final String? viaEndpoint;
  final Urgency urgency;
  final Set<Need> needs;
  final String? geohash;

  /// Body was end-to-end sealed; [readable] says whether this node could open it.
  final bool sealed;
  final bool readable;
  final int recipientCount;
  final String? text;
  final LocationFix? location;
  final int? batteryPct;
  final String? displayName;
  final TriageResult? triage;

  /// Best available position: precise if readable, else the coarse geohash cell centre.
  GeoPoint? get approxPoint => location?.point ?? (geohash == null ? null : geohashCenter(geohash!));
}

class SosEventRecord {
  const SosEventRecord({
    required this.id,
    required this.sosId,
    required this.actor,
    required this.kind,
    required this.lamport,
    required this.claimedAtMs,
    required this.receivedAtMs,
    this.note,
  });

  final String id;
  final String sosId;
  final String actor;
  final SosEventKind kind;
  final int lamport;
  final int claimedAtMs;
  final int receivedAtMs;
  final String? note;
}

class BeaconRecord {
  const BeaconRecord({
    required this.origin,
    required this.role,
    required this.declaredCaps,
    required this.available,
    required this.encKey,
    required this.name,
    required this.claimedAtMs,
    required this.receivedAtMs,
    required this.hop,
    this.batteryPct,
    this.location,
    this.credential,
    this.credentialSignatureValid = false,
    this.authorityName,
    this.engagedSos = const [],
    this.viaEndpoint,
  });

  final String origin;
  final NodeRole role;
  final Set<Capability> declaredCaps;
  final bool available;
  final String encKey;
  final String name;
  final int claimedAtMs;
  final int receivedAtMs;
  final int hop;
  final int? batteryPct;
  final LocationFix? location;
  final Credential? credential;

  /// Result of verifying the embedded credential's signature at ingest time.
  final bool credentialSignatureValid;

  /// Present when the sender operates as a (demo) issuing authority.
  final String? authorityName;
  final List<String> engagedSos;
  final String? viaEndpoint;
}

class HazardRecord {
  const HazardRecord({
    required this.id,
    required this.origin,
    required this.kind,
    required this.center,
    required this.radiusM,
    required this.severity,
    required this.claimedAtMs,
    required this.receivedAtMs,
    this.note,
  });

  final String id;
  final String origin;
  final HazardKind kind;
  final GeoPoint center;
  final double radiusM;
  final int severity;
  final int claimedAtMs;
  final int receivedAtMs;
  final String? note;
}

class VouchRecord {
  const VouchRecord({required this.voucher, required this.subject, required this.receivedAtMs});

  final String voucher;
  final String subject;
  final int receivedAtMs;
}

/// Read-only view of everything a node knows. All agents are pure functions of
/// this view, which keeps them deterministic and testable.
abstract interface class WorldView {
  int get nowMs;
  String get selfId;
  LocationFix? get selfLocation;

  Map<String, BeaconRecord> get beacons;
  Iterable<SosRecord> get sosRecords;
  List<SosEventRecord> eventsFor(String sosId);
  Iterable<HazardRecord> get hazards;
  List<VouchRecord> vouchesFor(String subject);

  Set<String> get anchors;
  Set<String> get revokedCredentialIds;

  /// Identities seen originating traffic (hop 0) over each radio endpoint.
  Map<String, Set<String>> get directIdentitiesByEndpoint;
  int? firstSeenMs(String identity);

  /// Identities penalised locally (forged credential, signature failures, flooding).
  Map<String, String> get penalties;
}
