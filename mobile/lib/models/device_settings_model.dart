class DeviceSettings {
  final bool motionEnabled;
  final bool notifyEnabled;
  final int mmwaveThreshold;
  final int clipLengthSec;
  final List<Map<String, double>> privacyZones;

  static const List<int> validClipLengths = [5, 10, 20, 30];

  const DeviceSettings({
    required this.motionEnabled,
    required this.notifyEnabled,
    required this.mmwaveThreshold,
    required this.clipLengthSec,
    this.privacyZones = const [],
  });

  factory DeviceSettings.defaults() => const DeviceSettings(
        motionEnabled: true,
        notifyEnabled: true,
        mmwaveThreshold: 50,
        clipLengthSec: 10,
      );

  factory DeviceSettings.fromJson(Map<String, dynamic> json) => DeviceSettings(
        motionEnabled: json['motionEnabled'] as bool,
        notifyEnabled: json['notifyEnabled'] as bool,
        mmwaveThreshold: json['mmwaveThreshold'] as int,
        clipLengthSec: json['clipLengthSec'] as int,
        privacyZones: (json['privacyZones'] as List<dynamic>?)
                ?.map((z) => Map<String, double>.from(
                    (z as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()))))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'motionEnabled': motionEnabled,
        'notifyEnabled': notifyEnabled,
        'mmwaveThreshold': mmwaveThreshold,
        'clipLengthSec': clipLengthSec,
        'privacyZones': privacyZones,
      };

  DeviceSettings copyWith({
    bool? motionEnabled,
    bool? notifyEnabled,
    int? mmwaveThreshold,
    int? clipLengthSec,
    List<Map<String, double>>? privacyZones,
  }) =>
      DeviceSettings(
        motionEnabled: motionEnabled ?? this.motionEnabled,
        notifyEnabled: notifyEnabled ?? this.notifyEnabled,
        mmwaveThreshold: mmwaveThreshold ?? this.mmwaveThreshold,
        clipLengthSec: clipLengthSec ?? this.clipLengthSec,
        privacyZones: privacyZones ?? this.privacyZones,
      );
}
