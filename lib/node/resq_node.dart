import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/canonical_json.dart';
import '../core/clock.dart';
import '../core/event_log.dart';
import '../core/geo.dart';
import '../core/ids.dart';
import '../crypto/identity.dart';
import '../crypto/sealed_box.dart';
import '../crypto/signatures.dart';
import '../data/resq_store.dart';
import '../domain/chain/evaluation_chain.dart';
import '../domain/chain/hazard_agent.dart';
import '../domain/dispatch/matcher.dart';
import '../domain/models.dart';
import '../domain/power/power_policy.dart';
import '../domain/reconcile/reconciler.dart';
import '../domain/triage/capability_parser.dart';
import '../domain/triage/triage_agent.dart';
import '../domain/trust/trust_agent.dart';
import '../domain/world.dart';
import '../mesh/transport.dart';
import '../protocol/envelope.dart';
import '../protocol/flow_control.dart';
import '../protocol/limits.dart';
import 'views.dart';

/// Tunables; the simulator shortens timeouts so scenarios play out quickly.
class NodeConfig {
  const NodeConfig({
    this.offerWindow = const Duration(seconds: 60),
    this.heartbeatInterval = const Duration(minutes: 2),
    this.beaconIntervalOverride,
    this.reconciler = const Reconciler(),
  });

  final Duration offerWindow;
  final Duration heartbeatInterval;
  final Duration? beaconIntervalOverride;
  final Reconciler reconciler;
}

/// The on-device agent. One instance per phone, and one per virtual node in
/// the simulator: the Red Team arena runs exactly this code.
///
/// State is event-sourced from verified, signed envelopes. Every inbound frame
/// passes: link flood guard → schema/size validation → dedupe → signature →
/// per-type validation → apply → ACK → policy-bounded relay → persist.
class ResqNode implements WorldView {
  ResqNode._({
    required this.identity,
    required this.store,
    required this.transport,
    required this.clock,
    required this.signatures,
    required this.config,
    required Set<String> provisionedAnchors,
  }) : _provisionedAnchors = provisionedAnchors;

  static Future<ResqNode> create({
    required LocalIdentity identity,
    required ResqStore store,
    required MeshTransport transport,
    required Clock clock,
    required SignatureService signatures,
    NodeConfig config = const NodeConfig(),
    Set<String> provisionedAnchors = const {},
  }) async {
    final node = ResqNode._(
      identity: identity,
      store: store,
      transport: transport,
      clock: clock,
      signatures: signatures,
      config: config,
      provisionedAnchors: provisionedAnchors,
    );
    node._loadSettings();
    await node._replay();
    return node;
  }

  final LocalIdentity identity;
  final ResqStore store;
  final MeshTransport transport;
  final Clock clock;
  final SignatureService signatures;
  final NodeConfig config;
  final EventLog log = EventLog();

  static const TriageAgent _triage = TriageAgent();
  static const CapabilityParser _capParser = CapabilityParser();
  static const TrustAgent _trust = TrustAgent();
  static const Matcher _matcher = Matcher();
  static const Justifier _justifier = Justifier();

  // ---- Local settings (persisted in meta) ----
  NodeRole? _role;
  String _displayName = '';
  String _profileText = '';
  CapabilityParse _profile = const CapabilityParse({}, [], unrecognized: false);
  bool _available = true;
  String? _authorityName;
  Credential? _myCredential;
  final Set<String> _provisionedAnchors;
  final Set<String> _pinnedAnchors = {};
  int _lamport = 0;
  LocationFix? _selfLocation;
  int? _realBattery;
  int? _batteryOverride;
  MedicalCard? _medicalCard;

  /// Medical cards requesters sealed to this phone: sosId -> (sender, card).
  final Map<String, (String, MedicalCard)> _receivedCards = {};

  /// `sosId|responder` pairs this requester already sent its card to.
  final Set<String> _cardsSent = {};

  // ---- Knowledge (rebuilt from envelopes) ----
  final Map<String, Envelope> _live = {};
  final Map<String, StoredEnvelope> _meta = {};
  final Map<String, SosRecord> _sos = {};
  final Map<String, Map<String, SosEventRecord>> _events = {};
  final Map<String, BeaconRecord> _beacons = {};
  final Map<String, String> _beaconEnvelopeByOrigin = {};
  final Map<String, HazardRecord> _hazards = {};
  final Map<String, Map<String, VouchRecord>> _vouches = {};
  final Set<String> _revoked = {};
  final Map<String, int> _firstSeen = {};
  final Map<String, Set<String>> _directIdentities = {};
  final Map<String, String> _penalties = {};
  final Map<String, int> _penaltyUntil = {};
  static const Duration penaltyDuration = Duration(hours: 24);
  final Map<String, String> _endpointIdentity = {};
  final Map<String, int> _authFailuresByEndpoint = {};

  /// Recent (sender ts - local now) offsets from direct neighbours, for the clock warning.
  final List<int> _clockOffsets = [];

  // ---- Own-message delivery evidence (persisted) ----
  final Map<String, Set<String>> _sentTo = {};
  final Map<String, Set<String>> _ackedBy = {};

  // ---- Offer windows ----
  final Map<String, int> _assignmentSeenAt = {};
  final Map<String, Set<String>> _lapsed = {};

  // ---- Mesh flow control ----
  final SeenCache _seen = SeenCache();
  final FloodGuard _linkGuard = FloodGuard(
    capacity: Limits.linkBurst,
    refillPerSecond: Limits.linkMessagesPerSecond,
    strikesBeforeQuarantine: Limits.linkStrikesBeforeQuarantine,
    quarantine: Limits.linkQuarantine,
  );
  final WindowCounter _originSos = WindowCounter(const Duration(minutes: 10));
  final WindowCounter _originEvents = WindowCounter(const Duration(minutes: 10));

  StreamSubscription<TransportEvent>? _transportSub;
  final StreamController<void> _changes = StreamController.broadcast();
  int _version = 0;
  int _lastBeaconMs = -1 << 40;
  final Map<String, int> _lastHeartbeat = {};
  bool _transportRunning = false;
  String _transportDetail = 'not started';

  // ---- Derived-view cache ----
  int _cacheVersion = -1;
  Map<String, SosState> _states = {};
  MatchPlan _plan = const MatchPlan({}, {}, {});
  List<HazardZone> _zones = const [];

  Stream<void> get changes => _changes.stream;
  int get version => _version;

  void _changed() {
    _version++;
    if (!_changes.isClosed) _changes.add(null);
  }

  // =====================================================================
  // WorldView
  // =====================================================================

  @override
  int get nowMs => clock.nowMs();

  @override
  String get selfId => identity.id;

  @override
  LocationFix? get selfLocation => _selfLocation;

  @override
  Map<String, BeaconRecord> get beacons => _beacons;

  @override
  Iterable<SosRecord> get sosRecords => _sos.values;

  @override
  List<SosEventRecord> eventsFor(String sosId) => _events[sosId]?.values.toList() ?? const [];

  @override
  Iterable<HazardRecord> get hazards => _hazards.values;

  @override
  List<VouchRecord> vouchesFor(String subject) => _vouches[subject]?.values.toList() ?? const [];

