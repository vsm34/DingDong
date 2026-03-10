class DdDevice {
  final String deviceId;
  final String displayName;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final String? firmwareVersion;
  final bool notifyEnabled;
  final bool motionEnabled;

  const DdDevice({
    required this.deviceId,
    required this.displayName,
    required this.ownerId,
    required this.createdAt,
    this.lastSeen,
    this.firmwareVersion,
    this.notifyEnabled = true,
    this.motionEnabled = true,
  });

  bool get isOnline {
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!).inMinutes < 2;
  }

  String get lastSeenLabel {
    if (lastSeen == null) return 'Never';
    final diff = DateTime.now().difference(lastSeen!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  DdDevice copyWith({
    String? displayName,
    DateTime? lastSeen,
    String? firmwareVersion,
    bool? notifyEnabled,
    bool? motionEnabled,
  }) =>
      DdDevice(
        deviceId: deviceId,
        displayName: displayName ?? this.displayName,
        ownerId: ownerId,
        createdAt: createdAt,
        lastSeen: lastSeen ?? this.lastSeen,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        notifyEnabled: notifyEnabled ?? this.notifyEnabled,
        motionEnabled: motionEnabled ?? this.motionEnabled,
      );
}

class HealthResponse {
  final bool ok;
  final String deviceId;
  final String fwVersion;
  final DateTime time;
  final DateTime? lastEventTs;

  const HealthResponse({
    required this.ok,
    required this.deviceId,
    required this.fwVersion,
    required this.time,
    this.lastEventTs,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) => HealthResponse(
        ok: json['ok'] as bool,
        deviceId: json['deviceId'] as String,
        fwVersion: json['fwVersion'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
        lastEventTs: json['lastEventTs'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['lastEventTs'] as int)
            : null,
      );
}
