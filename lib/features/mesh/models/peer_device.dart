enum PeerConnectionState {
  discovered,
  connecting,
  connected,
  disconnected,
}

class PeerDevice {
  final String endpointId;
  final String endpointName;
  final PeerConnectionState state;
  final int rssi; // Signal strength
  final int lastSeen;

  const PeerDevice({
    required this.endpointId,
    required this.endpointName,
    required this.state,
    this.rssi = -60,
    required this.lastSeen,
  });

  PeerDevice copyWith({
    String? endpointId,
    String? endpointName,
    PeerConnectionState? state,
    int? rssi,
    int? lastSeen,
  }) {
    return PeerDevice(
      endpointId: endpointId ?? this.endpointId,
      endpointName: endpointName ?? this.endpointName,
      state: state ?? this.state,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
