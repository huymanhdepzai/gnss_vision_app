import 'package:equatable/equatable.dart';

class MediaFile extends Equatable {
  final String id;
  final String tripId;
  final String path;
  final String type; // 'image', 'video', 'audio'
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? thumbnailPath;
  final int? duration; // for video/audio in seconds
  final bool isSynced;

  const MediaFile({
    required this.id,
    required this.tripId,
    required this.path,
    required this.type,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.thumbnailPath,
    this.duration,
    this.isSynced = false,
  });

  MediaFile copyWith({
    String? id,
    String? tripId,
    String? path,
    String? type,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    String? thumbnailPath,
    int? duration,
    bool? isSynced,
  }) {
    return MediaFile(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      path: path ?? this.path,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    path,
    type,
    createdAt,
    latitude,
    longitude,
    thumbnailPath,
    duration,
    isSynced,
  ];
}