  @override
  Set<String> get anchors => {..._provisionedAnchors, ..._pinnedAnchors};

  @override
  Set<String> get revokedCredentialIds => _revoked;

  @override
  Map<String, Set<String>> get directIdentitiesByEndpoint => _directIdentities;

  @override
  int? firstSeenMs(String identity) => identity == selfId ? 0 : _firstSeen[identity];

  @override
  Map<String, String> get penalties => _penalties;

  // =====================================================================
  // Lifecycle
  // =====================================================================

  Future<void> start() async {
    _transportSub ??= transport.events.listen(_onTransport);
    // Running state is set only by the transport's own status events, so a
    // radio that failed to start is never reported as running.
    await transport.start(_meshName());
    log.add(nowMs, LogCategory.mesh, 'TRANSPORT_START', transport.label);
    _changed();
  }

  Future<void> stop() async {
    await transport.stop();
    _transportRunning = false;
    _changed();
  }

  Future<void> dispose() async {
    await _transportSub?.cancel();
    await _changes.close();
  }

  /// Endpoint name advertised over the radio: short key prefix + role, never personal data.
  String _meshName() => 'resq-${identity.id.substring(0, 10)}';

  /// Periodic housekeeping; the host calls this every few seconds (sim: every step).
  Future<void> tick() async {
    final now = nowMs;
    _prune(now);
    final policy = powerPolicy;
    await transport.setLowPower(policy.mode == PowerMode.low || policy.mode == PowerMode.critical);

    final interval = config.beaconIntervalOverride ?? policy.beaconInterval;
    if (_role != null && now - _lastBeaconMs >= interval.inMilliseconds) {
      _lastBeaconMs = now;
      await _publishBeacon();
    }

    _refreshViews();
    await _shareMedicalCards();
    // Heartbeats keep an assignment alive so peers don't treat it as orphaned.
    for (final s in _states.values) {
      final track = s.tracks[selfId];
      if (track == null || track.progress == 0 || track.progress >= SosEventKind.resolved.progress) continue;
      if (track.withdrawn || !s.isActive) continue;
      final last = _lastHeartbeat[s.sosId] ?? 0;
      if (now - last >= config.heartbeatInterval.inMilliseconds) {
        _lastHeartbeat[s.sosId] = now;
        await _publishEvent(s.sosId, SosEventKind.heartbeat);
      }
    }

    // Offer windows: an offer nobody acts on rolls over to the next candidate.
    // A lapse never accepts, rejects or dispatches anything.
    for (final a in _plan.assignments.values) {
      final key = '${a.sos.id}|${a.primary}';
      final seen = _assignmentSeenAt.putIfAbsent(key, () => now);
      if (now - seen > config.offerWindow.inMilliseconds) {
        if (_lapsed.putIfAbsent(a.sos.id, () => {}).add(a.primary)) {
          log.add(now, LogCategory.dispatch, 'OFFER_WINDOW_LAPSED', 'offer moved to next candidate');
          _invalidate();
        }
      }
    }
    _changed();
  }

  // =====================================================================
  // Settings
  // =====================================================================

  NodeRole? get role => _role;
  String get displayName => _displayName;
  String get profileText => _profileText;
  CapabilityParse get profile => _profile;
  bool get available => _available;
  String? get authorityName => _authorityName;
  Credential? get myCredential => _myCredential;
  Set<String> get pinnedAnchors => Set.unmodifiable(_pinnedAnchors);
  Set<String> get provisionedAnchors => Set.unmodifiable(_provisionedAnchors);
  int? get realBattery => _realBattery;
  int? get batteryOverride => _batteryOverride;
  PowerPolicy get powerPolicy => PowerPolicy(realLevel: _realBattery, overrideLevel: _batteryOverride);
  bool get transportRunning => _transportRunning;
  String get transportDetail => _transportDetail;

  void _loadSettings() {
    _role = NodeRole.fromWire(store.getMeta('role'));
    _displayName = store.getMeta('name') ?? '';
    _profileText = store.getMeta('profile') ?? '';
    _profile = _capParser.parse(_profileText);
    _available = store.getMeta('available') != 'false';
    _authorityName = store.getMeta('authority');
    _lamport = int.tryParse(store.getMeta('lamport') ?? '') ?? 0;
    final cred = store.getMeta('my_credential');
    if (cred != null) _myCredential = Credential.fromJson(jsonDecode(cred));
    final card = store.getMeta('medical_card');
    if (card != null) _medicalCard = MedicalCard.fromJson(jsonDecode(card));
    final sent = store.getMeta('cards_sent');
    if (sent != null) _cardsSent.addAll((jsonDecode(sent) as List).cast<String>());
    final pinned = store.getMeta('pinned_anchors');
    if (pinned != null) _pinnedAnchors.addAll((jsonDecode(pinned) as List).cast<String>());
    final penalties = store.getMeta('penalties');
    if (penalties != null) {
      final now = clock.nowMs();
      final m = jsonDecode(penalties) as Map<String, dynamic>;
      for (final e in m.entries) {
        final v = e.value as Map<String, dynamic>;
        if ((v['until'] as int) > now) {
          _penalties[e.key] = v['reason'] as String;
          _penaltyUntil[e.key] = v['until'] as int;
        }
      }
    }
    final delivery = store.getMeta('delivery');
    if (delivery != null) {
      final m = jsonDecode(delivery) as Map<String, dynamic>;
      for (final e in m.entries) {
        final v = e.value as Map<String, dynamic>;
        _sentTo[e.key] = (v['s'] as List).cast<String>().toSet();
        _ackedBy[e.key] = (v['a'] as List).cast<String>().toSet();
      }
    }
  }

  Future<void> setRole(NodeRole role) async {
    _role = role;
    await store.putMeta('role', role.name);
    _lastBeaconMs = -1 << 40;
    _invalidate();
    _changed();
  }

  /// Back to the welcome screen. Stored SOS, events and identity are kept;
  /// this phone simply stops announcing a role until one is chosen again.
  Future<void> clearRole() async {
    _role = null;
    await store.deleteMeta('role');
    _invalidate();
    _changed();
  }

  MedicalCard? get medicalCard => _medicalCard;

  /// Saved in the encrypted store; never broadcast. See [_shareMedicalCards].
  Future<void> setMedicalCard(MedicalCard card) async {
    _medicalCard = card.isEmpty ? null : card;
    if (_medicalCard == null) {
      await store.deleteMeta('medical_card');
    } else {
      await store.putMeta('medical_card', jsonEncode(card.toJson()));
    }
    _changed();
  }

  /// True once this requester's card went to at least one accepting responder.
  bool medicalCardSentFor(String sosId) => _cardsSent.any((k) => k.startsWith('$sosId|'));

  /// The requester's medical card for [sosId], if they sealed one to this phone.
  MedicalCard? receivedCardFor(String sosId) {
    final entry = _receivedCards[sosId];
    if (entry == null || _sos[sosId]?.origin != entry.$1) return null;
    return entry.$2;
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name.trim().length > 40 ? name.trim().substring(0, 40) : name.trim();
    await store.putMeta('name', _displayName);
    _changed();
  }

