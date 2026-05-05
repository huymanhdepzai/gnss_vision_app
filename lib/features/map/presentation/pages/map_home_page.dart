import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/page_transitions.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../voice/presentation/controllers/voice_controller.dart';
import '../../../vision/presentation/pages/satellite_page.dart';
import '../../../vision/presentation/pages/flow_page.dart';
import '../../../trip/presentation/pages/trip_manager_page.dart';
import '../../../vision/presentation/pages/navigation_vision_page.dart';
import '../../data/datasources/goong_search_data_source.dart';
import '../../data/datasources/goong_directions_data_source.dart';
import '../../data/repositories/navigation_repository_impl.dart';
import '../bloc/map_home_bloc.dart';
import '../bloc/map_home_event.dart';
import '../bloc/map_home_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/map_place_sheet.dart';
import '../widgets/map_navigation_top_bar.dart';
import '../widgets/map_navigation_panel.dart';
import '../widgets/map_floating_buttons.dart';

class MapHomeScreenV2 extends StatelessWidget {
  const MapHomeScreenV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MapHomeBloc(
        searchDataSource: GoongSearchDataSourceImpl(),
        navigationRepository:
            NavigationRepositoryImpl(GoongDirectionsDataSourceImpl()),
      )..add(const MapHomeInitLocation()),
      child: const _MapHomeView(),
    );
  }
}

class _MapHomeView extends StatefulWidget {
  const _MapHomeView({Key? key}) : super(key: key);

  @override
  State<_MapHomeView> createState() => _MapHomeViewState();
}

