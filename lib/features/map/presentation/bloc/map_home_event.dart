import 'package:equatable/equatable.dart';

abstract class MapHomeEvent extends Equatable {
  const MapHomeEvent();

  @override
  List<Object?> get props => [];
}

class MapHomeInitLocation extends MapHomeEvent {
  const MapHomeInitLocation();
}

class MapHomeSearchChanged extends MapHomeEvent {
  final String query;
  const MapHomeSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class MapHomePerformSearch extends MapHomeEvent {
  final String query;
  const MapHomePerformSearch(this.query);

  @override
  List<Object?> get props => [query];
}

class MapHomeSelectPlace extends MapHomeEvent {
  final String placeId;
  final String description;
  const MapHomeSelectPlace(this.placeId, this.description);

  @override
  List<Object?> get props => [placeId, description];
}

class MapHomeStartNavigation extends MapHomeEvent {
  const MapHomeStartNavigation();
}

class MapHomeFetchRoute extends MapHomeEvent {
  const MapHomeFetchRoute();
}

class MapHomeResetToExplore extends MapHomeEvent {
  const MapHomeResetToExplore();
}

class MapHomeReturnToPlaceDetail extends MapHomeEvent {
  const MapHomeReturnToPlaceDetail();
}

class MapHomeClearSearch extends MapHomeEvent {
  const MapHomeClearSearch();
}

class MapHomeLocationUpdated extends MapHomeEvent {
  final double lat;
  final double lng;
  final double accuracy;
  const MapHomeLocationUpdated(this.lat, this.lng, this.accuracy);

  @override
  List<Object?> get props => [lat, lng, accuracy];
}

class MapHomeThemeChanged extends MapHomeEvent {
  final bool isDarkMode;
  const MapHomeThemeChanged(this.isDarkMode);

  @override
  List<Object?> get props => [isDarkMode];
}

class MapHomeVehicleSelected extends MapHomeEvent {
  final String vehicle;
  const MapHomeVehicleSelected(this.vehicle);

  @override
  List<Object?> get props => [vehicle];
}

class MapHomeRouteSelected extends MapHomeEvent {
  final int index;
  const MapHomeRouteSelected(this.index);

  @override
  List<Object?> get props => [index];
}