  Future<void> setProfile(String text) async {
    _profileText = text.length > Limits.maxProfileTextChars ? text.substring(0, Limits.maxProfileTextChars) : text;
    _profile = _capParser.parse(_profileText);
    await store.putMeta('profile', _profileText);
    _lastBeaconMs = -1 << 40;
    _changed();
  }

  Future<void> setAvailable(bool value) async {
    _available = value;
    await store.putMeta('available', '$value');
    _lastBeaconMs = -1 << 40;
    _changed();
  }

  void setSelfLocation(LocationFix? fix) {
    _selfLocation = fix;
    _invalidate();
  }

  void setRealBattery(int? level) {
    _realBattery = level;
    _invalidate();
  }

  /// Diagnostics-only override; the real reading is untouched and shown separately.
  void setBatteryOverride(int? level) {
    _batteryOverride = level;
    log.add(nowMs, LogCategory.power, level == null ? 'BATTERY_OVERRIDE_CLEARED' : 'BATTERY_OVERRIDE_SET', 'simulated');
    _changed();
  }

  // =====================================================================
  // Transport handling
  // =====================================================================

  void _onTransport(TransportEvent e) {
    switch (e) {
      case PeerConnected(:final endpointId):
        log.add(nowMs, LogCategory.mesh, 'PEER_CONNECTED', endpointId.length > 6 ? endpointId.substring(0, 6) : endpointId);
        unawaited(_onPeerConnected(endpointId));
      case PeerDisconnected(:final endpointId):
        log.add(nowMs, LogCategory.mesh, 'PEER_DISCONNECTED');
        _endpointIdentity.remove(endpointId);
        _directIdentities.remove(endpointId);
        _linkGuard.forget(endpointId);
        _invalidate();
        _changed();
      case FrameReceived(:final endpointId, :final bytes):
        unawaited(_onFrame(endpointId, bytes));
      case TransportStatus(:final running, :final detail):
        _transportRunning = running;
        _transportDetail = detail;
        log.add(nowMs, LogCategory.mesh, running ? 'TRANSPORT_STATUS' : 'TRANSPORT_DOWN', detail);
        _changed();
    }
  }

  Future<void> _onPeerConnected(String endpoint) async {
    await _sendLinkLocal(endpoint, MsgType.hello, {
      'enc': identity.public.encKey,
      'role': _role?.name ?? 'unset',
    });
    // Store-and-forward: replay live messages to the new neighbour. This is
    // also how partitions heal; dedupe on the far side drops what it knows.
    final now = nowMs;
    final batch = _live.values.where((env) => !env.isExpired(now)).toList()
      ..sort((a, b) => _syncPriority(a).compareTo(_syncPriority(b)));
    var sent = 0;
    for (final env in batch) {
      if (sent >= powerPolicy.syncBatch) break;
      final own = env.origin == selfId;
      if (!own && env.ttl <= 0) continue;
      if (!own && !powerPolicy.shouldRelay(env)) continue;
      final ok = await transport.send(endpoint, (own ? env : env.relayed()).toWire());
      if (ok) {
        sent++;
        if (own) _recordSent(env.id, endpoint);
      }
    }
    if (sent > 0) log.add(now, LogCategory.mesh, 'SYNC_SENT', '$sent frames');
    _changed();
  }

  int _syncPriority(Envelope env) {
    final own = env.origin == selfId ? 0 : 100;
    final type = switch (env.type) {
      MsgType.sos => env.urg == 'CRITICAL' ? 0 : (env.urg == 'LOW' ? 3 : 1),
      MsgType.event => 2,
      MsgType.revocation => 4,
      MsgType.credential => 5,
      MsgType.hazard => 6,
      MsgType.vouch => 7,
      MsgType.beacon => 8,
      MsgType.hello || MsgType.ack => 9,
    };
    return own + type;
  }

  Future<void> _onFrame(String endpoint, Uint8List bytes) async {
    final now = nowMs;
    final flood = _linkGuard.check(endpoint, now);
    if (flood != null) {
      if (flood == 'QUARANTINED_NOW') {
        for (final id in _directIdentities[endpoint] ?? const <String>{}) {
          _penalise(id, 'LINK_FLOODING');
        }
        log.add(now, LogCategory.security, 'LINK_QUARANTINED', 'flood/battery-drain attempt blocked');
        _invalidate();
        _changed();
      } else if (flood == 'RATE_LIMITED') {
        log.add(now, LogCategory.security, 'LINK_RATE_LIMITED');
      }
      return;
    }

    final decoded = decodeFrame(bytes, nowMs: now);
    final env = decoded.envelope;
    if (env == null) {
      log.add(now, LogCategory.security, 'FRAME_REJECTED', decoded.error ?? '');
      return;
    }
    if (_seen.contains(env.id)) {
      log.add(now, LogCategory.mesh, 'DUPLICATE_DROPPED');
      return;
    }
    final valid = await signatures.verify(env.signingBytes, env.sig, env.origin);
    if (!valid) {
      final failures = (_authFailuresByEndpoint[endpoint] ?? 0) + 1;
      _authFailuresByEndpoint[endpoint] = failures;
      log.add(now, LogCategory.security, 'MESSAGE_AUTHENTICATION_FAILED', 'type ${env.type.wire}');
      if (failures >= 3) {
        for (final id in _directIdentities[endpoint] ?? const <String>{}) {
          _penalise(id, 'SIGNATURE_FAILURES');
        }
        _invalidate();
      }
      return;
    }
    if (!_seen.add(env.id, env.exp)) return;

    if (env.hop == 0) {
      _directIdentities.putIfAbsent(endpoint, () => {}).add(env.origin);
      _clockOffsets.add(env.ts - now);
      if (_clockOffsets.length > 30) _clockOffsets.removeAt(0);
    }
    _firstSeen.putIfAbsent(env.origin, () => now);

    final keep = await _apply(env, receivedAt: now, via: endpoint, fromNetwork: true);

    if (env.hop == 0 && (env.type == MsgType.sos || env.type == MsgType.event)) {
      await _sendLinkLocal(endpoint, MsgType.ack, {'of': env.id});
    }
    if (!keep || env.type.isLinkLocal) {
      _changed();
      return;
    }

    if (env.ttl > 0 && powerPolicy.shouldRelay(env) && _withinOriginLimits(env, now)) {
      final relayed = env.relayed().toWire();
      for (final peer in transport.connectedPeers) {
        if (peer != endpoint) await transport.send(peer, relayed);
      }
    }
    _invalidate();
    // Someone accepted our SOS: send them the medical card now, not at the next tick.
    if (env.type == MsgType.event && env.body['kind'] == SosEventKind.accepted.name && _medicalCard != null) {
      final sosId = env.body['sos'];
      if (sosId is String && _sos[sosId]?.origin == selfId) await _shareMedicalCards();
    }
    _changed();
  }

  void _penalise(String identity, String reason) {
    _penalties[identity] = reason;
    _penaltyUntil[identity] = nowMs + penaltyDuration.inMilliseconds;
    unawaited(store.putMeta('penalties', jsonEncode({
      for (final e in _penalties.entries) e.key: {'reason': e.value, 'until': _penaltyUntil[e.key] ?? 0},
    })));
  }

