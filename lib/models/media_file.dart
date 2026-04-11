import 'package:hive/hive.dart';

enum MediaType { image, video }

class MediaFile {
  String id;
  String tripId;
  String filePath;
  MediaType type;
  double? latitude;
  double? longitude;
  DateTime capturedAt;
  String? thumbnailPath;

  MediaFile({
    required this.id,
    required this.tripId,
    required this.filePath,
    required this.type,
    this.latitude,
    this.longitude,
    required this.capturedAt,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'filePath': filePath,
      'type': type.index,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
    };
  }

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      id: json['id'],
      tripId: json['tripId'],
      filePath: json['filePath'],
      type: MediaType.values[json['type'] ?? 0],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      capturedAt: DateTime.parse(json['capturedAt']),
      thumbnailPath: json['thumbnailPath'],
    );
  }

  static Future<Box<MediaFile>> openBox() async {
    return await Hive.openBox<MediaFile>('media_files');
  }
}
