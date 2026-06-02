import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    on<MapHomeThemeChanged>(_onThemeChanged);
    on<MapHomeVehicleSelected>(_onVehicleSelected);
    on<MapHomeRouteSelected>(_onRouteSelected);
  }

  void _onRouteSelected(
    MapHomeRouteSelected event,
    Emitter<MapHomeState> emit,
  ) {
    if (event.index < 0 || event.index >= state.availableRoutes.length) return;
    
    final route = state.availableRoutes[event.index];
    final fullPolyline = <List<double>>[
      [state.currentLng, state.currentLat],
      ...route.polyline,
    ];
    final geoJson = _buildRouteGeoJson(fullPolyline);
    
    final staticMapUrl = _navigationRepository.getStaticMapRouteUrl(
      originLat: state.currentLat,
      originLng: state.currentLng,
      destinationLat: state.destinationLat!,
      destinationLng: state.destinationLng!,
      vehicle: state.vehicle,
    );
    
    emit(state.copyWith(
      selectedRouteIndex: event.index,
      route: route,
      distance: route.distanceText,
      duration: route.durationText,
      routeGeoJson: geoJson,
      staticMapUrl: staticMapUrl,
    ));
  }

  void _onVehicleSelected(
    MapHomeVehicleSelected event,
    Emitter<MapHomeState> emit,
  ) {
    emit(state.copyWith(vehicle: event.vehicle));
    if (state.destinationLat != null && state.destinationLng != null) {
      add(const MapHomeFetchRoute());
    }
  }

  void _onThemeChanged(
    MapHomeThemeChanged event,
    Emitter<MapHomeState> emit,
  ) {
    final styleUrl = _buildMapStyleUrl(event.isDarkMode);
    emit(state.copyWith(mapStyleUrl: styleUrl));
  }

  String _buildMapStyleUrl(bool isDark) {
    final mapTilesKey = dotenv.env['GOONG_MAPTILES_KEY'] ?? '';
    final style = isDark ? 'navigation_night' : 'navigation_day';
    return 'https://tiles.goong.io/assets/$style.json?api_key=$mapTilesKey';
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

  Future<void> _onLocationUpdated(
    MapHomeLocationUpdated event,
    Emitter<MapHomeState> emit,
  ) async {
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
    if (event.query.isEmpty) return;
    
    emit(state.copyWith(isSearching: true));

    try {
      final results = await _searchDataSource.autocomplete(
        event.query,
        lat: state.currentLat,
        lng: state.currentLng,
        radius: 10000,
        origin: '${state.currentLat},${state.currentLng}',
      );

      // Kiểm tra nếu query đã thay đổi hoặc đã bị xóa trong lúc đợi API
      if (state.searchQuery != event.query || state.searchQuery.isEmpty) {
        return;
      }

      // Sắp xếp kết quả theo khoảng cách từ gần đến xa
      results.sort((a, b) {
        if (a.distance == null && b.distance == null) return 0;
        if (a.distance == null) return 1; // Đưa null xuống cuối
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

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
        placeDetail: detail,
        viewState: MapViewState.placeDetail,
        isSearching: false,
      ));
      
      // Tự động tính toán lộ trình ngay khi chọn địa điểm
      add(const MapHomeFetchRoute());
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
    if (!state.isLocationLoaded) return;

    emit(state.copyWith(isSearching: true));

    final result = await _navigationRepository.getRoute(
      originLat: state.currentLat,
      originLng: state.currentLng,
      destinationLat: state.destinationLat!,
      destinationLng: state.destinationLng!,
      vehicle: state.vehicle,
    );

    result.fold(
      (failure) {
        debugPrint('Route fetch error: ${failure.message}');
        emit(state.copyWith(isSearching: false));
      },
      (routes) {
        if (routes.isEmpty) {
          emit(state.copyWith(isSearching: false));
          return;
        }

        final route = routes[0];
        final fullPolyline = <List<double>>[
          [state.currentLng, state.currentLat],
          ...route.polyline,
        ];
        final geoJson = _buildRouteGeoJson(fullPolyline);
        
        final staticMapUrl = _navigationRepository.getStaticMapRouteUrl(
          originLat: state.currentLat,
          originLng: state.currentLng,
          destinationLat: state.destinationLat!,
          destinationLng: state.destinationLng!,
          vehicle: state.vehicle,
        );

        emit(state.copyWith(
          distance: route.distanceText,
          duration: route.durationText,
          routeGeoJson: geoJson,
          staticMapUrl: staticMapUrl,
          isRouteActive: true,
          isSearching: false,
          route: route,
          availableRoutes: routes,
          selectedRouteIndex: 0,
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
      placeDetail: null,
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
      placeDetail: null,
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