  bool _withinOriginLimits(Envelope env, int now) {
    if (env.type == MsgType.sos && _originSos.hit(env.origin, now) > Limits.originSosPerTenMinutes) {
      log.add(now, LogCategory.security, 'ORIGIN_SOS_RATE_LIMIT', 'not relayed');
      return false;
    }
    if (env.type == MsgType.event && _originEvents.hit(env.origin, now) > Limits.originEventsPerTenMinutes) {
      log.add(now, LogCategory.security, 'ORIGIN_EVENT_RATE_LIMIT', 'not relayed');
      return false;
    }
    return true;
  }

  // =====================================================================
  // Applying verified envelopes
  // =====================================================================

  /// Validates per-type content and updates knowledge. Returns whether the
  /// envelope is kept (stored and eligible for relay).
  Future<bool> _apply(Envelope env, {required int receivedAt, String? via, required bool fromNetwork}) async {
    final b = env.body;
    switch (env.type) {
      case MsgType.hello:
        if (via != null) {
          _endpointIdentity[via] = env.origin;
          _directIdentities.putIfAbsent(via, () => {}).add(env.origin);
        }
        return false;

      case MsgType.ack:
        final of = b['of'];
        if (of is String && _sentTo.containsKey(of) && env.hop == 0) {
          _ackedBy.putIfAbsent(of, () => {}).add(env.origin);
          await _saveDelivery();
        }
        return false;

      case MsgType.beacon:
        return _applyBeacon(env, receivedAt, via);

      case MsgType.sos:
        final record = await _decodeSos(env, receivedAt, via);
        if (record == null) return false;
        _sos[env.id] = record;
        _keep(env, receivedAt, via, fromNetwork);
        return true;

      case MsgType.event:
        final sosId = b['sos'], kind = SosEventKind.fromWire(b['kind']), lam = b['lam'];
        if (sosId is! String || !messageIdPattern.hasMatch(sosId) || kind == null || lam is! int || lam < 0) {
          log.add(receivedAt, LogCategory.security, 'EVENT_INVALID');
          return false;
        }
        if (lam > _lamport) _lamport = lam;
        if (kind == SosEventKind.medicalCard && b['card'] is Map<String, dynamic>) {
          final opened = await SealedBox.open(b['card'] as Map<String, dynamic>, identity, aad: utf8.encode(env.id));
          if (opened != null) {
            try {
              final card = MedicalCard.fromJson(jsonDecode(utf8.decode(opened)));
              if (card != null) _receivedCards[sosId] = (env.origin, card);
            } on Object {
              log.add(receivedAt, LogCategory.security, 'MEDICAL_CARD_INVALID');
            }
          }
        }
        final note = b['note'];
        _events.putIfAbsent(sosId, () => {})[env.id] = SosEventRecord(
          id: env.id,
          sosId: sosId,
          actor: env.origin,
          kind: kind,
          lamport: lam,
          claimedAtMs: env.ts,
          receivedAtMs: receivedAt,
          note: note is String && note.length <= Limits.maxNoteChars ? note : null,
        );
        _keep(env, receivedAt, via, fromNetwork);
        return true;

      case MsgType.hazard:
        final center = GeoPoint.fromJson(b);
        final r = b['r'], sev = b['sev'];
        if (center == null || r is! num || sev is! int) return false;
        _hazards[env.id] = HazardRecord(
          id: env.id,
          origin: env.origin,
          kind: HazardKind.fromWire(b['kind']),
          center: center,
          radiusM: r.toDouble().clamp(20, 2000).toDouble(),
          severity: sev.clamp(1, 3),
          claimedAtMs: env.ts,
          receivedAtMs: receivedAt,
        );
        _keep(env, receivedAt, via, fromNetwork);
        return true;

      case MsgType.credential:
        final cred = Credential.fromJson(b['cred']);
        if (cred == null || cred.issuer != env.origin) return false;
        if (cred.subject == selfId) {
          final ok = await signatures.verify(canonicalBytes(cred.signedBody()), cred.sig, cred.issuer);
          if (ok) {
            _myCredential = cred;
            await store.putMeta('my_credential', jsonEncode(cred.toJson()));
            _lastBeaconMs = -1 << 40;
            log.add(receivedAt, LogCategory.trust, 'CREDENTIAL_RECEIVED',
                anchors.contains(cred.issuer) ? 'issuer pinned' : 'issuer NOT pinned');
          }
        }
        _keep(env, receivedAt, via, fromNetwork);
        return true;

      case MsgType.revocation:
        final cid = b['cid'];
        if (cid is! String) return false;
        if (!anchors.contains(env.origin)) {
          log.add(receivedAt, LogCategory.trust, 'REVOCATION_IGNORED', 'issuer not a trust anchor');
          return true; // still relay: others may trust this issuer
        }
        _revoked.add(cid);
        if (_myCredential?.cid == cid) log.add(receivedAt, LogCategory.trust, 'MY_CREDENTIAL_REVOKED');
        _keep(env, receivedAt, via, fromNetwork);
        return true;

      case MsgType.vouch:
        final sub = b['sub'];
        if (sub is! String || sub == env.origin) return false;
        _vouches.putIfAbsent(sub, () => {})[env.origin] =
            VouchRecord(voucher: env.origin, subject: sub, receivedAtMs: receivedAt);
        _keep(env, receivedAt, via, fromNetwork);
        return true;
    }
  }

  void _keep(Envelope env, int receivedAt, String? via, bool persist) {
    _live[env.id] = env;
    final stored = StoredEnvelope(json: env.toStorage(), receivedAtMs: receivedAt, via: via, hopAtReceipt: env.hop);
    _meta[env.id] = stored;
    if (persist && env.type != MsgType.beacon) unawaited(store.putEnvelope(env.id, stored));
  }

  Future<bool> _applyBeacon(Envelope env, int receivedAt, String? via) async {
    final b = env.body;
    final role = NodeRole.fromWire(b['role']);
    final enc = b['enc'];
    if (role == null || enc is! String) return false;
    final existing = _beacons[env.origin];
    if (existing != null && existing.claimedAtMs >= env.ts) return false;

    final caps = <Capability>{
      if (b['caps'] is List)
        for (final c in (b['caps'] as List).take(12)) ?Capability.fromWire(c),
    };
    final cred = Credential.fromJson(b['cred']);
    var credValid = false;
    if (cred != null) {
      credValid = await signatures.verify(canonicalBytes(cred.signedBody()), cred.sig, cred.issuer);
      if (!credValid || cred.subject != env.origin) {
        _penalise(env.origin, 'FORGED_CREDENTIAL');
        log.add(receivedAt, LogCategory.security, 'FORGED_CREDENTIAL', 'identity ${shortKey(env.origin)} quarantined');
      }
    }
    final bat = b['bat'];
    final name = b['name'];
    final auth = b['auth'];
    _beacons[env.origin] = BeaconRecord(
      origin: env.origin,
      role: role,
      declaredCaps: caps,
      available: b['avail'] == true,
      encKey: enc,
      name: name is String && name.length <= 40 ? name : '',
      claimedAtMs: env.ts,
      receivedAtMs: receivedAt,
      hop: env.hop,
      batteryPct: bat is int && bat >= 0 && bat <= 100 ? bat : null,
      location: LocationFix.fromJson(b['loc']),
      credential: cred,
      credentialSignatureValid: credValid,
      authorityName: auth is String && auth.length <= 40 ? auth : null,
      engagedSos: b['eng'] is List ? (b['eng'] as List).whereType<String>().take(4).toList() : const [],
      viaEndpoint: via,
    );
    final previous = _beaconEnvelopeByOrigin[env.origin];
    if (previous != null) {
      _live.remove(previous);
      _meta.remove(previous);
    }
    _beaconEnvelopeByOrigin[env.origin] = env.id;
    _keep(env, receivedAt, via, false);
    return true;
  }

