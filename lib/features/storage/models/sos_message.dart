enum SosStatus {
  active,       // Freshly broadcast, no responder yet
  acknowledged, // A responder has seen and acknowledged
  enRoute,      // A responder is actively moving toward the victim
  resolved,     // Emergency resolved or cancelled
}

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
  final SosStatus status;
  final String? acknowledgedBy; // nodeId of the responder who accepted

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
    this.status = SosStatus.active,
    this.acknowledgedBy,
  });

  SosMessage copyWith({
    SosStatus? status,
    String? acknowledgedBy,
    int? hopCount,
    bool? isRelayed,
  }) {
    return SosMessage(
      id: id,
      senderId: senderId,
      victimName: victimName,
      emergencyType: emergencyType,
      description: description,
      latitude: latitude,
      longitude: longitude,
      severity: severity,
      timestamp: timestamp,
      isRelayed: isRelayed ?? this.isRelayed,
      hopCount: hopCount ?? this.hopCount,
      status: status ?? this.status,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
    );
  }

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
      'status': status.name,
      'acknowledgedBy': acknowledgedBy,
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
      status: SosStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SosStatus.active,
      ),
      acknowledgedBy: map['acknowledgedBy'],
    );
  }
}
