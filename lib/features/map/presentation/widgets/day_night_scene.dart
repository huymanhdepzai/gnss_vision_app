import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import '../../../../core/app_theme.dart';

class DayNightInteractiveScene extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  const DayNightInteractiveScene({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<DayNightInteractiveScene> createState() => _DayNightInteractiveSceneState();
}

class _DayNightInteractiveSceneState extends State<DayNightInteractiveScene> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _continuousController;
  double _dragValue = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: widget.isDark ? 1.0 : 0.0,
    );
    _dragValue = _controller.value;

    _continuousController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _controller.addListener(() {
      setState(() {
        _dragValue = _controller.value;
      });
    });
  }

  @override
  void didUpdateWidget(DayNightInteractiveScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      if (!_isDragging) {
        _controller.stop();
        _controller.animateTo(widget.isDark ? 1.0 : 0.0, curve: Curves.easeInOutCubic);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _continuousController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragValue = _controller.value;
    });
    _controller.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta! / 300.0; // Normalized width
    setState(() {
      _dragValue = (_dragValue + delta).clamp(0.0, 1.0);
    });
    _controller.value = _dragValue;
    
    // Check threshold during drag
    if (_dragValue >= 0.5 && !widget.isDark) {
      widget.onThemeChanged(true);
    } else if (_dragValue < 0.5 && widget.isDark) {
      widget.onThemeChanged(false);
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    
    final velocity = details.primaryVelocity! / 300.0;
    if (velocity.abs() > 0.5) {
      final simulation = FrictionSimulation(0.1, _controller.value, velocity);
      _controller.animateWith(simulation).then((_) {
        _snapToEdge();
      });
    } else {
      _snapToEdge();
    }
  }

  void _snapToEdge() {
    if (_controller.value > 0.5) {
      if (!widget.isDark) widget.onThemeChanged(true);
      _controller.animateTo(1.0, curve: Curves.easeOutBack);
    } else {
      if (widget.isDark) widget.onThemeChanged(false);
      _controller.animateTo(0.0, curve: Curves.easeOutBack);
    }
  }

  void _toggleTheme() {
    if (_controller.isAnimating) return;
    HapticFeedback.lightImpact();
    widget.onThemeChanged(!widget.isDark);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _dragValue;
    final hintText = progress == 0.0 
        ? "Chạm hoặc vuốt để bắt đầu chu kỳ đêm" 
        : progress == 1.0 
            ? "Đang ở chế độ Đêm – vuốt ngược lại để đổi" 
            : "Thời gian: ${(progress * 100).toInt()}%";

    return Column(
      children: [
        GestureDetector(
          onTap: _toggleTheme,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedBuilder(
                    animation: _continuousController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size.infinite,
                        painter: DayNightPainter(progress: progress),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // const SizedBox(height: 16),
        // // Improved Slider Control
        // //
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? color : Colors.grey.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

class DayNightPainter extends CustomPainter {
  final double progress;

  DayNightPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final sunMoonPos = _getSunMoonPosition(size);
    _drawSky(canvas, size);
    _drawStars(canvas, size);
    _drawGodRays(canvas, size, sunMoonPos);
    _drawClouds(canvas, size);
    _drawSunMoon(canvas, size, sunMoonPos);
    _drawBirds(canvas, size);
    _drawWater(canvas, size);
  }

  Offset _getSunMoonPosition(Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.55;
    final radiusX = size.width * 0.4;
    final radiusY = size.height * 0.3;
    final angle = math.pi + (progress * math.pi);
    return Offset(
      centerX + radiusX * math.cos(angle),
      centerY + radiusY * math.sin(angle),
    );
  }

  void _drawSky(Canvas canvas, Size size) {
    final dayColorTop = const Color(0xFF4FC3F7);
    final dayColorBottom = const Color(0xFFE1F5FE);
    final nightColorTop = const Color(0xFF0D47A1);
    final nightColorBottom = const Color(0xFF000511);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(dayColorTop, nightColorTop, progress)!,
        Color.lerp(dayColorBottom, nightColorBottom, progress)!,
      ],
    );

    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  void _drawStars(Canvas canvas, Size size) {
    if (progress < 0.1) return;

    final random = math.Random(42);
    final starPaint = Paint()..color = Colors.white;

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * (size.height * 0.7);
      final radius = random.nextDouble() * 1.5;
      
      // Parallax effect
      final offsetX = (progress - 0.5) * 20 * (radius / 1.5);
      
      final opacity = (progress * random.nextDouble()).clamp(0.0, 1.0);
      starPaint.color = Colors.white.withOpacity(opacity);
      
      canvas.drawCircle(Offset(x + offsetX, y), radius, starPaint);
    }
  }

  void _drawGodRays(Canvas canvas, Size size, Offset sunPos) {
    if (progress > 0.4) return;

    final opacity = (1.0 - progress / 0.4).clamp(0.0, 1.0);
    final rayPaint = Paint()
      ..color = Colors.white.withOpacity(0.15 * opacity)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 + progress * 50) * math.pi / 180;
      final path = Path()
        ..moveTo(sunPos.dx, sunPos.dy)
        ..relativeLineTo(math.cos(angle - 0.1) * 200, math.sin(angle - 0.1) * 200)
        ..relativeLineTo(math.cos(angle + 0.1) * 10, math.sin(angle + 0.1) * 10)
        ..close();
      
      canvas.drawPath(path, rayPaint);
    }
  }

  void _drawClouds(Canvas canvas, Size size) {
    final random = math.Random(123);
    
    for (int i = 0; i < 5; i++) {
      final speed = random.nextDouble() * 15 + 8;
      final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final x = (random.nextDouble() * size.width + (time * speed)) % (size.width + 200) - 100;
      final y = random.nextDouble() * size.height * 0.35 + 15;
      final scale = random.nextDouble() * 0.6 + 0.7;
      final opacity = (0.7 * (1 - progress * 0.4)).clamp(0.1, 0.7);

      _drawSingleRealisticCloud(canvas, Offset(x, y), scale, opacity, progress);
    }
  }

  void _drawSingleRealisticCloud(Canvas canvas, Offset center, double scale, double opacity, double progress) {
    final cloudColor = Color.lerp(Colors.white, const Color(0xFFB0BEC5), progress)!;
    final shadowColor = Color.lerp(const Color(0xFFE1F5FE), const Color(0xFF263238), progress)!;

    final paint = Paint()
      ..color = cloudColor.withOpacity(opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale);

    // Main cloud body (organic cluster)
    final path = Path();
    _addCloudPuff(path, center, 25 * scale);
    _addCloudPuff(path, center + Offset(20 * scale, 5 * scale), 20 * scale);
    _addCloudPuff(path, center + Offset(-18 * scale, 8 * scale), 18 * scale);
    _addCloudPuff(path, center + Offset(35 * scale, 12 * scale), 15 * scale);
    _addCloudPuff(path, center + Offset(-5 * scale, -10 * scale), 15 * scale);

    // Draw shadow/depth layer
    final shadowPaint = Paint()
      ..color = shadowColor.withOpacity(opacity * 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * scale);
    canvas.drawPath(path.shift(Offset(0, 5 * scale)), shadowPaint);

    // Draw main body
    canvas.drawPath(path, paint);

    // Highlights (sun/moon light)
    final highlightColor = progress < 0.5 ? Colors.white : const Color(0xFFE1F5FE);
    final highlightPaint = Paint()
      ..color = highlightColor.withOpacity(opacity * 0.8)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale);
    
    final highlightPath = Path();
    _addCloudPuff(highlightPath, center + Offset(-5 * scale, -5 * scale), 12 * scale);
    _addCloudPuff(highlightPath, center + Offset(15 * scale, -2 * scale), 10 * scale);
    canvas.drawPath(highlightPath, highlightPaint);
  }

  void _addCloudPuff(Path path, Offset center, double radius) {
    path.addOval(Rect.fromCircle(center: center, radius: radius));
  }

  void _drawSunMoon(Canvas canvas, Size size, Offset pos) {
    if (progress < 0.5) {
      // Draw Sun
      final sunPaint = Paint()
        ..color = Colors.orangeAccent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(pos, 20, sunPaint);
      canvas.drawCircle(pos, 15, Paint()..color = Colors.yellow);
    } else {
      // Draw Moon Glow
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(pos, 20, glowPaint);

      // Draw Crescent Moon using Path operation
      final moonPath = Path()..addOval(Rect.fromCircle(center: pos, radius: 15));
      final cutPath = Path()..addOval(Rect.fromCircle(center: Offset(pos.dx - 6, pos.dy - 6), radius: 14));
      
      final crescentPath = Path.combine(PathOperation.difference, moonPath, cutPath);
      
      final moonPaint = Paint()
        ..color = const Color(0xFFF5F5F5); // Slightly off-white for moon
        
      canvas.drawPath(crescentPath, moonPaint);
    }
  }

  void _drawBirds(Canvas canvas, Size size) {
    if (progress > 0.6) return;
    
    final opacity = (1.0 - (progress - 0.2) / 0.4).clamp(0.0, 1.0);
    final birdPaint = Paint()
      ..color = Colors.black.withOpacity(0.3 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final t = (DateTime.now().millisecondsSinceEpoch / 1000.0) + i;
      final x = (size.width * 0.7) + math.sin(t) * 20;
      final y = (size.height * 0.2) + i * 15 + math.cos(t) * 5;
      
      final wingSpread = 5.0 + math.sin(t * 10) * 3;
      
      final path = Path()
        ..moveTo(x - wingSpread, y - 2)
        ..quadraticBezierTo(x, y + 2, x + wingSpread, y - 2);
      
      canvas.drawPath(path, birdPaint);
    }
  }

  void _drawWater(Canvas canvas, Size size) {
    final waterHeight = size.height * 0.3;
    final waterRect = Rect.fromLTWH(0, size.height - waterHeight, size.width, waterHeight);
    
    final waterColorDay = const Color(0xFF0288D1).withOpacity(0.6);
    final waterColorNight = const Color(0xFF001021).withOpacity(0.9);
    
    final paint = Paint()
      ..color = Color.lerp(waterColorDay, waterColorNight, progress)!;
    
    canvas.drawRect(waterRect, paint);

    // Reflections
    final reflectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.1 + (progress * 0.1))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    for (int i = 0; i < 10; i++) {
      final t = (DateTime.now().millisecondsSinceEpoch / 2000.0) + i;
      final x = (size.width * (i / 10.0)) + math.sin(t) * 10;
      final y = size.height - waterHeight + (i * 3) + 5;
      final w = 20.0 + math.sin(t * 2) * 10;
      
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: 2), reflectionPaint);
    }
    
    // Gradient overlay for depth
    final depthGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black.withOpacity(0.3 * progress)],
    );
    canvas.drawRect(waterRect, Paint()..shader = depthGradient.createShader(waterRect));
  }

  @override
  bool shouldRepaint(covariant DayNightPainter oldDelegate) => true;
}