  Future<SosRecord?> _decodeSos(Envelope env, int receivedAt, String? via) async {
    final b = env.body;
    final needs = <Need>{
      if (b['needs'] is List)
        for (final n in (b['needs'] as List).take(8)) ?Need.fromWire(n),
    };
    Map<String, dynamic>? inner;
    var sealed = false;
    var recipients = 0;
    if (b['open'] is Map<String, dynamic>) {
      inner = b['open'] as Map<String, dynamic>;
    } else if (b['sealed'] is Map<String, dynamic>) {
      sealed = true;
      final box = b['sealed'] as Map<String, dynamic>;
      recipients = box['r'] is List ? (box['r'] as List).length : 0;
      final opened = await SealedBox.open(box, identity, aad: utf8.encode(env.id));
      if (opened != null) {
        try {
          inner = jsonDecode(utf8.decode(opened)) as Map<String, dynamic>;
        } on Object {
          inner = null;
        }
      }
    }

    if (inner == null && env.origin == selfId) {
      final own = store.getMeta('own_sos:${env.id}');
      if (own != null) inner = jsonDecode(own) as Map<String, dynamic>;
    }

    String? text;
    LocationFix? loc;
    int? bat;
    String? name;
    TriageResult? triage;
    var urgency = Urgency.fromWire(env.urg);
    if (inner != null) {
      final t = inner['text'];
      if (t is String) text = t.length > Limits.maxSosTextChars ? t.substring(0, Limits.maxSosTextChars) : t;
      loc = LocationFix.fromJson(inner['loc']);
      final bb = inner['bat'];
      bat = bb is int && bb >= 0 && bb <= 100 ? bb : null;
      final nn = inner['name'];
      name = nn is String && nn.length <= 40 ? nn : null;
      // Receiver-side triage: the sender's urgency label is a claim; we
      // recompute from the text and never lower it below what the text supports.
      if (text != null) {
        triage = _triage.analyze(text);
        urgency = triage.urgency;
        needs.addAll(triage.needs);
      }
    }
    return SosRecord(
      id: env.id,
      origin: env.origin,
      claimedAtMs: env.ts,
      receivedAtMs: receivedAt,
      hopAtReceipt: env.hop,
      viaEndpoint: via,
      urgency: urgency,
      needs: needs,
      geohash: env.gh,
      sealed: sealed,
      readable: inner != null,
      recipientCount: recipients,
      text: text,
      location: loc,
      batteryPct: bat,
      displayName: name,
      triage: triage,
    );
  }

  // =====================================================================
  // Originating messages
  // =====================================================================

  Future<Envelope> _publish(
    MsgType type,
    Map<String, Object?> body, {
    String? gh,
    String? urg,
    int ttl = Limits.maxTtl,
    Duration? lifetime,
    String? id,
  }) async {
    final now = nowMs;
    id ??= newMessageId();
    final exp = now + (lifetime ?? type.maxLifetime).inMilliseconds;
    final fields = Envelope.signedFields(id: id, type: type, origin: selfId, ts: now, exp: exp, body: body, gh: gh, urg: urg);
    final sig = await signatures.sign(canonicalBytes(fields), identity);
    final env = Envelope(
      id: id, type: type, origin: selfId, ts: now, exp: exp, ttl: ttl, hop: 0, body: body, sig: sig, gh: gh, urg: urg,
    );
    _seen.add(id, exp);
    if (type == MsgType.sos || type == MsgType.event) {
      _sentTo.putIfAbsent(id, () => {});
      _ackedBy.putIfAbsent(id, () => {});
    }
    await _apply(env, receivedAt: now, fromNetwork: true);
    final wire = env.toWire();
    for (final peer in transport.connectedPeers) {
      if (await transport.send(peer, wire)) _recordSent(id, peer);
    }
    if (type == MsgType.sos) await _saveDelivery();
    _invalidate();
    _changed();
    return env;
  }

  void _recordSent(String id, String peer) {
    final set = _sentTo[id];
    if (set != null) set.add(peer);
  }

  Future<void> _saveDelivery() async {
    final ownSos = {for (final s in _sos.values) if (s.origin == selfId) s.id};
    final m = {
      for (final id in _sentTo.keys)
        if (ownSos.contains(id)) id: {'s': _sentTo[id]!.toList(), 'a': (_ackedBy[id] ?? {}).toList()},
    };
    await store.putMeta('delivery', jsonEncode(m));
  }

  Future<void> _sendLinkLocal(String endpoint, MsgType type, Map<String, Object?> body) async {
    final now = nowMs;
    final id = newMessageId();
    final exp = now + type.maxLifetime.inMilliseconds;
    final fields = Envelope.signedFields(id: id, type: type, origin: selfId, ts: now, exp: exp, body: body);
    final sig = await signatures.sign(canonicalBytes(fields), identity);
    final env = Envelope(id: id, type: type, origin: selfId, ts: now, exp: exp, ttl: 0, hop: 0, body: body, sig: sig);
    await transport.send(endpoint, env.toWire());
  }

  Future<void> _publishBeacon() async {
    final role = _role;
    if (role == null) return;
    final loc = _selfLocation;
    _refreshViews();
    final engaged = [
      for (final s in _states.values)
        if (s.isActive && s.primary == selfId) s.sosId,
    ];
    await _publish(MsgType.beacon, {
      'role': role.name,
      'caps': role == NodeRole.responder ? (_profile.capabilities.map((c) => c.name).toList()..sort()) : <String>[],
      'avail': role == NodeRole.responder && _available,
      'enc': identity.public.encKey,
      'name': _displayName,
      if (_realBattery != null) 'bat': _realBattery,
      // Beacon location is rounded to ~100 m: enough for matching, less precise than an SOS.
      if (loc != null)
        'loc': {
          'lat': (loc.point.lat * 1000).round() / 1000,
          'lng': (loc.point.lng * 1000).round() / 1000,
          'acc': loc.accuracyM < 100 ? 100 : loc.accuracyM.round(),
          'at': loc.fixedAtMs,
        },
      if (_myCredential != null) 'cred': _myCredential!.toJson(),
      if (_authorityName != null) 'auth': _authorityName,
      'eng': engaged,
    }, ttl: 3);
  }

