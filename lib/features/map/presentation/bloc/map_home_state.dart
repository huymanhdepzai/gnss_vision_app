import 'package:equatable/equatable.dart';
import '../../data/datasources/goong_search_data_source.dart';
import '../../domain/entities/navigation_route.dart';

enum MapViewState { explore, placeDetail, navigating }

class MapHomeState extends Equatable {
  final MapViewState viewState;
  final double currentLat;
  final double currentLng;
  final bool isLocationLoaded;
  final String destinationName;
  final String destinationAddress;
  final double? destinationLat;
  final double? destinationLng;
  final String distance;
  final String duration;
  final String? routeGeoJson;
  final bool isRouteActive;
  final List<SearchResult> searchResults;
  final bool isSearching;
  final String searchQuery;
  final NavigationRoute? route;
  final String? mapStyleUrl;
  final String vehicle;
  final List<NavigationRoute> availableRoutes;
  final int selectedRouteIndex;

  const MapHomeState({
    this.viewState = MapViewState.explore,
    this.currentLat = 21.028511,
    this.currentLng = 105.804817,
    this.isLocationLoaded = false,
    this.destinationName = '',
    this.destinationAddress = '',
    this.destinationLat,
    this.destinationLng,
    this.distance = 'Đang tính...',
    this.duration = '-- phút',
    this.routeGeoJson,
    this.isRouteActive = false,
    this.searchResults = const [],
    this.isSearching = false,
    this.searchQuery = '',
    this.route,
    this.mapStyleUrl,
    this.vehicle = 'car',
    this.availableRoutes = const [],
    this.selectedRouteIndex = 0,
  });

  MapHomeState copyWith({
    MapViewState? viewState,
    double? currentLat,
    double? currentLng,
    bool? isLocationLoaded,
    String? destinationName,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    String? distance,
    String? duration,
    String? routeGeoJson,
    bool? isRouteActive,
    List<SearchResult>? searchResults,
    bool? isSearching,
    String? searchQuery,
    NavigationRoute? route,
    String? mapStyleUrl,
    String? vehicle,
    List<NavigationRoute>? availableRoutes,
    int? selectedRouteIndex,
  }) {
    return MapHomeState(
      viewState: viewState ?? this.viewState,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      isLocationLoaded: isLocationLoaded ?? this.isLocationLoaded,
      destinationName: destinationName ?? this.destinationName,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      routeGeoJson: routeGeoJson ?? this.routeGeoJson,
      isRouteActive: isRouteActive ?? this.isRouteActive,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      route: route ?? this.route,
      mapStyleUrl: mapStyleUrl ?? this.mapStyleUrl,
      vehicle: vehicle ?? this.vehicle,
      availableRoutes: availableRoutes ?? this.availableRoutes,
      selectedRouteIndex: selectedRouteIndex ?? this.selectedRouteIndex,
    );
  }

  @override
  List<Object?> get props => [
        viewState,
        currentLat,
        currentLng,
        isLocationLoaded,
        destinationName,
        destinationAddress,
        destinationLat,
        destinationLng,
        distance,
        duration,
        routeGeoJson,
        isRouteActive,
        searchResults,
        isSearching,
        searchQuery,
        route,
        mapStyleUrl,
        vehicle,
        availableRoutes,
        selectedRouteIndex,
      ];
}