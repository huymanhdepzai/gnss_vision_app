import 'dart:math' as math;
import 'package:flutter/material.dart';
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

class _DayNightInteractiveSceneState extends State<DayNightInteractiveScene> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
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

    _controller.addListener(() {
      setState(() {
        _dragValue = _controller.value;
      });
      
      // Update theme when threshold crossed
      if (_controller.value >= 0.5 && !widget.isDark) {
        widget.onThemeChanged(true);
      } else if (_controller.value < 0.5 && widget.isDark) {
        widget.onThemeChanged(false);
      }
    });
  }

  @override
  void didUpdateWidget(DayNightInteractiveScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark && !_isDragging) {
      _controller.animateTo(widget.isDark ? 1.0 : 0.0, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
      _controller.animateTo(1.0, curve: Curves.easeOutBack);
    } else {
      _controller.animateTo(0.0, curve: Curves.easeOutBack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _dragValue;
    final hintText = progress == 0.0 
        ? "Swipe to begin night cycle" 
        : progress == 1.0 
            ? "Full cycle – drag to fine-tune" 
            : "Du hành thời gian: ${(progress * 100).toInt()}%";

    return Column(
      children: [
        GestureDetector(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: DayNightPainter(progress: progress),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress < 0.5 ? "GIAO DIỆN NGÀY" : "GIAO DIỆN ĐÊM",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: progress < 0.5 ? AppTheme.primaryColor : AppTheme.secondaryColor,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                width: 100,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 100 * progress,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hintText,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class DayNightPainter extends CustomPainter {
  final double progress;

  DayNightPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawStars(canvas, size);
    _drawGodRays(canvas, size);
    _drawClouds(canvas, size);
    _drawSunMoon(canvas, size);
    _drawBirds(canvas, size);
    _drawWater(canvas, size);
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

  void _drawGodRays(Canvas canvas, Size size) {
    if (progress > 0.4) return;

    final opacity = (1.0 - progress / 0.4).clamp(0.0, 1.0);
    final rayPaint = Paint()
      ..color = Colors.white.withOpacity(0.15 * opacity)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width * 0.2, size.height * 0.3);
    
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 + progress * 50) * math.pi / 180;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..relativeLineTo(math.cos(angle - 0.1) * 200, math.sin(angle - 0.1) * 200)
        ..relativeLineTo(math.cos(angle + 0.1) * 10, math.sin(angle + 0.1) * 10)
        ..close();
      
      canvas.drawPath(path, rayPaint);
    }
  }

  void _drawClouds(Canvas canvas, Size size) {
    final random = math.Random(123);
    final cloudColor = Color.lerp(Colors.white, Colors.white24, progress)!;
    
    for (int i = 0; i < 5; i++) {
      final speed = random.nextDouble() * 20 + 10;
      final x = (random.nextDouble() * size.width + (DateTime.now().millisecondsSinceEpoch / 1000.0 * speed)) % (size.width + 100) - 50;
      final y = random.nextDouble() * size.height * 0.4 + 20;
      final scale = random.nextDouble() * 0.5 + 0.5;

      // Simple cloud shape
      final paint = Paint()..color = cloudColor.withOpacity(0.8 * (1 - progress * 0.5));
      canvas.drawCircle(Offset(x, y), 20 * scale, paint);
      canvas.drawCircle(Offset(x + 15 * scale, y + 5 * scale), 15 * scale, paint);
      canvas.drawCircle(Offset(x - 15 * scale, y + 5 * scale), 15 * scale, paint);
    }
  }

  void _drawSunMoon(Canvas canvas, Size size) {
    // Arc path for Sun/Moon
    final centerX = size.width / 2;
    final centerY = size.height * 0.8;
    final radius = size.width * 0.4;
    
    final angle = math.pi + (progress * math.pi);
    final x = centerX + radius * math.cos(angle);
    final y = centerY + radius * math.sin(angle);

    if (progress < 0.5) {
      // Draw Sun
      final sunPaint = Paint()
        ..color = Colors.orangeAccent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(x, y), 20, sunPaint);
      canvas.drawCircle(Offset(x, y), 15, Paint()..color = Colors.yellow);
    } else {
      // Draw Moon
      final moonPaint = Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(x, y), 18, moonPaint);
      canvas.drawCircle(Offset(x, y), 15, Paint()..color = const Color(0xFFE0E0E0));
      
      // Crescent effect
      canvas.drawCircle(Offset(x - 8, y - 5), 14, Paint()..color = Color.lerp(const Color(0xFF0D47A1), const Color(0xFF000511), (progress-0.5)*2)!);
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
