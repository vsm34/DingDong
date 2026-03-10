class DdClip {
  final String clipId;
  final DateTime timestamp;
  final int durationSec;
  final int sizeBytes;

  const DdClip({
    required this.clipId,
    required this.timestamp,
    required this.durationSec,
    required this.sizeBytes,
  });

  factory DdClip.fromJson(Map<String, dynamic> json) => DdClip(
        clipId: json['clipId'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
        durationSec: json['durationSec'] as int,
        sizeBytes: json['sizeBytes'] as int,
      );

  Map<String, dynamic> toJson() => {
        'clipId': clipId,
        'ts': timestamp.millisecondsSinceEpoch,
        'durationSec': durationSec,
        'sizeBytes': sizeBytes,
      };

  String get durationLabel {
    if (durationSec < 60) return '${durationSec}s';
    final m = durationSec ~/ 60;
    final s = durationSec % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