  Future<void> _publishEvent(String sosId, SosEventKind kind, {String? note, Map<String, Object?>? extra, String? id}) async {
    _lamport++;
    await store.putMeta('lamport', '$_lamport');
    await _publish(
      MsgType.event,
      {
        'sos': sosId,
        'kind': kind.name,
        'lam': _lamport,
        if (note != null && note.isNotEmpty)
          'note': note.length > Limits.maxNoteChars ? note.substring(0, Limits.maxNoteChars) : note,
        ...?extra,
      },
      lifetime: kind == SosEventKind.heartbeat ? Limits.heartbeatLifetime : null,
      id: id,
    );
  }

  /// Sends this requester's medical card to each responder who accepted one of
  /// its SOS, sealed to that responder alone. Relays see only an opaque blob.
  Future<void> _shareMedicalCards() async {
    final card = _medicalCard;
    if (card == null) return;
    for (final st in states.values) {
      final sos = _sos[st.sosId];
      if (sos == null || sos.origin != selfId || !st.isActive) continue;
      for (final t in st.tracks.values) {
        if (t.progress < SosEventKind.accepted.progress || t.withdrawn) continue;
        final key = '${st.sosId}|${t.responder}';
        final encKey = _beacons[t.responder]?.encKey;
        if (encKey == null || _cardsSent.contains(key)) continue;
        _cardsSent.add(key);
        final id = newMessageId();
        try {
          final sealed = await SealedBox.seal(utf8.encode(jsonEncode(card.toJson())), [encKey], aad: utf8.encode(id));
          await _publishEvent(st.sosId, SosEventKind.medicalCard, extra: {'card': sealed}, id: id);
          log.add(nowMs, LogCategory.dispatch, 'MEDICAL_CARD_SHARED', 'sealed to the accepting responder');
        } on Object {
          _cardsSent.remove(key);
          continue;
        }
        await store.putMeta('cards_sent', jsonEncode(_cardsSent.toList()));
      }
    }
  }

  // =====================================================================
  // User actions
  // =====================================================================

  /// Creates and persists an SOS, then broadcasts it. Text, precise location
  /// and battery are sealed to known verified responders; if none are known the
  /// requester chooses between sharing openly or sending only coarse info.
  Future<String> submitSos({required String text, LocationFix? location, required bool shareOpenlyIfNoKeys}) async {
    final trimmed = text.trim();
    final clipped = trimmed.length > Limits.maxSosTextChars ? trimmed.substring(0, Limits.maxSosTextChars) : trimmed;
    final triage = _triage.analyze(clipped);
    final inner = <String, Object?>{
      'text': clipped,
      if (location != null) 'loc': location.toJson(),
      if (_realBattery != null) 'bat': _realBattery,
      if (_displayName.isNotEmpty) 'name': _displayName,
    };
    final recipients = _sealRecipients(location?.point ?? _selfLocation?.point);
    final id = newMessageId();
    Map<String, Object?> body;
    if (recipients.isNotEmpty) {
      body = {
        'needs': triage.needs.map((n) => n.name).toList(),
        'sealed': await SealedBox.seal(utf8.encode(jsonEncode(inner)), recipients, aad: utf8.encode(id)),
      };
    } else if (shareOpenlyIfNoKeys) {
      body = {'needs': triage.needs.map((n) => n.name).toList(), 'open': inner};
    } else {
      body = {'needs': triage.needs.map((n) => n.name).toList(), 'withheld': true};
    }
    final where = location ?? _selfLocation;
    final gh = where == null ? null : geohash(where.point);
    // The requester keeps their own full report locally even when it is sealed for others.
    await store.putMeta('own_sos:$id', jsonEncode(inner));
    final env = await _publish(MsgType.sos, body, gh: gh, urg: triage.urgency.label, id: id);
    log.add(nowMs, LogCategory.dispatch, 'SOS_CREATED',
        '${triage.urgency.label} · ${recipients.isNotEmpty ? 'sealed to ${recipients.length}' : (shareOpenlyIfNoKeys ? 'shared openly' : 'details withheld')}');
    return env.id;
  }

  /// Up to 8 verified responders' encryption keys, nearest first.
  List<String> _sealRecipients(GeoPoint? near) {
    final verified = _beacons.values
        .where((b) => b.role == NodeRole.responder && _trust.credentialStatus(b, this) == CredentialStatus.verified)
        .toList();
    if (near != null) {
      verified.sort((a, b) {
        final da = a.location?.point.distanceTo(near) ?? double.infinity;
        final db = b.location?.point.distanceTo(near) ?? double.infinity;
        return da.compareTo(db);
      });
    }
    return verified.take(SealedBox.maxRecipients).map((b) => b.encKey).toList();
  }

  Future<void> cancelSos(String sosId) => _publishEvent(sosId, SosEventKind.cancelled);

  Future<void> respond(String sosId, SosEventKind kind, {String? note}) async {
    await _publishEvent(sosId, kind, note: note);
    if (kind == SosEventKind.accepted) _lastHeartbeat[sosId] = nowMs;
    if (kind == SosEventKind.declined) _lapsed.putIfAbsent(sosId, () => {}).add(selfId);
    log.add(nowMs, LogCategory.dispatch, 'RESPONSE_${kind.name.toUpperCase()}');
    _lastBeaconMs = -1 << 40;
  }

  Future<void> reportHazard({
    required HazardKind kind,
    required GeoPoint center,
    double radiusM = 150,
    int severity = 2,
  }) async {
    await _publish(MsgType.hazard, {...center.toJson(), 'kind': kind.name, 'r': radiusM.round(), 'sev': severity.clamp(1, 3)});
    log.add(nowMs, LogCategory.dispatch, 'HAZARD_REPORTED', kind.label);
  }

  // ---- Trust operations ----

  Future<void> enableAuthority(String name) async {
    _authorityName = name.trim().isEmpty ? 'DEMO AUTHORITY' : name.trim();
    await store.putMeta('authority', _authorityName!);
    _lastBeaconMs = -1 << 40;
    log.add(nowMs, LogCategory.trust, 'AUTHORITY_MODE_ON', 'demo authority');
    _changed();
  }

  Future<void> disableAuthority() async {
    _authorityName = null;
    await store.deleteMeta('authority');
    _changed();
  }

  /// Issues a credential to [subject]. The operator must have compared the
  /// subject's fingerprint in person first (enforced in the UI).
  Future<Credential> issueCredential(String subject, Set<Capability> roles, {Duration validity = const Duration(days: 30)}) async {
    final now = nowMs;
    final draft = Credential(
      cid: newMessageId(),
      subject: subject,
      roles: roles,
      issuedAtMs: now,
      expiresAtMs: now + validity.inMilliseconds,
      issuer: selfId,
      issuerName: _authorityName ?? 'DEMO AUTHORITY',
      sig: '',
    );
    final sig = await signatures.sign(canonicalBytes(draft.signedBody()), identity);
    final cred = Credential(
      cid: draft.cid,
      subject: subject,
      roles: roles,
      issuedAtMs: draft.issuedAtMs,
      expiresAtMs: draft.expiresAtMs,
      issuer: selfId,
      issuerName: draft.issuerName,
      sig: sig,
    );
    await _publish(MsgType.credential, {'cred': cred.toJson()});
    final issued = (jsonDecode(store.getMeta('issued') ?? '[]') as List).cast<Object?>()..add(cred.toJson());
    await store.putMeta('issued', jsonEncode(issued));
    log.add(now, LogCategory.trust, 'CREDENTIAL_ISSUED', roles.map((r) => r.name).join(','));
    return cred;
  }

