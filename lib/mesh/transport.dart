import 'dart:typed_data';

sealed class TransportEvent {
  const TransportEvent();
}

class PeerConnected extends TransportEvent {
  const PeerConnected(this.endpointId, this.name);

  final String endpointId;
  final String name;
}

class PeerDisconnected extends TransportEvent {
  const PeerDisconnected(this.endpointId);

  final String endpointId;
}

class FrameReceived extends TransportEvent {
  const FrameReceived(this.endpointId, this.bytes);

  final String endpointId;
  final Uint8List bytes;
}

class TransportStatus extends TransportEvent {
  const TransportStatus(this.running, this.detail);

  final bool running;
  final String detail;
}

/// Link layer behind which every radio sits (FR-020). It only moves frames to
/// directly connected peers; multi-hop forwarding is RESQ's job (MeshAgent).
abstract interface class MeshTransport {
  /// True for the in-memory simulator; the UI labels such transports SIMULATION.
  bool get isSimulated;
  String get label;

  Stream<TransportEvent> get events;
  Set<String> get connectedPeers;

  Future<void> start(String localName);
  Future<void> stop();

  /// Sends one frame to one connected peer. Returns false on failure.
  Future<bool> send(String endpointId, Uint8List frame);

  /// Reduce radio duty cycle (low battery). Optional.
  Future<void> setLowPower(bool lowPower);
}
