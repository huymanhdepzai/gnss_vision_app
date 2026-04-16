import 'package:equatable/equatable.dart';

class Trip extends Equatable {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? videoPath;
  final String? thumbnailPath;
  final double distance;
  final double duration;
  final int mediaCount;
  final bool isSynced;

  const Trip({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.videoPath,
    this.thumbnailPath,
    this.distance = 0,
    this.duration = 0,
    this.mediaCount = 0,
    this.isSynced = false,
  });

  Trip copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? videoPath,
    String? thumbnailPath,
    double? distance,
    double? duration,
    int? mediaCount,
    bool? isSynced,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      videoPath: videoPath ?? this.videoPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      mediaCount: mediaCount ?? this.mediaCount,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    createdAt,
    updatedAt,
    videoPath,
    thumbnailPath,
    distance,
    duration,
    mediaCount,
    isSynced,
  ];
}