  List<Credential> get issuedCredentials => [
        for (final j in (jsonDecode(store.getMeta('issued') ?? '[]') as List)) ?Credential.fromJson(j),
      ];

  Future<void> revokeCredential(String cid) async {
    await _publish(MsgType.revocation, {'cid': cid});
    log.add(nowMs, LogCategory.trust, 'CREDENTIAL_REVOKED');
  }

  Future<void> pinAnchor(String key) async {
    _pinnedAnchors.add(key);
    await store.putMeta('pinned_anchors', jsonEncode(_pinnedAnchors.toList()));
    log.add(nowMs, LogCategory.trust, 'ANCHOR_PINNED', PublicIdentity.fingerprintOf(key));
    _invalidate();
    _changed();
  }

  Future<void> unpinAnchor(String key) async {
    _pinnedAnchors.remove(key);
    await store.putMeta('pinned_anchors', jsonEncode(_pinnedAnchors.toList()));
    _invalidate();
    _changed();
  }

  Future<void> vouch(String subject) async {
    if (subject == selfId) return;
    await _publish(MsgType.vouch, {'sub': subject});
    log.add(nowMs, LogCategory.trust, 'VOUCH_SENT');
  }

  /// Deletes local report data (retention policy / user request). Identity is kept.
  Future<void> wipeLocalData() async {
    await store.wipe();
    _live.clear();
    _meta.clear();
    _sos.clear();
    _events.clear();
    _hazards.clear();
    _vouches.clear();
    _revoked.clear();
    _sentTo.clear();
    _ackedBy.clear();
    _beacons.clear();
    _beaconEnvelopeByOrigin.clear();
    _penalties.clear();
    _penaltyUntil.clear();
    _firstSeen.clear();
    _lapsed.clear();
    _assignmentSeenAt.clear();
    _seen.clear();
    _role = null;
    log.add(nowMs, LogCategory.storage, 'LOCAL_DATA_WIPED');
    _invalidate();
    _changed();
  }

  // =====================================================================
  // Persistence: replay and pruning
  // =====================================================================

  Future<void> _replay() async {
    final now = nowMs;
    final stored = store.envelopes().toList()..sort((a, b) => a.$2.receivedAtMs.compareTo(b.$2.receivedAtMs));
    var restored = 0;
    for (final (id, s) in stored) {
      Object? json;
      try {
        json = jsonDecode(s.json);
      } on FormatException {
        await store.deleteEnvelope(id);
        continue;
      }
      final decoded = decodeJson(json, nowMs: now);
      final env = decoded.envelope;
      if (env == null) {
        await store.deleteEnvelope(id); // expired or corrupted
        continue;
      }
      _seen.add(env.id, env.exp);
      _firstSeen.putIfAbsent(env.origin, () => s.receivedAtMs);
      await _apply(env, receivedAt: s.receivedAtMs, via: s.via, fromNetwork: false);
      restored++;
    }
    log.add(now, LogCategory.storage, 'STATE_RESTORED', '$restored records');
    _invalidate();
  }

  void _prune(int now) {
    _seen.prune(now);
    final expired = [for (final e in _live.entries) if (e.value.isExpired(now)) e.key];
    for (final id in expired) {
      final env = _live.remove(id)!;
      _meta.remove(id);
      unawaited(store.deleteEnvelope(id));
      switch (env.type) {
        case MsgType.beacon:
          if (_beaconEnvelopeByOrigin[env.origin] == id) {
            _beaconEnvelopeByOrigin.remove(env.origin);
            _beacons.remove(env.origin);
          }
        case MsgType.hazard:
          _hazards.remove(id);
        case MsgType.sos:
          _sos.remove(id);
          _events.remove(id);
        default:
          break;
      }
    }
    if (expired.isNotEmpty) _invalidate();
  }

  // =====================================================================
  // Derived views
  // =====================================================================

  void _invalidate() => _cacheVersion = -1;

  void _refreshViews() {
    if (_cacheVersion == _version && _cacheVersion != -1) return;
    final now = nowMs;
    _states = {
      for (final s in _sos.values)
        s.id: config.reconciler.fold(s, eventsFor(s.id), now, expired: now - s.receivedAtMs > Limits.sosLifetime.inMilliseconds),
    };
    final open = [
      for (final s in _sos.values)
        if (_states[s.id]!.isOpen) s,
    ];
    final excluded = <String, Set<String>>{
      for (final s in open) s.id: {..._states[s.id]!.declinedBy, ..._states[s.id]!.orphaned, ...?_lapsed[s.id]},
    };
    // An encrypted SOS this phone cannot open was not addressed to it: never
    // offer it here (the requester sealed it for other, verified responders).
    for (final s in open) {
      if (s.sealed && !s.readable) excluded[s.id]!.add(selfId);
    }
    final busy = {for (final st in _states.values) if (st.isActive && st.primary != null) st.primary!};
    _plan = _matcher.plan(openSos: open, view: this, excluded: excluded, busyResponders: busy);
    // Offer windows cycle: once every candidate has let the window pass, start
    // a fresh round instead of leaving the SOS unmatched forever. Explicit
    // declines stay excluded.
    final exhausted = [
      for (final s in open)
        if (_plan.unmatched[s.id] == 'NO_ELIGIBLE_RESPONDER' && (_lapsed[s.id]?.isNotEmpty ?? false)) s.id,
    ];
    if (exhausted.isNotEmpty) {
      for (final id in exhausted) {
        final lapsed = _lapsed.remove(id) ?? const <String>{};
        excluded[id]!.removeAll(lapsed.difference(_states[id]!.declinedBy));
        _assignmentSeenAt.removeWhere((key, _) => key.startsWith('$id|'));
      }
      log.add(now, LogCategory.dispatch, 'OFFER_ROUND_RESTARTED', '${exhausted.length} request(s)');
      _plan = _matcher.plan(openSos: open, view: this, excluded: excluded, busyResponders: busy);
    }
    _zones = _matcher.chain.hazards.zones(this);
    _cacheVersion = _version;
  }

  Map<String, SosState> get states {
    _refreshViews();
    return _states;
  }

  MatchPlan get plan {
    _refreshViews();
    return _plan;
  }

  List<HazardZone> get hazardZones {
    _refreshViews();
    return _zones;
  }

  TrustAssessment trustOf(String identity) => _trust.assess(identity, this);

  /// Median offset of direct neighbours' clocks vs ours, or null with too few samples.
  Duration? get clockOffset {
    if (_clockOffsets.length < 3) return null;
    final sorted = [..._clockOffsets]..sort();
    return Duration(milliseconds: sorted[sorted.length ~/ 2]);
  }

  /// True when nearby phones disagree with this phone's clock by more than a few
  /// minutes: its messages may be rejected as expired or "from the future".
  bool get clockWarning {
    final off = clockOffset;
    return off != null && off.abs() > Limits.clockWarningSkew;
  }

