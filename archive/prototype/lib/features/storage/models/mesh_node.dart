class MeshNode {
  final String nodeId;
  final String deviceName;
  final int batteryLevel; // 0-100%
  final double routingCost; // Dynamic cost based on battery & link state
  final int lastSeen;
  final bool isDirectNeighbor;

  const MeshNode({
    required this.nodeId,
    required this.deviceName,
    required this.batteryLevel,
    required this.routingCost,
    required this.lastSeen,
    this.isDirectNeighbor = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'nodeId': nodeId,
      'deviceName': deviceName,
      'batteryLevel': batteryLevel,
      'routingCost': routingCost,
      'lastSeen': lastSeen,
      'isDirectNeighbor': isDirectNeighbor,
    };
  }

  factory MeshNode.fromMap(Map<String, dynamic> map) {
    return MeshNode(
      nodeId: map['nodeId'] ?? '',
      deviceName: map['deviceName'] ?? 'Unknown Node',
      batteryLevel: map['batteryLevel'] ?? 100,
      routingCost: (map['routingCost'] as num?)?.toDouble() ?? 1.0,
      lastSeen: map['lastSeen'] ?? DateTime.now().millisecondsSinceEpoch,
      isDirectNeighbor: map['isDirectNeighbor'] ?? true,
    );
  }
}
