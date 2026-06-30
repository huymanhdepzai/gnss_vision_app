class SavedAddressEntity {
  final String placeId;
  final String description;
  final double lat;
  final double lng;

  SavedAddressEntity({
    required this.placeId,
    required this.description,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'description': description,
    'lat': lat,
    'lng': lng,
  };

  factory SavedAddressEntity.fromJson(Map<String, dynamic> json) {
    return SavedAddressEntity(
      placeId: json['placeId'] as String,
      description: json['description'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}
