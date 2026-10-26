import '../core/geo.dart';

enum Urgency {
  critical('CRITICAL', 1.0),
  high('HIGH', 0.7),
  // Unknown is deliberately weighted above LOW: an unparsed SOS is never treated as harmless.
  unknown('UNKNOWN', 0.6),
  low('LOW', 0.3);

  const Urgency(this.label, this.weight);

  final String label;
  final double weight;

  static Urgency fromWire(Object? v) =>
      values.firstWhere((u) => u.label == v, orElse: () => Urgency.unknown);

  /// Severity class shown to people: SOS-A is life-threatening, SOS-D is minor.
  /// Unclear requests rank above minor ones, never below.
  String get sosClass => switch (this) {
        Urgency.critical => 'SOS-A',
        Urgency.high => 'SOS-B',
        Urgency.unknown => 'SOS-C',
        Urgency.low => 'SOS-D',
      };

  String get sosClassMeaning => switch (this) {
        Urgency.critical => 'Life-threatening',
        Urgency.high => 'Urgent',
        Urgency.unknown => 'Unclear — check',
        Urgency.low => 'Minor',
      };
}

enum Need {
  medical('MEDICAL'),
  waterRescue('WATER RESCUE'),
  fire('FIRE'),
  trapped('TRAPPED / SEARCH'),
  evacuation('EVACUATION'),
  supplies('SUPPLIES'),
  shelter('SHELTER');

  const Need(this.label);

  final String label;

  static Need? fromWire(Object? v) {
    for (final n in values) {
      if (n.name == v) return n;
    }
    return null;
  }
}

enum Capability {
  medicalAdvanced('MEDICAL (ADVANCED)'),
  medicalBasic('FIRST AID'),
  boat('BOAT'),
  waterRescue('WATER RESCUE'),
  swimmer('SWIMMER'),
  fire('FIREFIGHTING'),
  searchRescue('SEARCH & RESCUE'),
  vehicle('VEHICLE'),
  carry('LIFTING / STRETCHER'),
  supplies('SUPPLIES'),
  shelter('SHELTER'),
  security('SECURITY / POLICE'),
  general('GENERAL HELP');

  const Capability(this.label);

  final String label;

  static Capability? fromWire(Object? v) {
    for (final c in values) {
      if (c.name == v) return c;
    }
    return null;
  }
}

/// How well each capability serves each need (0..1). Unlisted pairs are 0.
const Map<Need, Map<Capability, double>> capabilityFit = {
  Need.medical: {Capability.medicalAdvanced: 1.0, Capability.medicalBasic: 0.6},
  Need.waterRescue: {Capability.boat: 1.0, Capability.waterRescue: 1.0, Capability.swimmer: 0.6},
  Need.fire: {Capability.fire: 1.0},
  Need.trapped: {Capability.searchRescue: 1.0, Capability.carry: 0.5, Capability.fire: 0.4},
  Need.evacuation: {Capability.vehicle: 1.0, Capability.boat: 0.8, Capability.carry: 0.6},
  Need.supplies: {Capability.supplies: 1.0, Capability.vehicle: 0.4},
  Need.shelter: {Capability.shelter: 1.0},
};

/// Capabilities that make it safe to enter each hazard kind.
const Map<HazardKind, Set<Capability>> hazardCapabilities = {
  HazardKind.flood: {Capability.boat, Capability.waterRescue, Capability.swimmer},
  HazardKind.fire: {Capability.fire},
  HazardKind.collapse: {Capability.searchRescue},
  HazardKind.other: {},
};

/// One-word profession for the requester's "who is coming" line, most
/// specialised skill first.
String professionOf(Set<Capability> caps) {
  for (final (cap, label) in const [
    (Capability.medicalAdvanced, 'Medical'),
    (Capability.medicalBasic, 'First aid'),
    (Capability.fire, 'Firefighter'),
    (Capability.waterRescue, 'Water rescue'),
    (Capability.security, 'Security'),
    (Capability.searchRescue, 'Search & rescue'),
    (Capability.boat, 'Boat'),
    (Capability.swimmer, 'Swimmer'),
  ]) {
    if (caps.contains(cap)) return label;
  }
  return 'Volunteer';
}

enum NodeRole {
  victim('VICTIM'),
  responder('RESPONDER'),
  diagnostics('DIAGNOSTICS');

  const NodeRole(this.label);

  final String label;

  static NodeRole? fromWire(Object? v) {
    for (final r in values) {
      if (r.name == v) return r;
    }
    return null;
  }
}

enum HazardKind {
  flood('FLOOD'),
  fire('FIRE'),
  collapse('COLLAPSE'),
  other('OTHER');

  const HazardKind(this.label);

  final String label;

  static HazardKind fromWire(Object? v) =>
      values.firstWhere((k) => k.name == v, orElse: () => HazardKind.other);
}

