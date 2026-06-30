import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/utils/injection_container.dart';
import '../../../auth/domain/entities/saved_address_entity.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/map_home_bloc.dart';
import '../bloc/map_home_event.dart';
import '../bloc/map_home_state.dart';

class MapSearchPage extends StatefulWidget {
  const MapSearchPage({Key? key}) : super(key: key);

  @override
  State<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends State<MapSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<MapHomeBloc>().state;
    if (state.searchQuery.isNotEmpty && state.viewState == MapViewState.explore) {
      _searchController.text = state.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  Widget _buildSuggestionsPanel(
    BuildContext context, 
    bool isDark, 
    Color textColor, 
    Color subtextColor,
    SavedAddressEntity? homeAddress,
    SavedAddressEntity? workAddress,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Địa điểm yêu thích / Lối tắt
          Row(
            children: [
              if (homeAddress != null)
                Expanded(
                  child: _buildShortcutCard(
                    icon: Icons.home_rounded,
                    title: homeAddress.description,
                    subtitle: "Về nhà",
                    isDark: isDark,
                    color: Colors.blue,
                    onTap: () async {
                      Navigator.pop(context, {
                        'placeId': homeAddress.placeId,
                        'description': homeAddress.description,
                      });
                    },
                  ),
                ),
              if (homeAddress != null && workAddress != null)
                const SizedBox(width: 16),
              if (workAddress != null)
                Expanded(
                  child: _buildShortcutCard(
                    icon: Icons.work_rounded,
                    title: workAddress.description,
                    subtitle: "Đến nơi làm việc",
                    isDark: isDark,
                    color: Colors.orange,
                    onTap: () async {
                      Navigator.pop(context, {
                        'placeId': workAddress.placeId,
                        'description': workAddress.description,
                      });
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required bool isDark,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : color.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCategories(bool isDark, Color textColor) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildCategoryChip("Trạm xăng", Icons.local_gas_station_rounded, Colors.redAccent, isDark, textColor),
          const SizedBox(width: 8),
          _buildCategoryChip("Nhà hàng", Icons.restaurant_rounded, Colors.deepOrange, isDark, textColor),
          const SizedBox(width: 8),
          _buildCategoryChip("Cà phê", Icons.local_cafe_rounded, Colors.brown, isDark, textColor),
          const SizedBox(width: 8),
          _buildCategoryChip("Trạm sạc", Icons.ev_station_rounded, Colors.green, isDark, textColor),
          const SizedBox(width: 8),
          _buildCategoryChip("Khách sạn", Icons.hotel_rounded, Colors.indigo, isDark, textColor),
          const SizedBox(width: 8),
          _buildCategoryChip("ATM", Icons.atm_rounded, Colors.teal, isDark, textColor),
          const SizedBox(width: 8),
          _buildCategoryChip("Bệnh viện", Icons.local_hospital_rounded, Colors.red, isDark, textColor),
          const SizedBox(width: 8),
          _buildCategoryChip("Siêu thị", Icons.shopping_cart_rounded, Colors.purple, isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String title, IconData icon, Color color, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () {
        _searchController.text = title;
        context.read<MapHomeBloc>().add(MapHomeSearchChanged(title));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5);

    final authState = context.watch<AuthBloc>().state;
    final user = authState.maybeMap(
      authenticated: (s) => s.user,
      orElse: () => null,
    );
    final homeAddress = user?.homeAddress;
    final workAddress = user?.workAddress;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : AppTheme.primaryColor.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      context.read<MapHomeBloc>().add(const MapHomeClearSearch());
                      Navigator.pop(context);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : AppTheme.primaryColor.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back_ios_new_sharp, color: textColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (query) {
                        context.read<MapHomeBloc>().add(MapHomeSearchChanged(query));
                      },
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: "Nhập tên địa điểm...",
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
                  BlocBuilder<MapHomeBloc, MapHomeState>(
                    builder: (context, state) {
                      if (state.isSearching) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark ? AppTheme.secondaryColor : AppTheme.primaryColor),
                            ),
                          ),
                        );
                      } else if (_searchController.text.isNotEmpty) {
                        return GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            context.read<MapHomeBloc>().add(const MapHomeSearchChanged(''));
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.close_rounded, color: subtextColor, size: 20),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Danh mục nhanh (Scroll ngang)
            _buildQuickCategories(isDark, textColor),
            const SizedBox(height: 12),
            // Kết quả tìm kiếm
            Expanded(
              child: BlocBuilder<MapHomeBloc, MapHomeState>(
                builder: (context, state) {
                  if (state.searchResults.isEmpty && _searchController.text.isEmpty) {
                    if (homeAddress != null || workAddress != null) {
                      return _buildSuggestionsPanel(context, isDark, textColor, subtextColor, homeAddress, workAddress);
                    }
                    return const SizedBox.shrink();
                  } else if (state.searchResults.isEmpty && !state.isSearching) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.03) : AppTheme.primaryColor.withOpacity(0.04),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: isDark ? Colors.white24 : AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Không tìm thấy kết quả",
                            style: TextStyle(
                              color: textColor, 
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Hãy thử nhập một từ khóa khác",
                            style: TextStyle(
                              color: subtextColor, 
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    );
                  } else if (state.searchResults.isEmpty && state.isSearching) {
                    return const SizedBox.shrink();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
                    itemCount: state.searchResults.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(
                        height: 1,
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final place = state.searchResults[index];
                      final delay = (index * 40).clamp(0, 300);
                      
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + delay),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              Navigator.pop(context, {
                                'placeId': place.placeId,
                                'description': place.description,
                              });
                            },
                            highlightColor: isDark ? Colors.white.withOpacity(0.05) : AppTheme.primaryColor.withOpacity(0.05),
                            splashColor: isDark ? Colors.white.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isDark
                                            ? [AppTheme.primaryColor.withOpacity(0.2), AppTheme.secondaryColor.withOpacity(0.1)]
                                            : [AppTheme.primaryColor.withOpacity(0.15), AppTheme.secondaryColor.withOpacity(0.05)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? AppTheme.primaryColor.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.15),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                                        child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place.mainText ?? place.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: textColor,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        if ((place.secondaryText ?? '').isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            place.secondaryText!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: subtextColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (place.distance != null) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withOpacity(0.06) : AppTheme.primaryColor.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _formatDistance(place.distance!),
                                        style: TextStyle(
                                          color: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(width: 12),
                                    Icon(Icons.north_west_rounded, size: 18, color: subtextColor.withOpacity(0.4)),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
