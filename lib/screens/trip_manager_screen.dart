import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/page_transitions.dart';
import '../controllers/theme_provider.dart';
import '../controllers/trip_controller.dart';
import '../models/trip.dart';
import '../models/media_file.dart';
import 'trip_detail_screen.dart';
import 'create_trip_screen.dart';

class TripManagerScreen extends StatefulWidget {
  const TripManagerScreen({Key? key}) : super(key: key);

  @override
  State<TripManagerScreen> createState() => _TripManagerScreenState();
}

class _TripManagerScreenState extends State<TripManagerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripController>().loadTrips();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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
          appBar: _buildAppBar(isDark),
          body: Consumer<TripController>(
            builder: (context, tripController, child) {
              if (tripController.isLoading) {
                return _buildLoadingState(isDark);
              }

              if (tripController.trips.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return _buildTripList(tripController, isDark);
            },
          ),
          floatingActionButton: _buildFAB(isDark),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
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
            size: 18,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Lịch Trình CủaTôi',
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.secondaryColor.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
          },
        ),
        const SizedBox(width: 8),
      ],
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
            'Đang tải lịch trình...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.secondaryColor.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route_outlined,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có lịch trình nào',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bắt đầu ghi lại hành trình của bạn\nbằng cách tạo lịch trình mới',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 14,
              ),
            ),
            // const SizedBox(height: 32),
            // _buildCreateButton(isDark),
          ],
        ),
      ),
    );
  }

  // Widget _buildCreateButton(bool isDark) {
  //   return GestureDetector(
  //     onTap: () {
  //       HapticFeedback.mediumImpact();
  //     },
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  //       decoration: BoxDecoration(
  //         gradient: AppTheme.primaryGradient,
  //         borderRadius: BorderRadius.circular(24),
  //         boxShadow: [
  //           BoxShadow(
  //             color: AppTheme.primaryColor.withOpacity(0.3),
  //             blurRadius: 20,
  //             spreadRadius: 2,
  //           ),
  //         ],
  //       ),
  //       child: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Container(
  //             padding: const EdgeInsets.all(6),
  //             decoration: BoxDecoration(
  //               color: Colors.white.withOpacity(0.2),
  //               shape: BoxShape.circle,
  //             ),
  //             child: const Icon(
  //               Icons.add_rounded,
  //               color: Colors.white,
  //               size: 18,
  //             ),
  //           ),
  //           const SizedBox(width: 12),
  //           const Text(
  //             'Tạo Lịch Trình Mới',
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontSize: 16,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildTripList(TripController tripController, bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tripController.trips.length,
        itemBuilder: (context, index) {
          final trip = tripController.trips[index];
          final media = tripController.getMediaForTrip(trip.id);
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(50 * (1 - value), 0),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _buildTripCard(trip, media, isDark),
          );
        },
      ),
    );
  }

  Widget _buildTripCard(Trip trip, List<MediaFile> media, bool isDark) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final imageCount = media.where((m) => m.type == MediaType.image).length;
    final videoCount = media.where((m) => m.type == MediaType.video).length;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageTransition(
            child: TripDetailScreen(tripId: trip.id),
            type: PageTransitionType.slideLeft,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
            width: 1,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ColorFilter.mode(
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.02),
              BlendMode.srcOver,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.2),
                              AppTheme.secondaryColor.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.title,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateFormat.format(trip.createdAt),
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trip.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.successColor.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Đang đi',
                                style: TextStyle(
                                  color: AppTheme.successColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.straighten_rounded,
                        label: trip.distance > 0
                            ? '${trip.distance.toStringAsFixed(1)} km'
                            : '--km',
                        color: AppTheme.accentColor,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        icon: Icons.timer_outlined,
                        label: trip.duration.isNotEmpty
                            ? trip.duration
                            : '--phút',
                        color: AppTheme.successColor,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      if (imageCount > 0 || videoCount > 0)
                        _buildInfoChip(
                          icon: Icons.photo_library_rounded,
                          label:
                              '$imageCount ảnh${videoCount > 0 ? ', $videoCount video' : ''}',
                          color: AppTheme.warningColor,
                          isDark: isDark,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildLocationInfo(
                            label: 'Điểm bắt đầu',
                            lat: trip.startLat,
                            lng: trip.startLng,
                            address: trip.startAddress,
                            isDark: isDark,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.3),
                        ),
                        Expanded(
                          child: _buildLocationInfo(
                            label: 'Điểm kết thúc',
                            lat: trip.endLat,
                            lng: trip.endLng,
                            address: trip.endAddress,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildMediaPreview(media, isDark),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo({
    required String label,
    required double lat,
    required double lng,
    String? address,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          address ?? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMediaPreview(List<MediaFile> media, bool isDark) {
    final displayMedia = media.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media đính kèm',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayMedia.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final m = displayMedia[index];
              final isLast = index == 3 && media.length > 4;
              final remainingCount = media.length - 4;

              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: m.type == MediaType.image
                          ? (File(m.filePath).existsSync()
                                ? Image.file(
                                    File(m.filePath),
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                  )
                                : Container(
                                    color: isDark
                                        ? AppTheme.surfaceDark
                                        : AppTheme.cardLight,
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black26,
                                    ),
                                  ))
                          : Container(
                              color: isDark
                                  ? AppTheme.surfaceDark
                                  : AppTheme.cardLight,
                              child: Icon(
                                Icons.play_circle_outline_rounded,
                                color: AppTheme.accentColor,
                                size: 32,
                              ),
                            ),
                    ),
                  ),
                  if (isLast)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '+$remainingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFAB(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () async {
        HapticFeedback.mediumImpact();
        final result = await Navigator.push(
          context,
          PageTransition(
            child: const CreateTripScreen(),
            type: PageTransitionType.slideUp,
          ),
        );
        if (result != null && result is Trip) {
          context.read<TripController>().loadTrips();
        }
      },
      backgroundColor: AppTheme.primaryColor,
      elevation: 8,
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
      ),
      label: const Text(
        'Lịch Trình Mới',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
