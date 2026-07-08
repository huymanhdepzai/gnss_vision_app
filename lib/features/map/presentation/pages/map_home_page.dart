import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/page_transitions.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../voice/presentation/controllers/voice_controller.dart';
import '../../../vision/presentation/pages/satellite_page.dart';
import '../../../vision/presentation/pages/flow_page.dart';
import '../../../trip/presentation/pages/trip_manager_page.dart';
import '../../../vision/presentation/pages/navigation_vision_page.dart';
import '../../data/datasources/goong_search_data_source.dart';
import '../../data/datasources/goong_directions_data_source.dart';
import '../../data/repositories/navigation_repository_impl.dart';
import '../controllers/navigation_controller.dart';
import '../bloc/map_home_bloc.dart';
import '../bloc/map_home_event.dart';
import '../bloc/map_home_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/map_place_sheet.dart';
import '../widgets/map_navigation_top_bar.dart';
import '../widgets/map_navigation_panel.dart';
import '../widgets/map_floating_buttons.dart';
import '../widgets/chat_assistant_overlay.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class MapHomeScreenV2 extends StatelessWidget {
  const MapHomeScreenV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return BlocProvider(
      create: (context) => MapHomeBloc(
        searchDataSource: GoongSearchDataSourceImpl(),
        navigationRepository:
            NavigationRepositoryImpl(
              GoongDirectionsDataSourceImpl(),
            ),
      )
        ..add(MapHomeThemeChanged(isDark))
        ..add(const MapHomeInitLocation()),
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
  bool _isDrawingMarkers = false;
  MapHomeState? _latestStateToDraw;
  bool _showAssistant = false;
  bool _isMapReady = false;
  bool _is3DMode = false;
  bool _hasNewMessage = true; // Added state for messenger-like notification

  late AnimationController _fabAnimationController;
  late AnimationController _sheetAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _fabScaleAnimation;
  late Animation<Offset> _sheetSlideAnimation;
  late Animation<double> _pulseAnimation;

  final ValueNotifier<double> _sheetExtentNotifier = ValueNotifier(0.45);

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
    context.read<MapHomeBloc>().add(
        MapHomeThemeChanged(context.read<ThemeProvider>().isDarkMode));
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
    final state = context.read<MapHomeBloc>().state;
    if (state.mapStyleUrl != null) {
      _mapboxMap?.loadStyleURI(state.mapStyleUrl!);
    }
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

  void _onMapLoaded(MapLoadedEventData data) {
    if (mounted) {
      setState(() {
        _isMapReady = true;
      });
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
    _latestStateToDraw = state;
    if (_isDrawingMarkers) return;

    _isDrawingMarkers = true;

    try {
      while (_latestStateToDraw != null) {
        final stateToDraw = _latestStateToDraw!;
        _latestStateToDraw = null;

        if (_circleAnnotationManager == null) break;

        // Xóa tất cả marker cũ trước khi vẽ mới
        await _circleAnnotationManager?.deleteAll();

        if (stateToDraw.isLocationLoaded) {
          // Vòng tròn bên ngoài (hiệu ứng pulse)
          await _circleAnnotationManager?.create(
            CircleAnnotationOptions(
              geometry: Point(
                      coordinates: Position(
                          stateToDraw.currentLng, stateToDraw.currentLat))
                  .toJson(),
              circleColor: AppTheme.secondaryColor.withOpacity(0.3).value,
              circleRadius: 20.0,
            ),
          );
          // Vòng tròn bên trong (vị trí chính xác)
          await _circleAnnotationManager?.create(
            CircleAnnotationOptions(
              geometry: Point(
                      coordinates: Position(
                          stateToDraw.currentLng, stateToDraw.currentLat))
                  .toJson(),
              circleColor: AppTheme.primaryColor.value,
              circleRadius: 10.0,
              circleStrokeWidth: 3.0,
              circleStrokeColor: Colors.white.value,
            ),
          );
        }

        // Vẽ điểm đến nếu không ở chế độ explore
        if (stateToDraw.viewState != MapViewState.explore &&
            stateToDraw.destinationLat != null &&
            stateToDraw.destinationLng != null) {
          await _circleAnnotationManager?.create(
            CircleAnnotationOptions(
              geometry: Point(
                      coordinates: Position(stateToDraw.destinationLng!,
                          stateToDraw.destinationLat!))
                  .toJson(),
              circleColor: AppTheme.accentColor.value,
              circleRadius: 12.0,
              circleStrokeWidth: 3.0,
              circleStrokeColor: Colors.white.value,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi vẽ marker: $e");
    } finally {
      _isDrawingMarkers = false;
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

  void _handleReturnToPlaceDetail() {
    HapticFeedback.mediumImpact();
    context.read<MapHomeBloc>().add(const MapHomeReturnToPlaceDetail());
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

  void _handleToggleMapMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _is3DMode = !_is3DMode;
    });
    _mapboxMap?.flyTo(
      CameraOptions(
        pitch: _is3DMode ? 60.0 : 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  void _showTopNotification(BuildContext context, String message, Color backgroundColor) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Opacity(
                  opacity: (value + 100) / 100,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        return BlocListener<AuthBloc, AuthState>(
          listener: (context, authState) {
            authState.maybeWhen(
              error: (message) {
                _showTopNotification(context, message, Colors.redAccent);
              },
              orElse: () {},
            );
          },
          child: BlocConsumer<MapHomeBloc, MapHomeState>(
            listenWhen: (previous, current) =>
                previous.isLocationLoaded != current.isLocationLoaded ||
                previous.currentLat != current.currentLat ||
                previous.currentLng != current.currentLng ||
                previous.destinationLat != current.destinationLat ||
                previous.destinationLng != current.destinationLng ||
                previous.routeGeoJson != current.routeGeoJson ||
                previous.viewState != current.viewState ||
                previous.route != current.route ||
                previous.mapStyleUrl != current.mapStyleUrl,
            listener: (context, state) {
              if (_previousState.mapStyleUrl != state.mapStyleUrl &&
                  state.mapStyleUrl != null) {
                _mapboxMap?.loadStyleURI(state.mapStyleUrl!);
              }

              if (state.viewState == MapViewState.navigating &&
                  state.route != null) {
                final navCtrl = context.read<NavigationController>();
                if (navCtrl.currentRoute != state.route) {
                  navCtrl.startNavigation(state.route!);
                }
              } else if (state.viewState != MapViewState.navigating) {
                context.read<NavigationController>().stopNavigation();
              }

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
                      onMapLoadedListener: _onMapLoaded,
                      onTapListener: (coordinate) {
                        if (state.viewState ==
                            MapViewState.placeDetail) {
                          _handleResetToExplore();
                        }
                        FocusScope.of(context).unfocus();
                      },
                    ),
                    IgnorePointer(
                      ignoring: _isMapReady,
                      child: AnimatedOpacity(
                        opacity: _isMapReady ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOutCubic,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.adaptiveSurface(isDark),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.adaptiveSurface(isDark),
                                isDark ? const Color(0xFF1A1A24) : const Color(0xFFF5F7FA),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.primaryColor.withOpacity(0.1),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 76,
                                            height: 76,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.primaryColor.withOpacity(0.2),
                                            ),
                                            child: Center(
                                              child: child,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Transform.translate(
                                    offset: Offset(0, -8 * ((_pulseAnimation.value - 1.0) / 0.15)),
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.4),
                                            blurRadius: 16,
                                            spreadRadius: 4,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.map_rounded,
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 36),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, child) {
                                          final progress = (_pulseAnimation.value - 1.0) / 0.15;
                                          return ShaderMask(
                                            blendMode: BlendMode.srcIn,
                                            shaderCallback: (bounds) {
                                              return LinearGradient(
                                                colors: [
                                                  AppTheme.adaptiveText(isDark).withOpacity(0.4),
                                                  AppTheme.adaptiveText(isDark),
                                                  AppTheme.adaptiveText(isDark).withOpacity(0.4),
                                                ],
                                                stops: [
                                                  progress - 0.3,
                                                  progress,
                                                  progress + 0.3,
                                                ],
                                                begin: const Alignment(-1.0, 0.0),
                                                end: const Alignment(1.0, 0.0),
                                              ).createShader(bounds);
                                            },
                                            child: const Text(
                                              'Đang chuẩn bị bản đồ...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, child) {
                                          final opacity = 0.3 + 0.7 * ((_pulseAnimation.value - 1.0) / 0.15);
                                          return Text(
                                            'Vui lòng đợi trong giây lát',
                                            style: TextStyle(
                                              color: AppTheme.adaptiveText(isDark).withOpacity(opacity),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (state.viewState == MapViewState.explore ||
                        state.viewState == MapViewState.placeDetail)
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, authState) {
                          final user = authState.maybeWhen(
                            authenticated: (u, isBio) => u,
                            orElse: () => null,
                          );
                          return MapSearchBar(
                            state: state,
                            isDark: isDark,
                            user: user,
                            onSearchChanged: (query) => context
                                .read<MapHomeBloc>()
                                .add(MapHomeSearchChanged(query)),
                            onSelectPlace: _handleSelectPlace,
                            onMenuTap: () =>
                                _scaffoldKey.currentState?.openDrawer(),
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
                                      type: PageTransitionType.slideLeft));
                            },
                            pulseAnimation: _pulseAnimation,
                            padding: EdgeInsets.fromLTRB(
                                16,
                                MediaQuery.of(context).padding.top + 8,
                                16,
                                28),
                          );
                        },
                      ),
                    if (state.viewState == MapViewState.navigating)
                      MapNavigationTopBar(
                          state: state, isDark: isDark),
                    if (state.viewState == MapViewState.placeDetail)
                      SlideTransition(
                        position: _sheetSlideAnimation,
                        child: NotificationListener<
                            DraggableScrollableNotification>(
                          onNotification: (notification) {
                            _sheetExtentNotifier.value = notification.extent;
                            return true;
                          },
                          child: DraggableScrollableSheet(
                            initialChildSize: 0.45,
                            minChildSize: 0.3,
                            maxChildSize: 0.9,
                            snap: true,
                            snapSizes: const [0.3, 0.45, 0.9],
                            builder: (context, scrollController) {
                              return MapPlaceSheet(
                                state: state,
                                isDark: isDark,
                                onStartNavigation: _handleStartNavigation,
                                onFetchAndDrawRoute: _handleFetchAndDrawRoute,
                                onVehicleSelected: (vehicle) => context
                                    .read<MapHomeBloc>()
                                    .add(MapHomeVehicleSelected(vehicle)),
                                onRouteSelected: (index) => context
                                    .read<MapHomeBloc>()
                                    .add(MapHomeRouteSelected(index)),
                                scrollController: scrollController,
                                padding: EdgeInsets.fromLTRB(
                                    20,
                                    14,
                                    20,
                                    MediaQuery.of(context).padding.bottom +
                                        20),
                              );
                            },
                          ),
                        ),
                      ),
                    if (state.viewState == MapViewState.navigating)
                      MapNavigationPanel(
                        state: state,
                        isDark: isDark,
                        onExitNavigation: _handleReturnToPlaceDetail,
                        onStartVision: _startNavigationVision,
                      ),
                    // Di chuyển Floating Buttons vào Stack để không bị đè
                    if (state.viewState != MapViewState.navigating)
                      ValueListenableBuilder<double>(
                        valueListenable: _sheetExtentNotifier,
                        builder: (context, extent, child) {
                          return Positioned(
                            right: 16,
                            bottom: state.viewState == MapViewState.placeDetail
                                ? (MediaQuery.of(context).size.height * extent) +
                                    16
                                : MediaQuery.of(context).padding.bottom + 16,
                            child: MapFloatingButtons(
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
                              onToggleAssistant: () {
                                setState(() {
                                  _showAssistant = !_showAssistant;
                                  if (_showAssistant) {
                                    _hasNewMessage = false;
                                  }
                                });
                                if (_showAssistant) {
                                  HapticFeedback.mediumImpact();
                                }
                              },
                              onToggleMapMode: _handleToggleMapMode,
                              is3DMode: _is3DMode,
                              fabScaleAnimation: _fabScaleAnimation,
                              pulseAnimation: _pulseAnimation,
                              hasNewMessage: _hasNewMessage,
                            ),
                          );
                        },
                      ),
                    if (_showAssistant)
                      GestureDetector(
                        onTap: () => setState(() => _showAssistant = false),
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox.expand(),
                      ),
                    if (_showAssistant)
                      Positioned(
                        right: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 80,
                        child: ChatAssistantOverlay(
                          isDark: isDark,
                          onClose: () => setState(() => _showAssistant = false),
                          onAction: (action) {
                            setState(() => _showAssistant = false);
                            if (action == 'gnss-vision' || action == 'satellite') {
                              _handleVoiceCommand(action);
                            }
                            // 'search' just closes the assistant so the user can use the search bar
                          },
                        ),
                      ),
                    if (state.viewState != MapViewState.navigating && state.isLocationLoaded)
                      Positioned(
                        left: 16,
                        top: MediaQuery.of(context).padding.top + 80,
                        child: _buildGnssQualityIndicator(isDark, state.locationAccuracy),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGnssQualityIndicator(bool isDark, double accuracy) {
    Color color;
    String label;
    IconData icon;
    
    // Accuracy is in meters. Lower is better.
    if (accuracy <= 10.0) {
      color = AppTheme.successColor;
      label = 'GNSS Tốt';
      icon = Icons.signal_cellular_alt_rounded;
    } else if (accuracy <= 30.0) {
      color = AppTheme.warningColor;
      label = 'GNSS Khá';
      icon = Icons.signal_cellular_alt_2_bar_rounded;
    } else {
      color = AppTheme.errorDark;
      label = 'GNSS Yếu';
      icon = Icons.signal_cellular_connected_no_internet_0_bar_rounded;
    }

    // Hide if accuracy is 0 (probably not yet initialized properly)
    if (accuracy <= 0.0) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F).withOpacity(0.9) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}