  ReconciliationReport get reconciliationReport => config.reconciler.report(states.values, nowMs);

  DeliveryStatus deliveryOf(String messageId) {
    final sent = _sentTo[messageId]?.length ?? 0;
    final acked = _ackedBy[messageId]?.length ?? 0;
    if (acked > 0) return DeliveryStatus(DeliveryStage.acknowledged, sent, acked);
    if (sent > 0) return DeliveryStatus(DeliveryStage.sentToPeers, sent, acked);
    if (transport.connectedPeers.isEmpty) return DeliveryStatus(DeliveryStage.waitingForPeer, sent, acked);
    return DeliveryStatus(DeliveryStage.savedLocally, sent, acked);
  }

  /// Most critical first; equally critical requests by who has waited longest.
  static int bySeverity(SosRecord a, SosRecord b) {
    final w = b.urgency.weight.compareTo(a.urgency.weight);
    return w != 0 ? w : a.claimedAtMs.compareTo(b.claimedAtMs);
  }

  /// Who a responder is, as far as this phone can tell: declared skills plus
  /// any verified credential.
  ({String name, Set<Capability> caps, bool verified, String? verifiedBy, LocationFix? location})? responderInfo(String id) {
    final b = _beacons[id];
    if (b == null) return null;
    final verified = _trust.credentialStatus(b, this) == CredentialStatus.verified;
    return (
      name: b.name,
      caps: {...b.declaredCaps, if (verified) ...b.credential!.roles},
      verified: verified,
      verifiedBy: verified ? b.credential!.issuerName : null,
      location: b.location,
    );
  }

  /// Close enough to count as "at the door", widened by GPS error but never
  /// beyond [arrivalMaxM] so a poor fix can't fake an arrival from afar.
  static const double arrivalBaseM = 30;
  static const double arrivalMaxM = 100;
  static const Duration arrivalFixMaxAge = Duration(minutes: 2);

  /// Marks this responder ON SCENE for every request they accepted once their
  /// own fresh GPS fix is within the arrival radius of the requester's
  /// location. The event reaches the requester over the mesh like any other.
  /// Returns the SOS ids that were marked.
  Future<List<String>> autoMarkArrivals() async {
    final me = _selfLocation;
    if (me == null || nowMs - me.fixedAtMs > arrivalFixMaxAge.inMilliseconds) return const [];
    final arrived = <String>[];
    for (final e in myEngagements) {
      if (e.standDown || !e.state.isActive) continue;
      if (e.myProgress < SosEventKind.accepted.progress || e.myProgress >= SosEventKind.onScene.progress) continue;
      final target = e.sos.location;
      if (target == null) continue;
      final radius = (arrivalBaseM + me.accuracyM + target.accuracyM).clamp(arrivalBaseM, arrivalMaxM);
      if (me.point.distanceTo(target.point) > radius) continue;
      await respond(e.sos.id, SosEventKind.onScene, note: 'arrived (auto, GPS)');
      arrived.add(e.sos.id);
    }
    return arrived;
  }

  List<MySosView> get mySos {
    final list = [
      for (final s in _sos.values)
        if (s.origin == selfId) MySosView(sos: s, state: states[s.id]!, delivery: deliveryOf(s.id)),
    ]..sort((a, b) => b.sos.claimedAtMs.compareTo(a.sos.claimedAtMs));
    return list;
  }

  List<OfferView> get myOffers {
    if (_role != NodeRole.responder) return const [];
    final now = nowMs;
    final mine = plan.assignments.values.where((a) => a.primary == selfId).toList()
      ..sort((a, b) => bySeverity(a.sos, b.sos));
    return [
      for (final a in mine)
          OfferView(
            assignment: a,
            justification: _justifier.build(
              a.sos,
              a.primaryResult,
              responderPoint: _selfLocation?.point,
              comparableResponders: a.comparableResponders,
              capabilityPhrase: _capabilityPhrase(a.sos),
            ),
            windowRemaining: Duration(
              milliseconds: (config.offerWindow.inMilliseconds - (now - (_assignmentSeenAt['${a.sos.id}|$selfId'] ?? now)))
                  .clamp(0, config.offerWindow.inMilliseconds),
            ),
          ),
    ];
  }

  String _capabilityPhrase(SosRecord sos) {
    if (sos.needs.contains(Need.medical)) return 'medical-capable';
    if (sos.needs.contains(Need.waterRescue)) return 'water-rescue-capable';
    if (sos.needs.contains(Need.fire)) return 'fire-capable';
    return 'suitable';
  }

  /// SOS this node is engaged with as a responder (including stand-down notices).
  List<EngagementView> get myEngagements => [
        for (final st in states.values.toList()
          ..sort((a, b) {
            final sa = _sos[a.sosId], sb = _sos[b.sosId];
            return sa == null || sb == null ? 0 : bySeverity(sa, sb);
          }))
          if ((st.tracks[selfId]?.progress ?? 0) > 0 || st.orphaned.contains(selfId))
            if (_sos[st.sosId] != null)
              EngagementView(
                sos: _sos[st.sosId]!,
                state: st,
                myProgress: st.tracks[selfId]?.progress ?? 0,
                standDown: st.standDown.contains(selfId),
                isPrimary: st.primary == selfId,
              ),
      ];

  List<OpenRequestView> get openRequests {
    final p = plan;
    final out = <OpenRequestView>[];
    for (final s in _sos.values) {
      final st = states[s.id]!;
      if (!st.isOpen || s.origin == selfId) continue;
      final assignment = p.assignments[s.id];
      out.add(OpenRequestView(
        sos: s,
        state: st,
        assignedTo: assignment?.primary,
        unmatchedReason: p.unmatched[s.id],
        myResult: p.results[(s.id, selfId)],
      ));
    }
    out.sort((a, b) => bySeverity(a.sos, b.sos));
    return out;
  }

  List<PeerView> get peers => [
        for (final endpoint in transport.connectedPeers)
          PeerView(
            endpoint: endpoint,
            identity: _endpointIdentity[endpoint],
            beacon: _endpointIdentity[endpoint] == null ? null : _beacons[_endpointIdentity[endpoint]!],
            trust: _endpointIdentity[endpoint] == null ? null : trustOf(_endpointIdentity[endpoint]!),
            directIdentities: _directIdentities[endpoint]?.length ?? 0,
          ),
      ];

  /// Authorities seen nearby that this node has not pinned yet.
  List<BeaconRecord> get unpinnedAuthorities =>
      [for (final b in _beacons.values) if (b.authorityName != null && !anchors.contains(b.origin)) b];

  DiagnosticsCounts get counts => DiagnosticsCounts(
        liveMessages: _live.length,
        sosKnown: _sos.length,
        beaconsKnown: _beacons.length,
        hazardsKnown: _hazards.length,
        outboxPending: [
          for (final s in _sos.values)
            if (s.origin == selfId && (_sentTo[s.id]?.isEmpty ?? true)) s.id,
        ].length,
        seenCacheSize: _seen.length,
        quarantinedLinks: _linkGuard.quarantinedKeys(nowMs).length,
        penalisedIdentities: _penalties.length,
        connectedPeers: transport.connectedPeers.length,
      );
}
