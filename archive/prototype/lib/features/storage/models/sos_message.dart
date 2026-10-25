class SosMessage {
  final String id;
  final String senderId;
  final String victimName;
  final String emergencyType; // Medical, Trapped, Flood, Fire, Other
  final String description;
  final double? latitude;
  final double? longitude;
  final String severity; // Critical, Urgent, Moderate
  final int timestamp;
  final bool isRelayed;
  final int hopCount;

  const SosMessage({
    required this.id,
    required this.senderId,
    required this.victimName,
    required this.emergencyType,
    required this.description,
    this.latitude,
    this.longitude,
    required this.severity,
    required this.timestamp,
    this.isRelayed = false,
    this.hopCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'victimName': victimName,
      'emergencyType': emergencyType,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity,
      'timestamp': timestamp,
      'isRelayed': isRelayed,
      'hopCount': hopCount,
    };
  }

  factory SosMessage.fromMap(Map<String, dynamic> map) {
    return SosMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      victimName: map['victimName'] ?? 'Anonymous',
      emergencyType: map['emergencyType'] ?? 'General Emergency',
      description: map['description'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      severity: map['severity'] ?? 'Urgent',
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      isRelayed: map['isRelayed'] ?? false,
      hopCount: map['hopCount'] ?? 0,
    );
  }
}
