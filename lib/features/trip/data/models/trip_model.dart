import 'package:equatable/equatable.dart';

class TripModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final String? startAddress;
  final String? endAddress;
  final List<String> mediaFileIds;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double distance;
  final String duration;
  final bool isActive;

  const TripModel({
    required this.id,
    required this.title,
    this.description,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.startAddress,
    this.endAddress,
    required this.mediaFileIds,
    required this.createdAt,
    this.completedAt,
    this.distance = 0,
    this.duration = '',
    this.isActive = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'mediaFileIds': mediaFileIds,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'distance': distance,
      'duration': duration,
      'isActive': isActive,
    };
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startLat: (json['startLat'] as num).toDouble(),
      startLng: (json['startLng'] as num).toDouble(),
      endLat: (json['endLat'] as num).toDouble(),
      endLng: (json['endLng'] as num).toDouble(),
      startAddress: json['startAddress'] as String?,
      endAddress: json['endAddress'] as String?,
      mediaFileIds: json['mediaFileIds'] != null
          ? List<String>.from(json['mediaFileIds'] as List)
          : [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      duration: json['duration'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  TripModel copyWith({
    String? id,
    String? title,
    String? description,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    String? startAddress,
    String? endAddress,
    List<String>? mediaFileIds,
    DateTime? createdAt,
    DateTime? completedAt,
    double? distance,
    String? duration,
    bool? isActive,
  }) {
    return TripModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      mediaFileIds: mediaFileIds ?? this.mediaFileIds,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    startLat,
    startLng,
    endLat,
    endLng,
    startAddress,
    endAddress,
    mediaFileIds,
    createdAt,
    completedAt,
    distance,
    duration,
    isActive,
  ];
}
