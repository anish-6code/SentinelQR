import 'package:hive/hive.dart';

part 'scan_record.g.dart';

@HiveType(typeId: 0)
class ScanRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String rawPayload;

  @HiveField(2)
  final String verdict;

  @HiveField(3)
  final int riskScore;

  @HiveField(4)
  final String payloadType;

  @HiveField(5)
  final DateTime scannedAt;

  @HiveField(6)
  final String? finalUrl;

  @HiveField(7)
  final int redirectHops;

  ScanRecord({
    required this.id,
    required this.rawPayload,
    required this.verdict,
    required this.riskScore,
    required this.payloadType,
    required this.scannedAt,
    this.finalUrl,
    this.redirectHops = 0,
  });

  /// Truncated payload for display in list tiles
  String get payloadPreview {
    if (rawPayload.length <= 60) return rawPayload;
    return '${rawPayload.substring(0, 60)}…';
  }
}

@HiveType(typeId: 1)
enum VerdictLevel {
  @HiveField(0)
  safe,

  @HiveField(1)
  suspicious,

  @HiveField(2)
  danger,
}