/// A location reading with its quality. Location is always an estimate.
class LocationFix {
  const LocationFix({required this.point, required this.accuracyM, required this.fixedAtMs, this.source = 'gps'});

  final GeoPoint point;
  final double accuracyM;
  final int fixedAtMs;
  final String source;

  Map<String, Object?> toJson() =>
      {...point.toJson(), 'acc': accuracyM.round(), 'at': fixedAtMs, 'src': source};

  static LocationFix? fromJson(Object? json) {
    final point = GeoPoint.fromJson(json);
    if (point == null || json is! Map) return null;
    final acc = json['acc'], at = json['at'];
    return LocationFix(
      point: point,
      accuracyM: acc is num && acc >= 0 ? acc.toDouble() : 1000,
      fixedAtMs: at is int ? at : 0,
      source: json['src'] is String ? json['src'] as String : 'unknown',
    );
  }
}

enum SosEventKind {
  accepted(1),
  enRoute(2),
  onScene(3),
  resolved(4),
  declined(0),
  standDown(0),
  heartbeat(0),
  cancelled(0),

  /// The requester's medical card, sealed to the responder who accepted.
  medicalCard(0);

  const SosEventKind(this.progress);

  /// Responder progress level used for precedence during reconciliation.
  final int progress;

  static SosEventKind? fromWire(Object? v) {
    for (final k in values) {
      if (k.name == v) return k;
    }
    return null;
  }
}

/// A signed credential issued by an authority (trust anchor) to a subject key.
class Credential {
  const Credential({
    required this.cid,
    required this.subject,
    required this.roles,
    required this.issuedAtMs,
    required this.expiresAtMs,
    required this.issuer,
    required this.issuerName,
    required this.sig,
  });

  final String cid;
  final String subject;
  final Set<Capability> roles;
  final int issuedAtMs;
  final int expiresAtMs;
  final String issuer;
  final String issuerName;
  final String sig;

  Map<String, Object?> signedBody() => {
        'cid': cid,
        'sub': subject,
        'roles': (roles.map((r) => r.name).toList()..sort()),
        'iat': issuedAtMs,
        'exp': expiresAtMs,
        'iss': issuer,
        'issName': issuerName,
      };

  Map<String, Object?> toJson() => {...signedBody(), 'sig': sig};

  static Credential? fromJson(Object? json) {
    if (json is! Map) return null;
    final roles = json['roles'];
    if (json['cid'] is! String || json['sub'] is! String || json['iss'] is! String || json['sig'] is! String) {
      return null;
    }
    if (roles is! List || json['iat'] is! int || json['exp'] is! int) return null;
    return Credential(
      cid: json['cid'] as String,
      subject: json['sub'] as String,
      roles: {for (final r in roles) ?Capability.fromWire(r)},
      issuedAtMs: json['iat'] as int,
      expiresAtMs: json['exp'] as int,
      issuer: json['iss'] as String,
      issuerName: json['issName'] is String ? json['issName'] as String : 'UNKNOWN',
      sig: json['sig'] as String,
    );
  }
}

/// The requester's medical card. Kept encrypted on the phone and shared only
/// with a responder who accepts their SOS, sealed to that responder's key.
class MedicalCard {
  const MedicalCard({
    this.bloodGroup = '',
    this.conditions = '',
    this.allergies = '',
    this.medications = '',
    this.contactName = '',
    this.contactPhone = '',
    this.notes = '',
  });

  static const int maxFieldChars = 120;
  static const List<String> bloodGroups = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final String bloodGroup;
  final String conditions;
  final String allergies;
  final String medications;
  final String contactName;
  final String contactPhone;
  final String notes;

  bool get isEmpty => toJson().isEmpty;

  Map<String, String> toJson() => {
        if (bloodGroup.isNotEmpty) 'bg': bloodGroup,
        if (conditions.isNotEmpty) 'cond': conditions,
        if (allergies.isNotEmpty) 'alg': allergies,
        if (medications.isNotEmpty) 'med': medications,
        if (contactName.isNotEmpty) 'cn': contactName,
        if (contactPhone.isNotEmpty) 'cp': contactPhone,
        if (notes.isNotEmpty) 'note': notes,
      };

  static MedicalCard? fromJson(Object? json) {
    if (json is! Map) return null;
    String f(String key) {
      final v = json[key];
      if (v is! String) return '';
      final t = v.trim();
      return t.length > maxFieldChars ? t.substring(0, maxFieldChars) : t;
    }

    final bg = f('bg');
    return MedicalCard(
      bloodGroup: bloodGroups.contains(bg) ? bg : '',
      conditions: f('cond'),
      allergies: f('alg'),
      medications: f('med'),
      contactName: f('cn'),
      contactPhone: f('cp'),
      notes: f('note'),
    );
  }
}
