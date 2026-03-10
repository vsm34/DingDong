enum EventType { motion, doorbell }

class SensorStats {
  final bool pirTriggered;
  final double? mmwaveDistance;

  const SensorStats({
    required this.pirTriggered,
    this.mmwaveDistance,
  });

  factory SensorStats.fromJson(Map<String, dynamic> json) => SensorStats(
        pirTriggered: json['pirTriggered'] as bool,
        mmwaveDistance: (json['mmwaveDistance'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'pirTriggered': pirTriggered,
        'mmwaveDistance': mmwaveDistance,
      };
}

class DdEvent {
  final String id;
  final String deviceId;
  final DateTime timestamp;
  final EventType type;
  final String? clipId;
  final SensorStats? sensorStats;

  const DdEvent({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    required this.type,
    this.clipId,
    this.sensorStats,
  });

  factory DdEvent.fromJson(Map<String, dynamic> json) => DdEvent(
        id: json['id'] as String,
        deviceId: json['deviceId'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
        type: json['type'] == 'doorbell' ? EventType.doorbell : EventType.motion,
        clipId: json['clipId'] as String?,
        sensorStats: json['sensorStats'] != null
            ? SensorStats.fromJson(json['sensorStats'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'ts': timestamp.millisecondsSinceEpoch,
        'type': type.name,
        'clipId': clipId,
        'sensorStats': sensorStats?.toJson(),
      };

  String get typeLabel => type == EventType.doorbell ? 'Doorbell' : 'Motion';
}
