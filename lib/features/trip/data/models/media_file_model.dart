import 'package:equatable/equatable.dart';

enum MediaType { image, video, audio }

class MediaFileModel extends Equatable {
  final String id;
  final String tripId;
  final String filePath;
  final MediaType type;
  final double? latitude;
  final double? longitude;
  final DateTime capturedAt;
  final String? thumbnailPath;
  final int? duration;
  final bool isSynced;

  const MediaFileModel({
    required this.id,
    required this.tripId,
    required this.filePath,
    required this.type,
    this.latitude,
    this.longitude,
    required this.capturedAt,
    this.thumbnailPath,
    this.duration,
    this.isSynced = false,
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
      'duration': duration,
      'isSynced': isSynced,
    };
  }

  factory MediaFileModel.fromJson(Map<String, dynamic> json) {
    return MediaFileModel(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      filePath: json['filePath'] as String,
      type: MediaType.values[json['type'] as int? ?? 0],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: json['duration'] as int?,
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }

  MediaFileModel copyWith({
    String? id,
    String? tripId,
    String? filePath,
    MediaType? type,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
    String? thumbnailPath,
    int? duration,
    bool? isSynced,
  }) {
    return MediaFileModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capturedAt: capturedAt ?? this.capturedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    filePath,
    type,
    latitude,
    longitude,
    capturedAt,
    thumbnailPath,
    duration,
    isSynced,
  ];
}
