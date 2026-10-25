import 'dart:async';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import 'transport.dart';

/// Real radio over Google Nearby Connections (package nearby_connections 4.3.0,
/// API verified against its source). P2P_CLUSTER gives M-to-N links over
/// Bluetooth/BLE/Wi-Fi with no internet.
///
/// The plugin stores ONE set of callbacks globally, so every connection shares
/// the same handlers here. Simultaneous dialling is avoided by a name
/// tie-break: only the lexicographically smaller name requests a connection.
class NearbyTransport implements MeshTransport {
  NearbyTransport({this.serviceId = 'com.darubaaz.resq.mesh', this.maxPeers = 6});

  final String serviceId;
  final int maxPeers;

  final Nearby _nearby = Nearby();
  final StreamController<TransportEvent> _events = StreamController.broadcast();
  final Map<String, String> _connected = {};
  final Map<String, String> _pendingNames = {};
  final Set<String> _requested = {};
  String _me = '';
  bool _running = false;
  bool _discovering = false;
  bool _lowPower = false;
  Timer? _rediscover;

  @override
  bool get isSimulated => false;

  @override
  String get label => 'NEARBY CONNECTIONS (BLE / WI-FI)';

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  Set<String> get connectedPeers => _connected.keys.toSet();

  void _emit(TransportEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _onInitiated(String id, ConnectionInfo info) {
    _pendingNames[id] = info.endpointName;
    if (_connected.length >= maxPeers) {
      _nearby.rejectConnection(id);
      return;
    }
    _nearby.acceptConnection(id, onPayLoadRecieved: (endpointId, payload) {
      final bytes = payload.bytes;
      if (payload.type == PayloadType.BYTES && bytes != null) {
        _emit(FrameReceived(endpointId, bytes));
      }
    });
  }

  void _onResult(String id, Status status) {
    _requested.remove(id);
    if (status == Status.CONNECTED) {
      _connected[id] = _pendingNames[id] ?? id;
      _emit(PeerConnected(id, _connected[id]!));
      _maybePauseDiscovery();
    }
  }

  void _onDisconnected(String id) {
    _requested.remove(id);
    if (_connected.remove(id) != null) _emit(PeerDisconnected(id));
    unawaited(_ensureDiscovery());
  }

  @override
  Future<void> start(String localName) async {
    if (_running) return;
    _me = localName;
    _running = true;
    try {
      final adv = await _nearby.startAdvertising(
        _me,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onInitiated,
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );
      _emit(TransportStatus(adv, adv ? 'advertising' : 'advertising failed — check Bluetooth and permissions'));
      if (!adv) {
        _running = false;
        return;
      }
      await _ensureDiscovery();
      _rediscover = Timer.periodic(const Duration(minutes: 2), (_) => unawaited(_ensureDiscovery(force: true)));
    } on Object catch (e) {
      _emit(TransportStatus(false, 'radio start failed: ${e.runtimeType}'));
    }
  }

  Future<void> _ensureDiscovery({bool force = false}) async {
    if (!_running || _discovering) return;
    if (!force && (_lowPower ? _connected.isNotEmpty : _connected.length >= wellConnectedPeers)) return;
    try {
      _discovering = await _nearby.startDiscovery(
        _me,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, _) {
          if (_connected.containsKey(id) || _requested.contains(id) || _connected.length >= maxPeers) return;
          if (_me.compareTo(name) >= 0) return; // the other side dials
          _requested.add(id);
          _nearby
              .requestConnection(
                _me,
                id,
                onConnectionInitiated: _onInitiated,
                onConnectionResult: _onResult,
                onDisconnected: _onDisconnected,
              )
              .catchError((Object _) {
            _requested.remove(id);
            return false;
          });
        },
        onEndpointLost: (_) {},
        serviceId: serviceId,
      );
      // Forced re-scan window: pause again after 20 s if still well connected.
      Timer(const Duration(seconds: 20), _maybePauseDiscovery);
    } on Object catch (e) {
      _discovering = false;
      _emit(TransportStatus(true, 'discovery failed: ${e.runtimeType}'));
    }
  }

  /// Discovery degrades existing Nearby links. Pause it once well connected
  /// (or connected at all in low power); the 2-minute timer re-scans briefly.
  static const int wellConnectedPeers = 3;

  void _maybePauseDiscovery() {
    final enough = _lowPower ? _connected.isNotEmpty : _connected.length >= wellConnectedPeers;
    if (_discovering && enough) {
      _discovering = false;
      unawaited(_nearby.stopDiscovery());
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _rediscover?.cancel();
    _discovering = false;
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } on Object {
      // Radio already down.
    }
    for (final id in _connected.keys.toList()) {
      _emit(PeerDisconnected(id));
    }
    _connected.clear();
    _emit(const TransportStatus(false, 'stopped'));
  }

  @override
  Future<bool> send(String endpointId, Uint8List frame) async {
    if (!_connected.containsKey(endpointId)) return false;
    try {
      await _nearby.sendBytesPayload(endpointId, frame);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> setLowPower(bool lowPower) async {
    _lowPower = lowPower;
    if (lowPower) {
      _maybePauseDiscovery();
    } else {
      await _ensureDiscovery();
    }
  }
}
