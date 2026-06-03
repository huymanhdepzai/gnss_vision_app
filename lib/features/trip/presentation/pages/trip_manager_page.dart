import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/page_transitions.dart';
import '../../../../core/providers/theme_provider.dart';
import '../controllers/trip_controller.dart';
import '../../data/models/trip.dart';
import '../../data/models/media_file.dart';
import 'trip_detail_page.dart';
import 'create_trip_page.dart';

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
      duration: UIConsts.animEntrance,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: UIConsts.curveEntrance),
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
          backgroundColor: AppTheme.adaptiveBackground(isDark),
          body: Consumer<TripController>(
            builder: (context, tripController, child) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(isDark),
                  if (tripController.isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildLoadingState(isDark),
                    )
                  else if (tripController.trips.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isDark),
                    )
                  else
                    _buildSliverTripList(tripController, isDark),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
          floatingActionButton: _buildFAB(isDark),
        );
      },
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.adaptiveBackground(isDark).withOpacity(0.9),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.only(
          start: UIConsts.spacing2XL,
          bottom: UIConsts.spacingLG,
        ),
        title: Text(
          'Hành Trình',
          style: TextStyle(
            color: AppTheme.adaptiveText(isDark),
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          children: [
            Positioned(
              right: -50,
              top: -20,
              child: Opacity(
                opacity: isDark ? 0.1 : 0.05,
                child: Icon(
                  Icons.map_rounded,
                  size: 200,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
      leading: Center(
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.iconContainerDecoration(
              isDark: isDark,
              color: Colors.grey,
            ).copyWith(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.adaptiveText(isDark),
              size: 16,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.iconContainerDecoration(
              isDark: isDark,
              color: AppTheme.successColor,
            ),
            child: const Icon(
              Icons.cloud_download_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          onPressed: () async {
            HapticFeedback.mediumImpact();
            final tripController = context.read<TripController>();
            final success = await tripController.syncAllFromCloud();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success 
                      ? 'Đã tải dữ liệu từ đám mây thành công' 
                      : 'Đồng bộ thất bại: ${tripController.error}',
                  ),
                  backgroundColor: success ? AppTheme.successColor : AppTheme.errorDark,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.iconContainerDecoration(
              isDark: isDark,
              color: AppTheme.primaryColor,
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
        const SizedBox(width: UIConsts.spacingLG),
      ],
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
          const SizedBox(height: UIConsts.spacingLG),
          Text(
            'Đang tải hành trình...',
            style: TextStyle(
              color: AppTheme.adaptiveSubtext(isDark),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(UIConsts.spacing3XL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(UIConsts.spacing3XL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.secondaryColor.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore_outlined,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: UIConsts.spacing2XL),
            Text(
              'Chưa có hành trình nào',
              style: TextStyle(
                color: AppTheme.adaptiveText(isDark),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: UIConsts.spacingSM),
            Text(
              'Mỗi bước chân là một câu chuyện.\nHãy bắt đầu ghi lại hành trình của bạn ngay!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.adaptiveSubtext(isDark),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverTripList(TripController tripController, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: UIConsts.spacingLG),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final trip = tripController.trips[index];
            final media = tripController.getMediaForTrip(trip.id);
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 100)),
              curve: UIConsts.curveEntrance,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: _buildTripCard(trip, media, isDark, tripController),
            );
          },
          childCount: tripController.trips.length,
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip, List<MediaFile> media, bool isDark, TripController tripController) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final imageCount = media.where((m) => m.type == MediaType.image).length;
    final videoCount = media.where((m) => m.type == MediaType.video).length;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final shouldReload = await Navigator.push(
          context,
          PageTransition(
            child: TripDetailScreen(tripId: trip.id),
            type: PageTransitionType.slideLeft,
          ),
        );
        if (shouldReload == true && mounted) {
           context.read<TripController>().loadTrips();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: UIConsts.spacingLG),
        decoration: AppTheme.cardDecoration(
          isDark: isDark,
          accentColor: trip.isActive ? AppTheme.successColor : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UIConsts.radiusXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(UIConsts.spacingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(UIConsts.spacingMD),
                          decoration: AppTheme.iconContainerDecoration(
                            isDark: isDark,
                            color: trip.isActive ? AppTheme.successColor : AppTheme.primaryColor,
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/route.svg',
                            colorFilter: ColorFilter.mode(
                              trip.isActive ? AppTheme.successColor : AppTheme.primaryColor,
                              BlendMode.srcIn,
                            ),
                            width: 24,
                            height: 24,
                          ),
                        ),
                        const SizedBox(width: UIConsts.spacingLG),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.title,
                                style: TextStyle(
                                  color: AppTheme.adaptiveText(isDark),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, 
                                      size: 12, color: AppTheme.adaptiveSubtext(isDark)),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateFormat.format(trip.createdAt),
                                    style: TextStyle(
                                      color: AppTheme.adaptiveSubtext(isDark),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (trip.isActive)
                          _buildActiveBadge()
                        else ...[
                          if (trip.isSynced)
                            Icon(
                              Icons.cloud_done_rounded,
                              color: AppTheme.successColor.withOpacity(0.8),
                              size: 22,
                            )
                          else if (tripController.isSyncing(trip.id))
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                              ),
                            )
                          else
                            IconButton(
                              icon: Icon(
                                Icons.cloud_upload_outlined,
                                color: AppTheme.primaryColor.withOpacity(0.7),
                                size: 22,
                              ),
                              onPressed: () => _handleSync(context, tripController, trip),
                            ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.adaptiveSubtext(isDark).withOpacity(0.5),
                          ),
                        ],
                      ],
                    ),
                    if (tripController.isSyncing(trip.id)) ...[
                      const SizedBox(height: UIConsts.spacingMD),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: tripController.getSyncProgress(trip.id),
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Đang tải lên: ${(tripController.getSyncProgress(trip.id) * 100).toInt()}%',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: UIConsts.spacingXL),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSyncStatusBadge(trip.isSynced, isDark),
                          const SizedBox(width: UIConsts.spacingSM),
                          _buildInfoChip(
                            icon: Icons.straighten_rounded,
                            label: trip.distance > 0
                                ? '${trip.distance.toStringAsFixed(1)} km'
                                : '-- km',
                            color: AppTheme.accentColor,
                            isDark: isDark,
                          ),
                          const SizedBox(width: UIConsts.spacingSM),
                          _buildInfoChip(
                            icon: Icons.timer_outlined,
                            label: trip.duration.isNotEmpty
                                ? trip.duration
                                : '-- phút',
                            color: AppTheme.successColor,
                            isDark: isDark,
                          ),
                          if (imageCount > 0 || videoCount > 0) ...[
                            const SizedBox(width: UIConsts.spacingSM),
                            _buildInfoChip(
                              icon: Icons.photo_library_rounded,
                              label: '${imageCount + videoCount}',
                              color: AppTheme.warningColor,
                              isDark: isDark,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: UIConsts.spacingXL),
                    _buildLocationTimeline(trip, isDark),
                  ],
                ),
              ),
              if (media.isNotEmpty)
                _buildMediaStrip(media, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusBadge(bool isSynced, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSynced
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.adaptiveDivier(isDark).withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConsts.radiusMD),
        border: Border.all(
          color: isSynced
              ? AppTheme.successColor.withOpacity(0.2)
              : AppTheme.adaptiveDivier(isDark).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: isSynced ? AppTheme.successColor : AppTheme.adaptiveSubtext(isDark),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isSynced ? 'Đã đồng bộ' : 'Chưa đồng bộ',
            style: TextStyle(
              color: isSynced ? AppTheme.successColor : AppTheme.adaptiveSubtext(isDark),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSync(BuildContext context, TripController tripController, Trip trip) async {
    debugPrint('Sync button pressed for trip: ${trip.id}');
    HapticFeedback.mediumImpact();
    try {
      final success = await tripController.syncTripToCloud(trip.id);
      debugPrint('Sync result: $success');
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Đã tải lên drive thành công cho: ${trip.title}')),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else if (!success && mounted) {
        final error = tripController.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đồng bộ thất bại: $error'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during sync call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi hệ thống: $e'), backgroundColor: AppTheme.accentColor),
        );
      }
    }
  }

  Widget _buildActiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(UIConsts.radiusFull),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.successColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Đang đi',
            style: TextStyle(
              color: AppTheme.successColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTimeline(Trip trip, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(UIConsts.spacingMD),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(UIConsts.radiusLG),
      ),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.circle,
            iconColor: AppTheme.primaryColor,
            label: 'Điểm bắt đầu',
            address: trip.startAddress ?? '${trip.startLat.toStringAsFixed(4)}, ${trip.startLng.toStringAsFixed(4)}',
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Container(
              width: 1.5,
              height: 16,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          _buildLocationRow(
            icon: Icons.location_on_rounded,
            iconColor: AppTheme.secondaryColor,
            label: 'Điểm kết thúc',
            address: trip.endAddress ?? '${trip.endLat.toStringAsFixed(4)}, ${trip.endLng.toStringAsFixed(4)}',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.adaptiveSubtext(isDark),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                address,
                style: TextStyle(
                  color: AppTheme.adaptiveText(isDark).withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConsts.radiusMD),
        border: Border.all(color: color.withOpacity(0.2)),
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaStrip(List<MediaFile> media, bool isDark) {
    final displayMedia = media.take(5).toList();

    return Container(
      height: 80,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: UIConsts.spacingXL),
      margin: const EdgeInsets.only(bottom: UIConsts.spacingXL),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: displayMedia.length,
        separatorBuilder: (_, __) => const SizedBox(width: UIConsts.spacingSM),
        itemBuilder: (context, index) {
          final m = displayMedia[index];
          final isLast = index == 4 && media.length > 5;
          final remainingCount = media.length - 5;

          return Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(UIConsts.radiusLG),
                  border: Border.all(
                    color: AppTheme.adaptiveOutline(isDark).withOpacity(0.2),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(UIConsts.radiusLG - 1),
                  child: m.type == MediaType.image
                      ? (File(m.filePath).existsSync()
                          ? Image.file(
                              File(m.filePath),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: isDark ? AppTheme.surfaceDark : AppTheme.cardLight,
                              child: Icon(Icons.image_not_supported_rounded, 
                                  color: AppTheme.adaptiveSubtext(isDark), size: 20),
                            ))
                      : Container(
                          color: isDark ? AppTheme.surfaceDark : AppTheme.cardLight,
                          child: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: AppTheme.secondaryColor,
                            size: 32,
                          ),
                        ),
                ),
              ),
              if (isLast)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(UIConsts.radiusLG),
                    ),
                    child: Center(
                      child: Text(
                        '+$remainingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
    );
  }

  Widget _buildFAB(bool isDark) {
    return Container(
      decoration: AppTheme.gradientButtonDecoration(
        gradient: AppTheme.primaryGradient,
        isDark: isDark,
      ),
      child: FloatingActionButton.extended(
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
            if (mounted) {
              context.read<TripController>().loadTrips();
            }
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        label: const Text(
          'Hành Trình Mới',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
