import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/page_transitions.dart';
import '../../../../core/providers/theme_provider.dart';
import '../controllers/trip_controller.dart';
import '../../data/models/trip.dart';
import '../../data/models/media_file.dart';
import '../../../../shared/data/services/media_service.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  Trip? _trip;
  List<MediaFile> _mediaFiles = [];
  int _selectedMediaIndex = 0;
  bool _showMediaViewer = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final tripController = context.read<TripController>();
    await tripController.loadTrips();

    setState(() {
      _trip = tripController.getTripById(widget.tripId);
      if (_trip != null) {
        _mediaFiles = tripController.getMediaForTrip(widget.tripId);
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: isDark
              ? AppTheme.backgroundDark
              : AppTheme.backgroundLight,
          body: _isLoading
              ? _buildLoadingState(isDark)
              : _trip == null
              ? _buildErrorState(isDark)
              : Stack(
                  children: [
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildContent(isDark),
                    ),
                    if (_showMediaViewer) _buildMediaViewer(isDark),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Đang tải chi tiết...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy lịch trình',
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Quay lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(isDark),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTripHeader(isDark),
                const SizedBox(height: 20),
                _buildMapPreview(isDark),
                const SizedBox(height: 20),
                _buildTripInfo(isDark),
                const SizedBox(height: 20),
                _buildCoordinatesCard(isDark),
                const SizedBox(height: 24),
                if (_mediaFiles.isNotEmpty) ...[
                  _buildMediaSection(isDark),
                  const SizedBox(height: 24),
                ],
                _buildAddMediaButtons(isDark),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 16,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.accentColor,
              size: 18,
            ),
          ),
          onPressed: () => _showDeleteConfirmation(isDark),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTripHeader(bool isDark) {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy - HH:mm');
    final dateStr = dateFormat.format(_trip!.createdAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.2),
            AppTheme.secondaryColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trip!.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (_trip!.isActive
                                ? AppTheme.successColor
                                : AppTheme.warningColor)
                            .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _trip!.isActive
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _trip!.isActive ? 'Đang di chuyển' : 'Đã hoàn thành',
                        style: TextStyle(
                          color: _trip!.isActive
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview(bool isDark) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MapWidget(
            key: const ValueKey("tripMapWidget"),
            resourceOptions: ResourceOptions(accessToken: mapboxToken),
            onMapCreated: (mapboxMap) {
              _mapboxMap = mapboxMap;
              final mapTilesKey = dotenv.env['GOONG_MAPTILES_KEY'] ?? '';
              _mapboxMap?.loadStyleURI(
                'https://tiles.goong.io/assets/navigation_night.json?api_key=$mapTilesKey',
              );
            },
            onStyleLoadedListener: (data) async {
              _initializeMap();
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardDark.withOpacity(0.9)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_rounded,
                    color: AppTheme.primaryColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Lộ trình',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _initializeMap() async {
    if (_mapboxMap == null || _trip == null) return;

    final start = Position(_trip!.startLng, _trip!.startLat);
    final end = Position(_trip!.endLng, _trip!.endLat);

    final manager = await _mapboxMap?.annotations
        .createCircleAnnotationManager();
    if (manager != null) {
      await manager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: start).toJson(),
          circleColor: AppTheme.primaryColor.value,
          circleRadius: 12.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );

      await manager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: end).toJson(),
          circleColor: AppTheme.accentColor.value,
          circleRadius: 12.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }

    _mapboxMap?.setCamera(
      CameraOptions(center: Point(coordinates: start).toJson(), zoom: 13.0),
    );
  }

  Widget _buildTripInfo(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: Icons.straighten_rounded,
            label: 'Khoảng cách',
            value: _trip!.distance > 0
                ? '${_trip!.distance.toStringAsFixed(1)} km'
                : '-- km',
            color: AppTheme.accentColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.timer_outlined,
            label: 'Thời gian',
            value: _trip!.duration.isNotEmpty ? _trip!.duration : '-- phút',
            color: AppTheme.successColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.cardDark.withOpacity(0.98),
                  AppTheme.surfaceDark.withOpacity(0.98),
                ]
              : [
                  Colors.white.withOpacity(0.98),
                  AppTheme.cardLight.withOpacity(0.98),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tọa độ',
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildCoordinateRow(
            icon: Icons.circle_rounded,
            iconColor: AppTheme.primaryColor,
            label: 'Điểm bắt đầu',
            lat: _trip!.startLat,
            lng: _trip!.startLng,
            address: _trip!.startAddress,
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 2,
              height: 30,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
          _buildCoordinateRow(
            icon: Icons.location_on_rounded,
            iconColor: AppTheme.accentColor,
            label: 'Điểm kết thúc',
            lat: _trip!.endLat,
            lng: _trip!.endLng,
            address: _trip!.endAddress,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double lat,
    required double lng,
    String? address,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address ??
                    '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.copy_rounded,
            color: isDark ? Colors.white38 : Colors.black38,
            size: 18,
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: '$lat, $lng'));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Đã sao chép tọa độ'),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMediaSection(bool isDark) {
    final imageMedia = _mediaFiles
        .where((m) => m.type == MediaType.image)
        .toList();
    final videoMedia = _mediaFiles
        .where((m) => m.type == MediaType.video)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ảnh & Video (${_mediaFiles.length})',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_mediaFiles.isNotEmpty)
              TextButton.icon(
                onPressed: () {},
                icon: Icon(
                  Icons.grid_view_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                label: Text(
                  'Xem tất cả',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _mediaFiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final media = _mediaFiles[index];
              return _buildMediaItem(media, index, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(MediaFile media, int index, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedMediaIndex = index;
          _showMediaViewer = true;
        });
        if (media.type == MediaType.video) {
          _initializeVideoPlayer(media.filePath);
        }
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: media.type == MediaType.image
                  ? (File(media.filePath).existsSync()
                        ? Image.file(File(media.filePath), fit: BoxFit.cover)
                        : Container(
                            color: isDark
                                ? AppTheme.surfaceDark
                                : AppTheme.cardLight,
                            child: Icon(
                              Icons.image_not_supported_rounded,
                              color: isDark ? Colors.white24 : Colors.black26,
                              size: 32,
                            ),
                          ))
                  : Container(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.cardLight,
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        color: AppTheme.accentColor,
                        size: 40,
                      ),
                    ),
            ),
            if (media.type == MediaType.video)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            if (media.latitude != null && media.longitude != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.accentColor,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'GPS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildMediaViewer(bool isDark) {
    final media = _mediaFiles[_selectedMediaIndex];

    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Stack(
        children: [
          Center(
            child: media.type == MediaType.image
                ? (File(media.filePath).existsSync()
                      ? Image.file(File(media.filePath), fit: BoxFit.contain)
                      : Container())
                : _videoController != null &&
                      _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const CircularProgressIndicator(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMediaViewer = false;
                });
                _videoController?.dispose();
                _videoController = null;
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          if (media.type == MediaType.video && _videoController != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      _videoController?.play();
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.pause_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      _videoController?.pause();
                    },
                  ),
                ],
              ),
            ),
          if (_mediaFiles.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 100,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_mediaFiles.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _selectedMediaIndex
                          ? AppTheme.primaryColor
                          : Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
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
  }

  Widget _buildAddMediaButtons(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thêm ảnh/video',
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAddButton(
                icon: Icons.camera_alt_rounded,
                label: 'Chụp ảnh',
                color: AppTheme.primaryColor,
                isDark: isDark,
                onTap: () => _pickMedia(MediaType.image, fromCamera: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAddButton(
                icon: Icons.videocam_rounded,
                label: 'Quay video',
                color: AppTheme.accentColor,
                isDark: isDark,
                onTap: () => _pickMedia(MediaType.video, fromCamera: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAddButton(
                icon: Icons.photo_library_rounded,
                label: 'Ảnh từ thư viện',
                color: AppTheme.successColor,
                isDark: isDark,
                onTap: () => _pickMedia(MediaType.image, fromCamera: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAddButton(
                icon: Icons.video_library_rounded,
                label: 'Video từ thư viện',
                color: AppTheme.warningColor,
                isDark: isDark,
                onTap: () => _pickMedia(MediaType.video, fromCamera: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia(MediaType type, {required bool fromCamera}) async {
    final tripController = context.read<TripController>();

    try {
      if (type == MediaType.image) {
        await tripController.pickAndAddImage(
          widget.tripId,
          fromCamera: fromCamera,
        );
      } else {
        await tripController.pickAndAddVideo(
          widget.tripId,
          fromCamera: fromCamera,
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Xóa lịch trình?',
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Hành động này không thể hoàn tác. Tất cả ảnh và video liên quan cũng sẽ bị xóa.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Hủy',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final tripController = context.read<TripController>();
              await tripController.deleteTrip(widget.tripId);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
