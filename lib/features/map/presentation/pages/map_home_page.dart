import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/page_transitions.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../voice/presentation/controllers/voice_controller.dart';
import '../../../vision/presentation/pages/satellite_page.dart';
import '../../../vision/presentation/pages/flow_page.dart';
import '../controllers/map_home_controller.dart';
import '../widgets/app_drawer.dart';
import '../../../trip/presentation/pages/trip_manager_page.dart';
import '../../../vision/presentation/pages/navigation_vision_page.dart';

class MapHomeScreenV2 extends StatefulWidget {
  const MapHomeScreenV2({Key? key}) : super(key: key);

  @override
  State<MapHomeScreenV2> createState() => _MapHomeScreenV2State();
}

class _MapHomeScreenV2State extends State<MapHomeScreenV2>
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<MapHomeController>();
      controller.initLocation();
      controller.navigationController.addListener(_onNavigationChanged);
      controller.addListener(_onControllerChanged);
      _initVoiceController();
    });
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _initVoiceController() {
    final voiceController = context.read<VoiceController>();
    voiceController.onCommandRecognized = _handleVoiceCommand;
    if (voiceController.isEnabled) {
      voiceController.initialize();
    }
  }

  void _handleVoiceCommand(String command) {
    switch (command) {
      case 'gnss-vision':
        _navigateToVision();
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

  void _onControllerChanged() {
    if (!mounted) return;
    final controller = context.read<MapHomeController>();
    if (controller.isLocationLoaded && _mapboxMap != null) {
      _updateCamera(controller.currentLocation, 16.0);
    }
    _drawMarkers();
  }

  void _onNavigationChanged() {
    if (!mounted) return;
    setState(() {});
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
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    _sheetSlideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _sheetAnimationController, curve: Curves.easeOutCubic),
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
    final controller = context.read<MapHomeController>();
    controller.navigationController.removeListener(_onNavigationChanged);
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    final mapTilesKey = dotenv.env['GOONG_MAPTILES_KEY'] ?? '';
    _mapboxMap?.loadStyleURI(
      'https://tiles.goong.io/assets/navigation_night.json?api_key=$mapTilesKey',
    );
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    _circleAnnotationManager = await _mapboxMap?.annotations.createCircleAnnotationManager();

    final controller = context.read<MapHomeController>();
    if (controller.isLocationLoaded) {
      _updateCamera(controller.currentLocation, 16.0);
      _drawMarkers();
    }

    if (controller.isRouteActive && controller.routeGeoJson != null) {
      await _drawRouteLine(controller.routeGeoJson!);
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

  Future<void> _drawMarkers() async {
    final controller = context.read<MapHomeController>();
    if (_circleAnnotationManager == null) return;
    await _circleAnnotationManager?.deleteAll();

    if (controller.isLocationLoaded) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: controller.currentLocation).toJson(),
          circleColor: AppTheme.secondaryColor.withOpacity(0.3).value,
          circleRadius: 20.0,
        ),
      );
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: controller.currentLocation).toJson(),
          circleColor: AppTheme.primaryColor.value,
          circleRadius: 10.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }

    if (controller.currentState != MapViewState.explore && controller.destinationLocation != null) {
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: controller.destinationLocation!).toJson(),
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
    final controller = context.read<MapHomeController>();
    controller.selectPlace(placeId, description).then((_) {
      if (controller.destinationLocation != null) {
        _updateCamera(controller.destinationLocation!, 15.0);
        _drawMarkers();
        _sheetAnimationController.forward();
      }
    });
  }

  void _handleStartNavigation() {
    HapticFeedback.heavyImpact();
    _sheetAnimationController.reverse();
    final controller = context.read<MapHomeController>();
    controller.startNavigation();
    controller.fetchRoute().then((_) {
      if (controller.routeGeoJson != null) {
        _drawRouteLine(controller.routeGeoJson!);
      }
      _drawMarkers();
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: controller.currentLocation).toJson(),
          zoom: 17.0,
          pitch: 45.0,
        ),
        MapAnimationOptions(duration: 1500),
      );
    });
  }

  void _handleFetchAndDrawRoute() {
    final controller = context.read<MapHomeController>();
    controller.fetchAndDrawRoute().then((_) {
      if (controller.routeGeoJson != null) {
        _drawRouteLine(controller.routeGeoJson!);
      }
      _drawMarkers();
    });
  }

  void _handleResetToExplore() {
    HapticFeedback.lightImpact();
    _sheetAnimationController.reverse();
    final controller = context.read<MapHomeController>();
    controller.resetToExplore();
    _clearRouteOnly();
    _drawMarkers();
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: controller.currentLocation).toJson(),
        zoom: 16.0,
        pitch: 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );
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

  void _navigateToVision() {
    final controller = context.read<MapHomeController>();
    if (controller.currentState == MapViewState.navigating) {
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
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Consumer<MapHomeController>(
      builder: (context, controller, _) {
        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(
            onNavigateToVision: _navigateToVision,
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
                resourceOptions: ResourceOptions(accessToken: mapboxToken),
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: _onStyleLoaded,
                onTapListener: (coordinate) {
                  if (controller.currentState == MapViewState.placeDetail) {
                    _handleResetToExplore();
                  }
                  FocusScope.of(context).unfocus();
                },
              ),
              if (controller.currentState == MapViewState.explore ||
                  controller.currentState == MapViewState.placeDetail)
                _buildModernSearchBar(controller),
              if (controller.currentState == MapViewState.navigating)
                _buildModernNavigationTopBar(controller),
              if (controller.currentState == MapViewState.placeDetail)
                _buildModernPlaceSheet(controller),
              if (controller.currentState == MapViewState.navigating)
                _buildModernNavigationPanel(controller),
            ],
          ),
          floatingActionButton: controller.currentState != MapViewState.navigating
              ? _buildModernFABs(controller)
              : null,
        );
      },
    );
  }

  Widget _buildModernSearchBar(MapHomeController controller) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppTheme.backgroundDark.withOpacity(0.95), AppTheme.backgroundDark.withOpacity(0.7), Colors.transparent]
                    : [Colors.white.withOpacity(0.98), Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.4), Colors.transparent],
              ),
            ),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 28),
            child: Column(
              children: [
                _buildSearchInput(controller, themeProvider),
                if (controller.searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSearchResults(controller, themeProvider),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchInput(MapHomeController controller, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppTheme.primaryColor.withOpacity(0.06) : Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          if (isDark) BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
          if (!isDark) BoxShadow(color: Colors.white.withOpacity(0.9), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                if (controller.currentState == MapViewState.explore)
                  _buildSearchIconButton(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: Icons.menu_rounded,
                    isDark: isDark,
                  ),
                if (controller.currentState == MapViewState.explore) const SizedBox(width: 8),
                if (controller.currentState == MapViewState.placeDetail)
                  _buildSearchIconButton(onTap: _handleResetToExplore, icon: Icons.arrow_back_ios_new_rounded, isDark: isDark)
                else if (controller.currentState == MapViewState.explore)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: controller.searchQuery)
                      ..selection = TextSelection.fromPosition(TextPosition(offset: controller.searchQuery.length)),
                    onChanged: controller.onSearchChanged,
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      fillColor: Colors.transparent,
                      hintText: "Tìm kiếm điểm đến...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.35),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (controller.isSearching)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppTheme.secondaryColor : AppTheme.primaryColor),
                    ),
                  )
                else if (controller.searchQuery.isNotEmpty)
                  _buildSearchIconButton(
                    onTap: controller.clearSearch,
                    icon: Icons.close_rounded,
                    isDark: isDark,
                    size: 16,
                  ),
                const SizedBox(width: 6),
                _buildProfileAvatar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchIconButton({required VoidCallback onTap, required IconData icon, required bool isDark, double size = 20}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : AppTheme.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : AppTheme.primaryColor.withOpacity(0.08), width: 1),
          boxShadow: [BoxShadow(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, color: isDark ? Colors.white70 : AppTheme.primaryColor, size: size),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(context, PageTransition(child: const TripManagerScreen(), type: PageTransitionType.slideLeft));
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3 * _pulseAnimation.value), blurRadius: 14, spreadRadius: 1, offset: const Offset(0, 3)),
                BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.15), blurRadius: 8, offset: const Offset(-1, 1)),
              ],
            ),
            child: const CircleAvatar(radius: 17, backgroundColor: Colors.transparent, child: Icon(Icons.person_rounded, color: Colors.white, size: 19)),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(MapHomeController controller, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.5);
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark.withOpacity(0.9) : Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(color: isDark ? Colors.black.withOpacity(0.5) : AppTheme.primaryColor.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: controller.searchResults.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 56, color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.05)),
              itemBuilder: (context, index) {
                final place = controller.searchResults[index];
                int delay = (index * 40).clamp(0, 250);
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 250 + delay),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(offset: Offset(15 * (1 - value), 0), child: Opacity(opacity: value, child: child));
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleSelectPlace(place.placeId, place.description),
                      splashColor: AppTheme.primaryColor.withOpacity(0.08),
                      highlightColor: AppTheme.primaryColor.withOpacity(0.04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [AppTheme.primaryColor.withOpacity(0.15), AppTheme.secondaryColor.withOpacity(0.1)]
                                      : [AppTheme.primaryColor.withOpacity(0.12), AppTheme.secondaryColor.withOpacity(0.06)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? AppTheme.primaryColor.withOpacity(0.12) : AppTheme.primaryColor.withOpacity(0.1), width: 1),
                                boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(isDark ? 0.1 : 0.08), blurRadius: 8, offset: const Offset(0, 3))],
                              ),
                              child: ShaderMask(
                                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                                child: Icon(Icons.location_on_rounded, color: Colors.white, size: isDark ? 18 : 20),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(place.mainText ?? place.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: isDark ? 15 : 14, color: textColor, height: 1.3)),
                                  if ((place.secondaryText ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(place.secondaryText!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: subtextColor, fontSize: 12, height: 1.3)),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.04) : AppTheme.primaryColor.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.4), size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPlaceSheet(MapHomeController controller) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _sheetSlideAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.cardDark.withOpacity(0.98), AppTheme.surfaceDark.withOpacity(0.96)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppTheme.primaryColor.withOpacity(0.12), blurRadius: 50, offset: const Offset(0, -15)),
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, -8)),
              BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, -3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8)]))),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.accentColor.withOpacity(0.22), AppTheme.accentColor.withOpacity(0.06)]),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.accentColor.withOpacity(0.25), width: 1.5),
                            boxShadow: [BoxShadow(color: AppTheme.accentColor.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4)), BoxShadow(color: Colors.white.withOpacity(0.08), blurRadius: 6, offset: const Offset(-2, -2))],
                          ),
                          child: const Icon(Icons.place_rounded, color: AppTheme.accentColor, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(controller.destinationName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(controller.destinationAddress, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildGradientButton(text: "Bắt đầu", icon: Icons.navigation_rounded, gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]), onTap: _handleStartNavigation)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildOutlineButton(text: "Xem đường", icon: Icons.route_rounded, onTap: _handleFetchAndDrawRoute)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({required String text, required IconData icon, required Gradient gradient, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)), BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.15), blurRadius: 8, offset: const Offset(-2, -2))],
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 20)),
                const SizedBox(width: 10),
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3, shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({required String text, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.45), width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.secondaryColor.withOpacity(0.06),
          boxShadow: [BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: AppTheme.secondaryColor, size: 20), const SizedBox(width: 10), Text(text, style: TextStyle(color: AppTheme.secondaryColor, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3))]),
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavigationTopBar(MapHomeController controller) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.backgroundDark.withOpacity(0.97), AppTheme.backgroundDark.withOpacity(0.65), Colors.transparent]),
        ),
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 28),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.cardDark.withOpacity(0.98), AppTheme.surfaceDark.withOpacity(0.96)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.12), width: 1.5),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.1), blurRadius: 25, offset: const Offset(0, 6)), BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(-2, -2))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.successColor.withOpacity(0.22), AppTheme.successColor.withOpacity(0.06)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.successColor.withOpacity(0.18), width: 1),
                  boxShadow: [BoxShadow(color: AppTheme.successColor.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: const Icon(Icons.turn_right_rounded, color: AppTheme.successColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Đang hướng tới", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                    const SizedBox(height: 3),
                    Text(controller.destinationName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavigationPanel(MapHomeController controller) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: FloatingActionButton.extended(
                        heroTag: "vision_btn",
                        backgroundColor: AppTheme.cardDark,
                        elevation: 6,
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          if (controller.currentState == MapViewState.navigating) {
                            _startNavigationVision();
                          } else {
                            Navigator.push(context, PageTransition(child: const FlowScreenV2(), type: PageTransitionType.slideUp));
                          }
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]), shape: BoxShape.circle),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                        ),
                        label: ShaderMask(shaderCallback: (bounds) => AppTheme.accentGradient.createShader(bounds), child: const Text("GNSS-Vision", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.cardDark.withOpacity(0.98), AppTheme.surfaceDark.withOpacity(0.97)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.12), width: 1.5),
              boxShadow: [
                BoxShadow(color: AppTheme.primaryColor.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, -8)),
                BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, -3)),
                BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, -4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.successColor.withOpacity(0.2), AppTheme.successColor.withOpacity(0.05)]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.successColor.withOpacity(0.15), width: 1),
                          boxShadow: [BoxShadow(color: AppTheme.successColor.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.timer_rounded, color: AppTheme.successColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(controller.duration, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.successColor, letterSpacing: -0.5, shadows: [Shadow(color: AppTheme.successColor, blurRadius: 16)])),
                            Text("Khoảng cách: ${controller.distance}", style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14, fontWeight: FontWeight.w400)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _handleResetToExplore,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.accentColor.withOpacity(0.16), AppTheme.accentColor.withOpacity(0.04)]),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.accentColor.withOpacity(0.25), width: 1),
                            boxShadow: [BoxShadow(color: AppTheme.accentColor.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: const Text("Thoát", style: TextStyle(color: AppTheme.accentColor, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFABs(MapHomeController controller) {
    return AnimatedBuilder(
      animation: _fabScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabScaleAnimation.value,
          child: Padding(
            padding: EdgeInsets.only(bottom: controller.currentState == MapViewState.placeDetail ? 260.0 : 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.warningColor.withOpacity(0.35 * _pulseAnimation.value), blurRadius: 18, spreadRadius: 1)],
                      ),
                      child: FloatingActionButton(
                        heroTag: "btn_satellite",
                        backgroundColor: AppTheme.cardDark,
                        elevation: 6,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(context, PageTransition(child: const SatelliteScreenV2(), type: PageTransitionType.fadeSlide, duration: const Duration(milliseconds: 600)));
                        },
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.warningColor.withOpacity(0.3), AppTheme.accentColor.withOpacity(0.2)])),
                          child: const Icon(Icons.satellite_alt_rounded, color: AppTheme.warningColor),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.35 * (2 - _pulseAnimation.value)), blurRadius: 18, spreadRadius: 1)],
                      ),
                      child: FloatingActionButton(
                        heroTag: "btn_location",
                        backgroundColor: AppTheme.cardDark,
                        elevation: 6,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (controller.isLocationLoaded) {
                            _updateCamera(controller.currentLocation, 16.0);
                          } else {
                            controller.initLocation();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.primaryColor.withOpacity(0.3), AppTheme.secondaryColor.withOpacity(0.25)])),
                          child: const Icon(Icons.my_location_rounded, color: AppTheme.secondaryColor),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}