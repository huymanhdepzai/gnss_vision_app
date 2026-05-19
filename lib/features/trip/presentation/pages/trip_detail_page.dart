import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../controllers/trip_controller.dart';
import '../../data/models/trip.dart';
import '../../data/models/media_file.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  bool _isLoading = true;
  Trip? _trip;
  List<MediaFile> _mediaFiles = [];
  int _selectedMediaIndex = 0;
  bool _showMediaViewer = false;
  VideoPlayerController? _videoController;
  final ScrollController _scrollController = ScrollController();
  bool _showTitleInAppBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final showTitle = _scrollController.offset > 140;
        if (showTitle != _showTitleInAppBar) {
          setState(() {
            _showTitleInAppBar = showTitle;
          });
        }
      }
    });
  }

  Future<void> _loadData() async {
    final tripController = context.read<TripController>();
    await tripController.loadTrips();

    if (mounted) {
      final trip = tripController.getTripById(widget.tripId);
      setState(() {
        _trip = trip;
        if (_trip != null) {
          _mediaFiles = tripController.getMediaForTrip(widget.tripId);
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: AppTheme.adaptiveBackground(isDark),
          body: _isLoading
              ? _buildLoadingState(isDark)
              : _trip == null
                  ? _buildErrorState(isDark)
                  : Stack(
                      children: [
                        _buildMainContent(isDark),
                        if (_showMediaViewer) _buildMediaViewer(isDark),
                      ],
                    ),
          floatingActionButton: !_showMediaViewer && _trip != null
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddMediaOptions(isDark),
                  icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
                  label: const Text('Thêm kỷ niệm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.primaryColor,
                  elevation: 8,
                )
              : null,
        );
      },
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Đang lấy dữ liệu...',
            style: TextStyle(
              color: AppTheme.adaptiveSubtext(isDark),
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: AppTheme.iconContainerDecoration(
                isDark: isDark,
                color: AppTheme.accentColor,
              ),
              child: const Icon(Icons.location_off_rounded, size: 64, color: AppTheme.accentColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Không tìm thấy hành trình',
              style: TextStyle(
                color: AppTheme.adaptiveText(isDark),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dữ liệu hành trình này có thể đã bị xóa hoặc không còn tồn tại.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.adaptiveSubtext(isDark),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Quay lại danh sách', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(isDark),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTripSummaryCard(isDark),
                const SizedBox(height: 32),
                _buildSectionHeader('Bản đồ lộ trình', Icons.map_outlined, isDark),
                const SizedBox(height: 16),
                _buildMapCard(isDark),
                const SizedBox(height: 32),
                _buildSectionHeader('Chi tiết điểm đến', Icons.route_outlined, isDark),
                const SizedBox(height: 16),
                _buildTimeline(isDark),
                const SizedBox(height: 32),
                if (_mediaFiles.isNotEmpty) ...[
                  _buildSectionHeader('Ảnh & Video kỷ niệm', Icons.photo_library_outlined, isDark),
                  const SizedBox(height: 16),
                  _buildMediaGallery(isDark),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.adaptiveBackground(isDark),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: isDark ? Colors.black26 : Colors.white70,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.adaptiveText(isDark)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: isDark ? Colors.black26 : Colors.white70,
            child: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.accentColor),
              onPressed: () => _showDeleteConfirmation(isDark),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      title: AnimatedOpacity(
        opacity: _showTitleInAppBar ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          _trip?.title ?? '',
          style: TextStyle(
            color: AppTheme.adaptiveText(isDark),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Immersive background - gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.8),
                    AppTheme.adaptiveBackground(isDark),
                  ],
                ),
              ),
            ),
            // Subtitle and info
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: EntranceAnimation(
                type: EntranceType.fadeSlideUp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (_trip!.isActive ? AppTheme.successColor : AppTheme.primaryColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (_trip!.isActive ? AppTheme.successColor : AppTheme.primaryColor).withOpacity(0.5)),
                      ),
                      child: Text(
                        _trip!.isActive ? 'ĐANG DI CHUYỂN' : 'ĐÃ HOÀN THÀNH',
                        style: TextStyle(
                          color: _trip!.isActive ? AppTheme.successColor : AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _trip!.title,
                      style: TextStyle(
                        color: AppTheme.adaptiveText(isDark),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.adaptiveSubtext(isDark)),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(_trip!.createdAt),
                          style: TextStyle(
                            color: AppTheme.adaptiveSubtext(isDark),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.adaptiveText(isDark),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTripSummaryCard(bool isDark) {
    return EntranceAnimation(
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricItem(
              icon: Icons.route_rounded,
              label: 'Quãng đường',
              value: _trip!.distance > 0 ? '${_trip!.distance.toStringAsFixed(1)}' : '--',
              unit: 'km',
              color: AppTheme.primaryColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricItem(
              icon: Icons.speed_rounded,
              label: 'Thời gian',
              value: _trip!.duration.isNotEmpty ? _trip!.duration.split(' ').first : '--',
              unit: _trip!.duration.isNotEmpty ? _trip!.duration.split(' ').last : 'phút',
              color: AppTheme.secondaryColor,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(isDark: isDark, accentColor: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.iconContainerDecoration(isDark: isDark, color: color, radius: 12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(color: AppTheme.adaptiveSubtext(isDark), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(color: AppTheme.adaptiveText(isDark), fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(color: AppTheme.adaptiveSubtext(isDark), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(bool isDark) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    return EntranceAnimation(
      delay: const Duration(milliseconds: 200),
      child: Container(
        height: 220,
        decoration: AppTheme.cardDecoration(isDark: isDark),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            MapWidget(
              key: const ValueKey("tripDetailMap"),
              resourceOptions: ResourceOptions(accessToken: mapboxToken),
              onMapCreated: (mapboxMap) {
                _mapboxMap = mapboxMap;
                final mapTilesKey = dotenv.env['GOONG_MAPTILES_KEY'] ?? '';
                _mapboxMap?.loadStyleURI(
                  'https://tiles.goong.io/assets/navigation_night.json?api_key=$mapTilesKey',
                );
              },
              onStyleLoadedListener: (data) => _initializeMap(),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: PressScale(
                onTap: () {
                  // Full screen map logic or focus
                  if (_mapboxMap != null && _trip != null) {
                    double lat = _trip!.startLat;
                    double lng = _trip!.startLng;
                    if (lat.abs() > 90 && lng.abs() <= 90) {
                      final t = lat; lat = lng; lng = t;
                    }
                    _mapboxMap!.setCamera(CameraOptions(
                      center: Point(coordinates: Position(lng, lat)).toJson(),
                      zoom: 14.0,
                    ));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: AppTheme.glassDecoration(isDark: isDark, tintColor: AppTheme.primaryColor),
                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeMap() async {
    if (_mapboxMap == null || _trip == null) return;

    // Robust coordinate handling: identify potential swaps (lat vs lng)
    double startLat = _trip!.startLat;
    double startLng = _trip!.startLng;
    if (startLat.abs() > 90 && startLng.abs() <= 90) {
      final temp = startLat;
      startLat = startLng;
      startLng = temp;
    }

    double endLat = _trip!.endLat;
    double endLng = _trip!.endLng;
    if (endLat.abs() > 90 && endLng.abs() <= 90) {
      final temp = endLat;
      endLat = endLng;
      endLng = temp;
    }

    final start = Position(startLng, startLat);
    final end = Position(endLng, endLat);

    final manager = await _mapboxMap?.annotations.createCircleAnnotationManager();
    if (manager != null) {
      await manager.create(CircleAnnotationOptions(
        geometry: Point(coordinates: start).toJson(),
        circleColor: AppTheme.primaryColor.value,
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      ));
      await manager.create(CircleAnnotationOptions(
        geometry: Point(coordinates: end).toJson(),
        circleColor: AppTheme.accentColor.value,
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      ));
    }
    _mapboxMap?.setCamera(CameraOptions(center: Point(coordinates: start).toJson(), zoom: 12.0));
    _fetchAndDrawRoute(startLat, startLng, endLat, endLng);
  }

  Future<void> _fetchAndDrawRoute(double sLat, double sLng, double eLat, double eLng) async {
    final apiKey = dotenv.env['GOONG_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://rsapi.goong.io/Direction?origin=$sLat,$sLng&destination=$eLat,$eLng&vehicle=car&api_key=$apiKey',
    );

    try {
      var response = await http.get(url);
      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['routes'] != null && jsonResponse['routes'].isNotEmpty) {
        final encodedPolyline = jsonResponse['routes'][0]['overview_polyline']['points'];
        final polylineCoords = _decodePolyline(encodedPolyline);
        
        final geoJson = jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': polylineCoords.map((c) => [c[1], c[0]]).toList(),
              }
            }
          ]
        });

        _drawRouteLine(geoJson);
      }
    } catch (e) {
      debugPrint("Lỗi lấy lộ trình: $e");
    }
  }

  List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add([lat / 1E5, lng / 1E5]);
    }
    return points;
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

  Widget _buildTimeline(bool isDark) {
    return EntranceAnimation(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(isDark: isDark),
        child: Column(
          children: [
            _buildTimelineItem(
              icon: Icons.my_location_rounded,
              color: AppTheme.primaryColor,
              label: 'Điểm bắt đầu',
              address: _trip!.startAddress ?? 'Chưa rõ địa chỉ',
              time: DateFormat('HH:mm').format(_trip!.createdAt),
              isFirst: true,
              isDark: isDark,
            ),
            _buildTimelineItem(
              icon: Icons.location_on_rounded,
              color: AppTheme.accentColor,
              label: 'Điểm kết thúc',
              address: _trip!.endAddress ?? 'Chưa rõ địa chỉ',
              time: _trip!.completedAt != null ? DateFormat('HH:mm').format(_trip!.completedAt!) : '--:--',
              isLast: true,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
    required String time,
    bool isFirst = false,
    bool isLast = false,
    required bool isDark,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 2),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withOpacity(0.5), AppTheme.accentColor.withOpacity(0.5)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Text(time, style: TextStyle(color: AppTheme.adaptiveSubtext(isDark), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: TextStyle(color: AppTheme.adaptiveText(isDark), fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isLast) const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGallery(bool isDark) {
    return StaggeredGrid(
      crossAxisCount: 2,
      spacing: 12,
      children: List.generate(_mediaFiles.length, (index) {
        final media = _mediaFiles[index];
        return _buildMediaCard(media, index, isDark);
      }),
    );
  }

  Widget _buildMediaCard(MediaFile media, int index, bool isDark) {
    return PressScale(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _selectedMediaIndex = index;
          _showMediaViewer = true;
        });
        if (media.type == MediaType.video) {
          _initializeVideoPlayer(media.filePath);
        }
      },
      child: Container(
        decoration: AppTheme.cardDecoration(isDark: isDark),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            media.type == MediaType.image
                ? Image.file(File(media.filePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildMediaPlaceholder(isDark))
                : _buildVideoThumbnail(media, isDark),
            if (media.type == MediaType.video)
              const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40)),
            if (media.latitude != null && media.longitude != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.location_on_rounded, color: AppTheme.secondaryColor, size: 12),
                ),
              ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(media.type == MediaType.image ? Icons.image_rounded : Icons.videocam_rounded, color: Colors.white, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      media.type == MediaType.image ? 'Ảnh' : 'Video',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder(bool isDark) {
    return Container(
      color: AppTheme.adaptiveCard(isDark),
      child: Icon(Icons.broken_image_outlined, color: AppTheme.adaptiveSubtext(isDark)),
    );
  }

  Widget _buildVideoThumbnail(MediaFile media, bool isDark) {
    return Container(
      color: Colors.black87,
      child: const Icon(Icons.movie_creation_outlined, color: Colors.white38, size: 32),
    );
  }

  void _showAddMediaOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        decoration: BoxDecoration(
          color: AppTheme.adaptiveSurface(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.adaptiveDivier(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Thêm kỷ niệm mới', style: TextStyle(color: AppTheme.adaptiveText(isDark), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildAddOption(Icons.camera_alt_rounded, 'Máy ảnh', AppTheme.primaryColor, isDark, () => _pickMedia(MediaType.image, true))),
                const SizedBox(width: 16),
                Expanded(child: _buildAddOption(Icons.videocam_rounded, 'Quay video', AppTheme.accentColor, isDark, () => _pickMedia(MediaType.video, true))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAddOption(Icons.photo_library_rounded, 'Thư viện ảnh', AppTheme.successColor, isDark, () => _pickMedia(MediaType.image, false))),
                const SizedBox(width: 16),
                Expanded(child: _buildAddOption(Icons.video_library_rounded, 'Thư viện video', AppTheme.warningColor, isDark, () => _pickMedia(MediaType.video, false))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String label, Color color, bool isDark, VoidCallback onTap) {
    return PressScale(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: AppTheme.cardDecoration(isDark: isDark, accentColor: color),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: AppTheme.adaptiveText(isDark), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia(MediaType type, bool fromCamera) async {
    final tripController = context.read<TripController>();
    try {
      if (type == MediaType.image) {
        await tripController.pickAndAddImage(widget.tripId, fromCamera: fromCamera);
      } else {
        await tripController.pickAndAddVideo(widget.tripId, fromCamera: fromCamera);
      }
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.accentColor));
    }
  }

  Widget _buildMediaViewer(bool isDark) {
    final media = _mediaFiles[_selectedMediaIndex];
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: media.type == MediaType.image
                ? Image.file(File(media.filePath), fit: BoxFit.contain)
                : _videoController != null && _videoController!.value.isInitialized
                    ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))
                    : const CircularProgressIndicator(color: Colors.white),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showMediaViewer = false;
                  });
                  _videoController?.pause();
                },
              ),
            ),
          ),
          if (media.type == MediaType.video && _videoController != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white24,
                  onPressed: () => setState(() => _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play()),
                  child: Icon(_videoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                ),
              ),
            ),
          if (_mediaFiles.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_mediaFiles.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _selectedMediaIndex ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _selectedMediaIndex ? AppTheme.primaryColor : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  void _initializeVideoPlayer(String path) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(path));
    await _videoController!.initialize();
    setState(() {});
    _videoController!.play();
    _videoController!.setLooping(true);
  }

  void _showDeleteConfirmation(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.adaptiveSurface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Xóa hành trình?', style: TextStyle(color: AppTheme.adaptiveText(isDark), fontWeight: FontWeight.bold)),
        content: Text(
          'Mọi dữ liệu bao gồm hình ảnh và video sẽ bị xóa vĩnh viễn. Bạn có chắc chắn không?',
          style: TextStyle(color: AppTheme.adaptiveSubtext(isDark)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: AppTheme.adaptiveSubtext(isDark)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<TripController>().deleteTrip(widget.tripId);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Xóa ngay'),
          ),
        ],
      ),
    );
  }
}

