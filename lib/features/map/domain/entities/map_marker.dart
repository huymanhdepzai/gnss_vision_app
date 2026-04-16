import 'package:equatable/equatable.dart';

class MapMarker extends Equatable {
  final String id;
  final String title;
  final String? description;
  final double latitude;
  final double longitude;
  final String type;
  final DateTime createdAt;

  const MapMarker({
    required this.id,
    required this.title,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.createdAt,
  });

  MapMarker copyWith({
    String? id,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? type,
    DateTime? createdAt,
  }) {
    return MapMarker(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    latitude,
    longitude,
    type,
    createdAt,
  ];
}
