import 'dart:ui';
import 'package:flutter/material.dart';

import '../controllers/flow_controller.dart';
import '../widgets/flow_painter.dart';

class FlowScreen extends StatefulWidget {
  const FlowScreen({Key? key}) : super(key: key);

  @override
  _FlowScreenState createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  final FlowController _controller = FlowController();
  bool _isDebugMode = false;

  @override
  void initState() {
    super.initState();
    // Chúng ta không cần lắng nghe controller.addListener nữa vì đã dùng ValueNotifier
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. CHƯƠNG TRÌNH PHÁT VIDEO / CAMERA (Dùng ValueListenableBuilder để chỉ rebuild khu vực này)
          ValueListenableBuilder(
            valueListenable: _controller.frameNotifier,
            builder: (context, bytes, child) {
              return _buildVideoBackground(bytes);
            },
          ),

          // 2. HUD - LA BÀN AR
          ValueListenableBuilder(
            valueListenable: _controller.headingNotifier,
            builder: (context, heading, child) {
              if (_controller.frameNotifier.value == null) return const SizedBox.shrink();
              return _buildAROverlay(heading);
            },
          ),

          // 3. THANH TRẠNG THÁI PHÍA TRÊN
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: _buildTopStatusPanel(),
          ),

          // 4. BẢNG ĐIỀU KHIỂN PHÍA DƯỚI
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: _buildBottomControlPanel(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBackground(var bytes) {
    if (bytes != null && _controller.imageSize != Size.zero) {
      return Center(
        child: RepaintBoundary(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _controller.imageSize.width,
              height: _controller.imageSize.height,
              child: Stack(
                children: [
                  Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                  ),
                  CustomPaint(
                    painter: FlowPainter(
                      points: _controller.pointsToDraw,
                      imageSize: _controller.imageSize,
                      staticRois: _controller.staticRois,
                      aiObstacles: _controller.aiObstacles, // Dùng aiObstacles thay vì forbiddenZones để vẽ khung đỏ
                      isDebugMode: _isDebugMode,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 64),
          ),
          const SizedBox(height: 24),
          const Text(
            "Ready to Stream",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 1.1),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _controller.pickAndPlayVideo,
            icon: const Icon(Icons.add_to_photos_rounded),
            label: const Text("CHỌN NGUỒN VIDEO"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withOpacity(0.8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAROverlay(double heading) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Dùng Positioned để neo la bàn xuống góc dưới cùng bên phải,
          // ngay phía trên bảng điều khiển.
          Positioned(
            bottom: 150, // Điều chỉnh độ cao so với đáy màn hình
            right: 24,   // Cách mép phải 24px
            child: Opacity(
              opacity: 0.6, // Tăng độ nét lên một chút vì la bàn đã nhỏ lại
              child: AnimatedRotation(
                turns: heading / 360.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 100, // Thu nhỏ kích thước từ 200 xuống 100
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.3), // Thêm nền mờ để nổi bật mũi tên
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Mũi tên đỏ chỉ hướng
                      const Icon(Icons.navigation_rounded, color: Colors.redAccent, size: 50),

                      // Vẽ 4 vạch đánh dấu (Bắc, Nam, Đông, Tây)
                      ...List.generate(4, (index) {
                        return Transform.rotate(
                          angle: (index * 90) * 3.14159 / 180,
                          child: const Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: SizedBox(
                                  height: 8,
                                  width: 2,
                                  child: DecoratedBox(decoration: BoxDecoration(color: Colors.white54))
                              ),
                            ),
                          ),
                        );
                      }),
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

  Widget _buildTopStatusPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              ValueListenableBuilder(
                valueListenable: _controller.speedNotifier,
                builder: (context, speed, child) {
                  return _buildStatItem(
                    label: "TỐC ĐỘ",
                    value: _controller.isDemoMode ? "DEMO" : "${(speed * 3.6).toStringAsFixed(0)}",
                    unit: "KM/H",
                    color: Colors.white,
                  );
                },
              ),
              const Spacer(),
              Container(width: 1, height: 40, color: Colors.white10),
              const Spacer(),
              ValueListenableBuilder(
                valueListenable: _controller.headingNotifier,
                builder: (context, heading, child) {
                  return _buildStatItem(
                    label: "HƯỚNG",
                    value: "${heading.toStringAsFixed(0)}°",
                    unit: _getDirectionString(heading),
                    color: Colors.cyanAccent,
                  );
                },
              ),
              const Spacer(),
              Container(width: 1, height: 40, color: Colors.white10),
              const Spacer(),
              _buildSystemIndicators(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({required String label, required String value, required String unit, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemIndicators() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                _indicatorIcon(
                  icon: Icons.satellite_alt_rounded,
                  isActive: _controller.hasValidGps,
                  activeColor: Colors.greenAccent,
                ),
                const SizedBox(width: 12),
                _controller.isModelLoaded
                    ? _indicatorIcon(icon: Icons.psychology_rounded, isActive: true, activeColor: Colors.cyanAccent)
                    : const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _controller.isModelLoaded ? "AI ACTIVE" : "AI LOADING",
              style: TextStyle(
                color: _controller.isModelLoaded ? Colors.cyanAccent.withOpacity(0.7) : Colors.orangeAccent.withOpacity(0.7),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _indicatorIcon({required IconData icon, required bool isActive, required Color activeColor}) {
    return Icon(icon, color: isActive ? activeColor : Colors.white24, size: 20);
  }

  Widget _buildBottomControlPanel(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder(
          valueListenable: _controller.progressNotifier,
          builder: (context, progress, child) {
            return _buildProgressBar(progress);
          },
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleIconButton(
                        icon: Icons.folder_copy_rounded,
                        onPressed: _controller.pickAndPlayVideo,
                      ),
                      _circleIconButton(
                        icon: _isDebugMode ? Icons.grid_view_rounded : Icons.grid_view_outlined,
                        color: _isDebugMode ? Colors.cyanAccent : Colors.white70,
                        onPressed: () => setState(() => _isDebugMode = !_isDebugMode),
                      ),
                      _buildPlayButton(),
                      _buildSpeedToggle(),
                      _circleIconButton(
                        icon: Icons.refresh_rounded,
                        onPressed: _controller.resetTracking,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_controller.formatTime(progress, _controller.fps), style: const TextStyle(color: Colors.white38, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
              Text(_controller.formatTime(_controller.totalFrames, _controller.fps), style: const TextStyle(color: Colors.white38, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: progress.clamp(0.0, _controller.totalFrames > 0 ? _controller.totalFrames : 1.0),
              min: 0.0,
              max: _controller.totalFrames > 0 ? _controller.totalFrames : 1.0,
              onChanged: (val) {
                _controller.progressNotifier.value = val;
                _controller.seekTo(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _controller.togglePause,
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
          ],
        ),
        child: Icon(
          _controller.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          color: Colors.black,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildSpeedToggle() {
    return GestureDetector(
      onTap: _controller.isPlaying ? _controller.cycleSpeed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          "${_controller.playbackSpeed}x",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onPressed, Color color = Colors.white70}) {
    return IconButton(
      icon: Icon(icon),
      color: color,
      iconSize: 24,
      onPressed: onPressed,
      splashRadius: 24,
    );
  }

  String _getDirectionString(double heading) {
    if (heading >= 337.5 || heading < 22.5) return "NORTH";
    if (heading >= 22.5 && heading < 67.5) return "NE";
    if (heading >= 67.5 && heading < 112.5) return "EAST";
    if (heading >= 112.5 && heading < 157.5) return "SE";
    if (heading >= 157.5 && heading < 202.5) return "SOUTH";
    if (heading >= 202.5 && heading < 247.5) return "SW";
    if (heading >= 247.5 && heading < 292.5) return "WEST";
    if (heading >= 292.5 && heading < 337.5) return "NW";
    return "N/A";
  }
}
