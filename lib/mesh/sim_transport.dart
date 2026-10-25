import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'transport.dart';

/// In-memory radio for the simulator. Links are set by the simulator from
/// node distance and partitions; delivery is queued and pumped explicitly so a
/// whole simulated city runs deterministically on one clock.
class SimRadio {
  final Map<String, SimTransport> _nodes = {};
  final Set<(String, String)> _links = {};
  final Queue<(String from, String to, Uint8List bytes)> _queue = Queue();

  int framesDelivered = 0;
  int framesDropped = 0;

  SimTransport attach(String nodeKey) => _nodes.putIfAbsent(nodeKey, () => SimTransport._(this, nodeKey));

  void detach(String nodeKey) {
    for (final other in _nodes.keys.toList()) {
      setLink(nodeKey, other, false);
    }
    _nodes.remove(nodeKey);
  }

  static (String, String) _key(String a, String b) => a.compareTo(b) < 0 ? (a, b) : (b, a);

  bool linked(String a, String b) => _links.contains(_key(a, b));

  void setLink(String a, String b, bool up) {
    if (a == b) return;
    final k = _key(a, b);
    final na = _nodes[a], nb = _nodes[b];
    if (up && !_links.contains(k) && na != null && nb != null && na._running && nb._running) {
      _links.add(k);
      na._emit(PeerConnected(b, b));
      nb._emit(PeerConnected(a, a));
    } else if (!up && _links.remove(k)) {
      na?._emit(PeerDisconnected(b));
      nb?._emit(PeerDisconnected(a));
    }
  }

  Iterable<(String, String)> get links => _links;

  /// Delivers up to [maxFrames] queued frames. Returns how many were delivered.
  int pump({int maxFrames = 2000}) {
    var n = 0;
    while (_queue.isNotEmpty && n < maxFrames) {
      final (from, to, bytes) = _queue.removeFirst();
      if (!linked(from, to)) {
        framesDropped++;
        continue;
      }
      _nodes[to]?._emit(FrameReceived(from, bytes));
      framesDelivered++;
      n++;
    }
    return n;
  }

  int get queued => _queue.length;
}

class SimTransport implements MeshTransport {
  SimTransport._(this._radio, this.nodeKey);

  final SimRadio _radio;
  final String nodeKey;
  final StreamController<TransportEvent> _events = StreamController.broadcast(sync: true);
  bool _running = false;

  @override
  bool get isSimulated => true;

  @override
  String get label => 'SIMULATED RADIO';

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  Set<String> get connectedPeers =>
      {for (final (a, b) in _radio.links) if (a == nodeKey) b else if (b == nodeKey) a};

  void _emit(TransportEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  @override
  Future<void> start(String localName) async {
    _running = true;
    _emit(const TransportStatus(true, 'simulated radio up'));
  }

  @override
  Future<void> stop() async {
    _running = false;
    for (final peer in connectedPeers.toList()) {
      _radio.setLink(nodeKey, peer, false);
    }
  }

  @override
  Future<bool> send(String endpointId, Uint8List frame) async {
    if (!_running || !_radio.linked(nodeKey, endpointId)) return false;
    _radio._queue.add((nodeKey, endpointId, frame));
    return true;
  }

  @override
  Future<void> setLowPower(bool lowPower) async {}
}
