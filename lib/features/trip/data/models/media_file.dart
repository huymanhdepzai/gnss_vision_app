import 'package:hive/hive.dart';

enum MediaType { image, video }

class MediaFile {
  String id;
  String tripId;
  String filePath;
  String? remoteId;
  MediaType type;
  double? latitude;
  double? longitude;
  DateTime capturedAt;
  String? thumbnailPath;
  bool isSynced;

  MediaFile({
    required this.id,
    required this.tripId,
    required this.filePath,
    this.remoteId,
    required this.type,
    this.latitude,
    this.longitude,
    required this.capturedAt,
    this.thumbnailPath,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'filePath': filePath,
      'remoteId': remoteId,
      'type': type.index,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
      'isSynced': isSynced,
    };
  }

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      id: json['id'],
      tripId: json['tripId'],
      filePath: json['filePath'],
      remoteId: json['remoteId'],
      type: MediaType.values[json['type'] ?? 0],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      capturedAt: DateTime.parse(json['capturedAt']),
      thumbnailPath: json['thumbnailPath'],
      isSynced: json['isSynced'] ?? false,
    );
  }

  static Future<Box<MediaFile>> openBox() async {
    return await Hive.openBox<MediaFile>('media_files');
  }
}
