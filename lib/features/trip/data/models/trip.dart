import 'media_file.dart';

class Trip {
  String id;
  String title;
  String? description;
  double startLat;
  double startLng;
  double endLat;
  double endLng;
  String? startAddress;
  String? endAddress;
  List<String> mediaFileIds;
  DateTime createdAt;
  DateTime? completedAt;
  double distance;
  String duration;
  bool isActive;

  Trip({
    required this.id,
    required this.title,
    this.description,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.startAddress,
    this.endAddress,
    List<String>? mediaFileIds,
    required this.createdAt,
    this.completedAt,
    this.distance = 0,
    this.duration = '',
    this.isActive = false,
  }) : mediaFileIds = mediaFileIds ?? [];

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

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startLat: (json['startLat'] as num).toDouble(),
      startLng: (json['startLng'] as num).toDouble(),
      endLat: (json['endLat'] as num).toDouble(),
      endLng: (json['endLng'] as num).toDouble(),
      startAddress: json['startAddress'],
      endAddress: json['endAddress'],
      mediaFileIds: json['mediaFileIds'] != null
          ? List<String>.from(json['mediaFileIds'])
          : [],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      duration: json['duration'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }
}