class _MapHomeViewState extends State<_MapHomeView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;

  late AnimationController _fabAnimationController;
  late AnimationController _sheetAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _fabScaleAnimation;
  late Animation<Offset> _sheetSlideAnimation;
  late Animation<double> _pulseAnimation;

  MapHomeState _previousState = const MapHomeState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVoiceController();
      context.read<ThemeProvider>().addListener(_onThemeChanged);
    });
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _onThemeChanged() {
    if (_mapboxMap != null) {
      _updateMapStyle(context.read<ThemeProvider>().isDarkMode);
    }
  }

  void _updateMapStyle(bool isDark) {
    final mapTilesKey = dotenv.env['GOONG_MAPTILES_KEY'] ?? '';
    final style = isDark ? 'navigation_night' : 'navigation_day';
    _mapboxMap?.loadStyleURI(
      'https://tiles.goong.io/assets/$style.json?api_key=$mapTilesKey',
    );
  }

  void _initVoiceController() {
    final voiceController = context.read<VoiceController>();
    voiceController.onCommandRecognized = _handleVoiceCommand;
    if (voiceController.isEnabled) {
      voiceController.initialize();
    }
  }

  void _handleVoiceCommand(String command) {
    final state = context.read<MapHomeBloc>().state;
    switch (command) {
      case 'gnss-vision':
        if (state.viewState == MapViewState.navigating) {
          Navigator.push(
            context,
            PageTransition(
              child: const NavigationVisionPage(),
              type: PageTransitionType.slideUp,
            ),
          );
        } else {
          Navigator.push(
            context,
            PageTransition(
              child: const FlowScreenV2(),
              type: PageTransitionType.slideUp,
            ),
          );
        }
        break;
      case 'satellite':
        Navigator.push(
          context,
          PageTransition(
            child: const SatelliteScreenV2(),
            type: PageTransitionType.fadeSlide,
            duration: const Duration(milliseconds: 600),
          ),
        );
        break;
      case 'home':
        Navigator.popUntil(context, (route) => route.isFirst);
        break;
    }
  }

  void _initAnimations() {
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _sheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    _sheetSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _sheetAnimationController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fabAnimationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pulseController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _pulseController.repeat(reverse: true);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabAnimationController.dispose();
    _sheetAnimationController.dispose();
    _pulseController.dispose();

    try {
      context.read<ThemeProvider>().removeListener(_onThemeChanged);
    } catch (e) {}

    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _updateMapStyle(context.read<ThemeProvider>().isDarkMode);
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    _circleAnnotationManager =
        await _mapboxMap?.annotations.createCircleAnnotationManager();

    final state = context.read<MapHomeBloc>().state;
    if (state.isLocationLoaded) {
      _updateCamera(
          Position(state.currentLng, state.currentLat), 16.0);
      _drawMarkers(state);
    }

    if (state.isRouteActive && state.routeGeoJson != null) {
      await _drawRouteLine(state.routeGeoJson!);
    }
  }

  void _handleStateSideEffects(MapHomeState previous, MapHomeState current) {
    if (!current.isLocationLoaded || _mapboxMap == null) return;

    if (!previous.isLocationLoaded && current.isLocationLoaded) {
      _updateCamera(
          Position(current.currentLng, current.currentLat), 16.0);
      _drawMarkers(current);
    }

    if (previous.currentLat != current.currentLat ||
        previous.currentLng != current.currentLng) {
      if (current.viewState == MapViewState.explore) {
        _updateCamera(
            Position(current.currentLng, current.currentLat), 16.0);
      }
      _drawMarkers(current);
    }

    if (previous.viewState != current.viewState &&
        current.viewState == MapViewState.placeDetail) {
      _sheetAnimationController.forward();
      if (current.destinationLat != null &&
          current.destinationLng != null) {
        _updateCamera(
            Position(current.destinationLng!, current.destinationLat!),
            15.0);
        _drawMarkers(current);
      }
    }

    if (previous.routeGeoJson != current.routeGeoJson) {
      if (current.routeGeoJson != null) {
        _drawRouteLine(current.routeGeoJson!);
      } else {
        _clearRouteOnly();
      }
      _drawMarkers(current);
    }

    if (previous.viewState != current.viewState &&
        current.viewState == MapViewState.navigating) {
      _drawMarkers(current);
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
                  coordinates:
                      Position(current.currentLng, current.currentLat))
              .toJson(),
          zoom: 17.0,
          pitch: 45.0,
        ),
        MapAnimationOptions(duration: 1500),
      );
    }

    if (previous.viewState != current.viewState &&
        current.viewState == MapViewState.explore &&
        previous.viewState != MapViewState.explore) {
      _clearRouteOnly();
      _drawMarkers(current);
      _updateCamera(
          Position(current.currentLng, current.currentLat), 16.0);
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
                  coordinates:
                      Position(current.currentLng, current.currentLat))
              .toJson(),
          zoom: 16.0,
          pitch: 0.0,
        ),
        MapAnimationOptions(duration: 800),
      );
      _sheetAnimationController.reverse();
    }
  }

  Future<void> _drawRouteLine(String geoJson) async {
    if (_mapboxMap == null) return;
    try {
      await _clearRouteOnly();
      await _mapboxMap?.style.addSource(
        GeoJsonSource(id: "route_source", data: geoJson),
      );
      var lineLayerJson = """{
        "type": "line",
        "id": "route_layer",
        "source": "route_source",
        "paint": {
          "line-join": "round",
          "line-cap": "round",
          "line-color": "#00D4FF",
          "line-width": 6.0,
          "line-blur": 2.0
        }
      }""";
      await _mapboxMap?.style.addPersistentStyleLayer(lineLayerJson, null);
    } catch (e) {
      debugPrint("Lỗi vẽ đường đi: $e");
    }
  }

  Future<void> _clearRouteOnly() async {
    try {
      await _mapboxMap?.style.removeStyleLayer("route_layer");
      await _mapboxMap?.style.removeStyleSource("route_source");
    } catch (e) {}
  }

  void _updateCamera(Position position, double zoom) {
    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: position).toJson(),
        zoom: zoom,
      ),
    );
  }

  Future<void> _drawMarkers(MapHomeState state) async {
    if (_circleAnnotationManager == null) return;
    await _circleAnnotationManager?.deleteAll();

    if (state.isLocationLoaded) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(
                  coordinates:
                      Position(state.currentLng, state.currentLat))
              .toJson(),
          circleColor: AppTheme.secondaryColor.withOpacity(0.3).value,
          circleRadius: 20.0,
        ),
      );
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(
                  coordinates:
                      Position(state.currentLng, state.currentLat))
              .toJson(),
          circleColor: AppTheme.primaryColor.value,
          circleRadius: 10.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }

    if (state.viewState != MapViewState.explore &&
        state.destinationLat != null &&
        state.destinationLng != null) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(
                  coordinates: Position(
                      state.destinationLng!, state.destinationLat!))
              .toJson(),
          circleColor: AppTheme.accentColor.value,
          circleRadius: 12.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }
  }

  void _handleSelectPlace(String placeId, String description) {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    context.read<MapHomeBloc>().add(MapHomeSelectPlace(placeId, description));
  }

  void _handleStartNavigation() {
    HapticFeedback.heavyImpact();
    _sheetAnimationController.reverse();
    final bloc = context.read<MapHomeBloc>();
    bloc.add(const MapHomeStartNavigation());
    bloc.add(const MapHomeFetchRoute());
  }

  void _handleFetchAndDrawRoute() {
    context.read<MapHomeBloc>().add(const MapHomeFetchRoute());
  }

  void _handleResetToExplore() {
    HapticFeedback.lightImpact();
    _sheetAnimationController.reverse();
    context.read<MapHomeBloc>().add(const MapHomeResetToExplore());
  }

  void _startNavigationVision() {
    HapticFeedback.heavyImpact();
    Navigator.push(
      context,
      PageTransition(
        child: const NavigationVisionPage(),
        type: PageTransitionType.slideUp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        return BlocConsumer<MapHomeBloc, MapHomeState>(
          listenWhen: (previous, current) =>
              previous.isLocationLoaded != current.isLocationLoaded ||
              previous.currentLat != current.currentLat ||
              previous.currentLng != current.currentLng ||
              previous.destinationLat != current.destinationLat ||
              previous.destinationLng != current.destinationLng ||
              previous.routeGeoJson != current.routeGeoJson ||
              previous.viewState != current.viewState,
          listener: (context, state) {
            _handleStateSideEffects(_previousState, state);
            _previousState = state;
          },
          builder: (context, state) {
            return Scaffold(
              key: _scaffoldKey,
              drawer: AppDrawer(
                onNavigateToVision: () => _handleVoiceCommand('gnss-vision'),
                onNavigateToSatellite: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      child: const SatelliteScreenV2(),
                      type: PageTransitionType.fadeSlide,
                      duration: const Duration(milliseconds: 600),
                    ),
                  );
                },
              ),
              body: Stack(
                children: [
                  MapWidget(
                    key: const ValueKey("mapWidget"),
                    resourceOptions:
                        ResourceOptions(accessToken: mapboxToken),
                    onMapCreated: _onMapCreated,
                    onStyleLoadedListener: _onStyleLoaded,
                    onTapListener: (coordinate) {
                      if (state.viewState ==
                          MapViewState.placeDetail) {
                        _handleResetToExplore();
                      }
                      FocusScope.of(context).unfocus();
                    },
                  ),
                  if (state.viewState == MapViewState.explore ||
                      state.viewState == MapViewState.placeDetail)
                    MapSearchBar(
                      state: state,
                      isDark: isDark,
                      onSearchChanged: (query) => context
                          .read<MapHomeBloc>()
                          .add(MapHomeSearchChanged(query)),
                      onSelectPlace: _handleSelectPlace,
                      onMenuTap: () => _scaffoldKey.currentState
                          ?.openDrawer(),
                      onBackTap: _handleResetToExplore,
                      onClearSearch: () => context
                          .read<MapHomeBloc>()
                          .add(const MapHomeClearSearch()),
                      onProfileTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                            context,
                            PageTransition(
                                child: const TripManagerScreen(),
                                type: PageTransitionType
                                    .slideLeft));
                      },
                      pulseAnimation: _pulseAnimation,
                      padding: EdgeInsets.fromLTRB(
                          16,
                          MediaQuery.of(context).padding.top + 8,
                          16,
                          28),
                    ),
                  if (state.viewState == MapViewState.navigating)
                    MapNavigationTopBar(
                        state: state, isDark: isDark),
                  if (state.viewState == MapViewState.placeDetail)
                    MapPlaceSheet(
                      state: state,
                      isDark: isDark,
                      onStartNavigation: _handleStartNavigation,
                      onFetchAndDrawRoute: _handleFetchAndDrawRoute,
                      slideAnimation: _sheetSlideAnimation,
                      padding: EdgeInsets.fromLTRB(
                          20,
                          14,
                          20,
                          MediaQuery.of(context).padding.bottom +
                              20),
                    ),
                  if (state.viewState == MapViewState.navigating)
                    MapNavigationPanel(
                      state: state,
                      isDark: isDark,
                      onExitNavigation: _handleResetToExplore,
                      onStartVision: _startNavigationVision,
                    ),
                ],
              ),
              floatingActionButton:
                  state.viewState != MapViewState.navigating
                      ? MapFloatingButtons(
                          state: state,
                          isDark: isDark,
                          onMyLocation: () {
                            HapticFeedback.lightImpact();
                            if (state.isLocationLoaded) {
                              _updateCamera(
                                  Position(state.currentLng,
                                      state.currentLat),
                                  16.0);
                            } else {
                              context
                                  .read<MapHomeBloc>()
                                  .add(const MapHomeInitLocation());
                            }
                          },
                          fabScaleAnimation: _fabScaleAnimation,
                          pulseAnimation: _pulseAnimation,
                        )
                      : null,
            );
          },
        );
      },
    );
  }
}