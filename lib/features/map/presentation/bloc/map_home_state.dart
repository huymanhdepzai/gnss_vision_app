import 'package:equatable/equatable.dart';
import '../../data/datasources/goong_search_data_source.dart';
import '../../domain/entities/navigation_route.dart';

enum MapViewState { explore, placeDetail, navigating }

class MapHomeState extends Equatable {
  final MapViewState viewState;
  final double currentLat;
  final double currentLng;
  final double locationAccuracy;
  final bool isLocationLoaded;
  final String destinationName;
  final String destinationAddress;
  final String? destinationPlaceId;
  final double? destinationLat;
  final double? destinationLng;
  final String distance;
  final String duration;
  final String? routeGeoJson;
  final String? staticMapUrl;
  final bool isRouteActive;
  final List<SearchResult> searchResults;
  final bool isSearching;
  final String searchQuery;
  final NavigationRoute? route;
  final String? mapStyleUrl;
  final String vehicle;
  final List<NavigationRoute> availableRoutes;
  final int selectedRouteIndex;
  final PlaceDetail? placeDetail;

  const MapHomeState({
    this.viewState = MapViewState.explore,
    this.currentLat = 21.028511,
    this.currentLng = 105.804817,
    this.locationAccuracy = 0.0,
    this.isLocationLoaded = false,
    this.destinationName = '',
    this.destinationAddress = '',
    this.destinationPlaceId,
    this.destinationLat,
    this.destinationLng,
    this.distance = 'Đang tính...',
    this.duration = '-- phút',
    this.routeGeoJson,
    this.staticMapUrl,
    this.isRouteActive = false,
    this.searchResults = const [],
    this.isSearching = false,
    this.searchQuery = '',
    this.route,
    this.mapStyleUrl,
    this.vehicle = 'car',
    this.availableRoutes = const [],
    this.selectedRouteIndex = 0,
    this.placeDetail,
  });

  MapHomeState copyWith({
    MapViewState? viewState,
    double? currentLat,
    double? currentLng,
    double? locationAccuracy,
    bool? isLocationLoaded,
    String? destinationName,
    String? destinationAddress,
    String? destinationPlaceId,
    double? destinationLat,
    double? destinationLng,
    String? distance,
    String? duration,
    String? routeGeoJson,
    String? staticMapUrl,
    bool? isRouteActive,
    List<SearchResult>? searchResults,
    bool? isSearching,
    String? searchQuery,
    NavigationRoute? route,
    String? mapStyleUrl,
    String? vehicle,
    List<NavigationRoute>? availableRoutes,
    int? selectedRouteIndex,
    PlaceDetail? placeDetail,
  }) {
    return MapHomeState(
      viewState: viewState ?? this.viewState,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      isLocationLoaded: isLocationLoaded ?? this.isLocationLoaded,
      destinationName: destinationName ?? this.destinationName,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationPlaceId: destinationPlaceId ?? this.destinationPlaceId,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      routeGeoJson: routeGeoJson ?? this.routeGeoJson,
      staticMapUrl: staticMapUrl ?? this.staticMapUrl,
      isRouteActive: isRouteActive ?? this.isRouteActive,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      route: route ?? this.route,
      mapStyleUrl: mapStyleUrl ?? this.mapStyleUrl,
      vehicle: vehicle ?? this.vehicle,
      availableRoutes: availableRoutes ?? this.availableRoutes,
      selectedRouteIndex: selectedRouteIndex ?? this.selectedRouteIndex,
      placeDetail: placeDetail ?? this.placeDetail,
    );
  }

  @override
  List<Object?> get props => [
        viewState,
        currentLat,
        currentLng,
        locationAccuracy,
        isLocationLoaded,
        destinationName,
        destinationAddress,
        destinationPlaceId,
        destinationLat,
        destinationLng,
        distance,
        duration,
        routeGeoJson,
        staticMapUrl,
        isRouteActive,
        searchResults,
        isSearching,
        searchQuery,
        route,
        mapStyleUrl,
        vehicle,
        availableRoutes,
        selectedRouteIndex,
        placeDetail,
      ];
}