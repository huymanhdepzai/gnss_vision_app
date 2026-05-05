import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../data/datasources/goong_search_data_source.dart';
import '../../domain/repositories/navigation_repository.dart';
import 'map_home_event.dart';
import 'map_home_state.dart';

class MapHomeBloc extends Bloc<MapHomeEvent, MapHomeState> {
  final GoongSearchDataSource _searchDataSource;
  final NavigationRepository _navigationRepository;

  Timer? _debounce;
  StreamSubscription<geo.Position>? _positionStream;

  MapHomeBloc({
    required GoongSearchDataSource searchDataSource,
    required NavigationRepository navigationRepository,
  })  : _searchDataSource = searchDataSource,
        _navigationRepository = navigationRepository,
        super(const MapHomeState()) {
    on<MapHomeInitLocation>(_onInitLocation);
    on<MapHomeSearchChanged>(_onSearchChanged);
    on<MapHomePerformSearch>(_onPerformSearch);
    on<MapHomeSelectPlace>(_onSelectPlace);
    on<MapHomeStartNavigation>(_onStartNavigation);
    on<MapHomeFetchRoute>(_onFetchRoute);
    on<MapHomeResetToExplore>(_onResetToExplore);
    on<MapHomeClearSearch>(_onClearSearch);
    on<MapHomeLocationUpdated>(_onLocationUpdated);
  }

  Future<void> _onInitLocation(
    MapHomeInitLocation event,
    Emitter<MapHomeState> emit,
  ) async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    geo.LocationPermission permission =
        await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }
    if (permission == geo.LocationPermission.deniedForever) return;

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      emit(state.copyWith(
        currentLat: position.latitude,
        currentLng: position.longitude,
        isLocationLoaded: true,
      ));
    } catch (e) {
      debugPrint('Error getting initial location: $e');
    }

    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      add(MapHomeLocationUpdated(position.latitude, position.longitude));
    });
  }

  void _onLocationUpdated(
    MapHomeLocationUpdated event,
    Emitter<MapHomeState> emit,
  ) {
    emit(state.copyWith(
      currentLat: event.lat,
      currentLng: event.lng,
      isLocationLoaded: true,
    ));
  }

  Future<void> _onSearchChanged(
    MapHomeSearchChanged event,
    Emitter<MapHomeState> emit,
  ) async {
    _debounce?.cancel();

    final query = event.query;

    if (query.isEmpty) {
      emit(state.copyWith(searchResults: [], searchQuery: ''));
      return;
    }

    emit(state.copyWith(searchQuery: query));
    _debounce = Timer(const Duration(milliseconds: 500), () {
      add(MapHomePerformSearch(query));
    });
  }

  Future<void> _onPerformSearch(
    MapHomePerformSearch event,
    Emitter<MapHomeState> emit,
  ) async {
    emit(state.copyWith(isSearching: true));

    try {
      final results = await _searchDataSource.autocomplete(
        event.query,
        lat: state.currentLat,
        lng: state.currentLng,
        radius: 50,
      );
      emit(state.copyWith(searchResults: results, isSearching: false));
    } catch (e) {
      debugPrint('Search error: $e');
      emit(state.copyWith(searchResults: [], isSearching: false));
    }
  }

  Future<void> _onSelectPlace(
    MapHomeSelectPlace event,
    Emitter<MapHomeState> emit,
  ) async {
    emit(state.copyWith(
      isSearching: true,
      searchResults: [],
      searchQuery: event.description,
    ));

    try {
      final detail =
          await _searchDataSource.getPlaceDetail(event.placeId);
      emit(state.copyWith(
        destinationLat: detail.latitude,
        destinationLng: detail.longitude,
        destinationName:
            detail.name.isNotEmpty ? detail.name : event.description,
        destinationAddress: detail.address,
        viewState: MapViewState.placeDetail,
        isSearching: false,
      ));
    } catch (e) {
      debugPrint('Place detail error: $e');
      emit(state.copyWith(
        viewState: MapViewState.explore,
        isSearching: false,
      ));
    }
  }

  Future<void> _onStartNavigation(
    MapHomeStartNavigation event,
    Emitter<MapHomeState> emit,
  ) async {
    emit(state.copyWith(viewState: MapViewState.navigating));
  }

  Future<void> _onFetchRoute(
    MapHomeFetchRoute event,
    Emitter<MapHomeState> emit,
  ) async {
    if (state.destinationLat == null || state.destinationLng == null) return;

    emit(state.copyWith(isSearching: true));

    final result = await _navigationRepository.getRoute(
      originLat: state.currentLat,
      originLng: state.currentLng,
      destinationLat: state.destinationLat!,
      destinationLng: state.destinationLng!,
    );

    result.fold(
      (failure) {
        debugPrint('Route fetch error: ${failure.message}');
        emit(state.copyWith(isSearching: false));
      },
      (route) {
        final geoJson = _buildRouteGeoJson(route.polyline);
        emit(state.copyWith(
          distance: route.distanceText,
          duration: route.durationText,
          routeGeoJson: geoJson,
          isRouteActive: true,
          isSearching: false,
        ));
      },
    );
  }

  Future<void> _onResetToExplore(
    MapHomeResetToExplore event,
    Emitter<MapHomeState> emit,
  ) async {
    emit(MapHomeState(
      currentLat: state.currentLat,
      currentLng: state.currentLng,
      isLocationLoaded: state.isLocationLoaded,
      viewState: MapViewState.explore,
    ));
  }

  Future<void> _onClearSearch(
    MapHomeClearSearch event,
    Emitter<MapHomeState> emit,
  ) async {
    emit(MapHomeState(
      currentLat: state.currentLat,
      currentLng: state.currentLng,
      isLocationLoaded: state.isLocationLoaded,
      viewState: MapViewState.explore,
    ));
  }

  String _buildRouteGeoJson(List<dynamic> polyline) {
    final coords = polyline.map((point) {
      if (point is List<double>) {
        return [point[0], point[1]];
      }
      return point;
    }).toList();
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          }
        }
      ]
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _positionStream?.cancel();
    return super.close();
  }
}