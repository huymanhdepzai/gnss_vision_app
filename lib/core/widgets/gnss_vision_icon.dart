import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

class GnssVisionIcon extends StatelessWidget {
  final double size;
  final bool showOrbits;
  final bool showSatellites;
  final bool showGlow;
  final double orbitAngleOffset;
  final Color? primaryColor;
  final Color? secondaryColor;

  const GnssVisionIcon({
    super.key,
    this.size = 120,
    this.showOrbits = true,
    this.showSatellites = true,
    this.showGlow = true,
    this.orbitAngleOffset = 0,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GnssVisionIconPainter(
        showOrbits: showOrbits,
        showSatellites: showSatellites,
        showGlow: showGlow,
        orbitAngleOffset: orbitAngleOffset,
        primaryColor: primaryColor ?? AppTheme.primaryColor,
        secondaryColor: secondaryColor ?? AppTheme.secondaryColor,
      ),
    );
  }
}

class _GnssVisionIconPainter extends CustomPainter {
  final bool showOrbits;
  final bool showSatellites;
  final bool showGlow;
  final double orbitAngleOffset;
  final Color primaryColor;
  final Color secondaryColor;

  _GnssVisionIconPainter({
    required this.showOrbits,
    required this.showSatellites,
    required this.showGlow,
    required this.orbitAngleOffset,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final s = size.width / 1024;

    final pinHeadCenterY = 370 * s;
    final pinHeadRadius = 172 * s;
    final pinPointY = 710 * s;
    final orbitRx = 215 * s;
    final orbitRy = 68 * s;

    _drawAmbientGlow(canvas, size, s, cx);
    _drawOrbitalRings(canvas, size, s, cx, pinHeadCenterY, orbitRx, orbitRy);
    _drawPin(canvas, size, s, cx, pinHeadCenterY, pinHeadRadius, pinPointY);
    _drawCompassIcon(canvas, size, s, cx, pinHeadCenterY);
    _drawOrbitalRingFront(canvas, size, s, cx, pinHeadCenterY, orbitRx, orbitRy);
    if (showSatellites) {
      _drawSatelliteDots(canvas, size, s, cx, pinHeadCenterY, orbitRx, orbitRy);
    }
  }

  void _drawAmbientGlow(Canvas canvas, Size size, double s, double cx) {
    if (!showGlow) return;
    final centerGlowY = 370 * s;
    final glowRadius = 350 * s;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.15),
          secondaryColor.withOpacity(0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(cx, centerGlowY),
        radius: glowRadius,
      ));

    canvas.drawCircle(Offset(cx, centerGlowY), glowRadius, paint);
  }

  void _drawOrbitalRings(
    Canvas canvas, Size size, double s, double cx,
    double centerY, double rx, double ry,
  ) {
    if (!showOrbits) return;

    final ring3Paint = Paint()
      ..color = const Color(0xFF67E8F9).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s;

    canvas.save();
    canvas.translate(cx, centerY);
    canvas.rotate((-60 + orbitAngleOffset * 30) * pi / 180);
    canvas.translate(-cx, -centerY);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, centerY), width: rx * 2, height: ry * 2), ring3Paint);
    canvas.restore();

    final ring2Paint = Paint()
      ..color = const Color(0xFF9B8AFF).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8 * s;

    canvas.save();
    canvas.translate(cx, centerY);
    canvas.rotate((60 + orbitAngleOffset * 20) * pi / 180);
    canvas.translate(-cx, -centerY);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, centerY), width: rx * 2, height: ry * 2), ring2Paint);
    canvas.restore();
  }

  void _drawPin(
    Canvas canvas, Size size, double s, double cx,
    double centerY, double radius, double pointY,
  ) {
    final path = _createPinPath(cx, centerY, radius, pointY, s);

    if (showGlow) {
      canvas.drawShadow(path, primaryColor.withOpacity(0.4), 16 * s, true);
    }

    final rect = Rect.fromCircle(center: Offset(cx, centerY), radius: radius);
    final gradient = RadialGradient(
      center: const Alignment(-0.15, -0.3),
      radius: 0.65,
      colors: [
        const Color(0xFF9B8AFF),
        primaryColor,
        secondaryColor,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s;
    canvas.drawCircle(Offset(cx, centerY + 3 * s), 105 * s, highlightPaint);

    final innerGlow = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, centerY - 20 * s), 60 * s, innerGlow);
  }

  Path _createPinPath(double cx, double centerY, double radius, double pointY, double s) {
    final leftX = cx - radius;
    final rightX = cx + radius;

    final cp1x = cx - 34 * s;
    final cp1y = 650 * s;
    final cp2x = leftX;
    final cp2y = centerY + 135 * s;

    final cp3x = rightX;
    final cp3y = centerY + 135 * s;
    final cp4x = cx + 34 * s;
    final cp4y = 650 * s;

    return Path()
      ..moveTo(cx, pointY)
      ..cubicTo(cp1x, cp1y, cp2x, cp2y, leftX, centerY)
      ..arcToPoint(
        Offset(rightX, centerY),
        radius: Radius.circular(radius),
        clockwise: true,
        largeArc: true,
      )
      ..cubicTo(cp3x, cp3y, cp4x, cp4y, cx, pointY)
      ..close();
  }

  void _drawCompassIcon(Canvas canvas, Size size, double s, double cx, double centerY) {
    final topY = centerY - 40 * s;
    final bottomY = centerY + 40 * s;
    final leftX = cx - 24 * s;
    final rightX = cx + 24 * s;

    final diamondPath = Path()
      ..moveTo(cx, topY)
      ..lineTo(rightX, centerY)
      ..lineTo(cx, bottomY)
      ..lineTo(leftX, centerY)
      ..close();

    canvas.drawShadow(diamondPath, const Color(0xFF22D3EE).withOpacity(0.3), 4 * s, true);

    final whitePaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(diamondPath, whitePaint);

    final northPath = Path()
      ..moveTo(cx, topY)
      ..lineTo(rightX, centerY)
      ..lineTo(cx, centerY)
      ..close();

    final cyanPaint = Paint()
      ..color = const Color(0xFF22D3EE).withOpacity(0.95)
      ..style = PaintingStyle.fill;
    canvas.drawPath(northPath, cyanPaint);

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, centerY), 5 * s, dotPaint);
  }

  void _drawOrbitalRingFront(
    Canvas canvas, Size size, double s, double cx,
    double centerY, double rx, double ry,
  ) {
    if (!showOrbits) return;

    final ring1Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          secondaryColor.withOpacity(0.3),
          secondaryColor,
          secondaryColor,
          secondaryColor.withOpacity(0.3),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(cx - rx, centerY),
        width: rx * 2,
        height: ry * 2,
      ))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, centerY), width: rx * 2, height: ry * 2),
      ring1Paint,
    );
  }

  void _drawSatelliteDots(
    Canvas canvas, Size size, double s, double cx,
    double centerY, double rx, double ry,
  ) {
    if (!showOrbits) return;

    _drawDot(canvas, cx + rx, centerY, 7 * s, 12 * s, secondaryColor, 0.95, 0.2);
    _drawDot(canvas, cx - rx, centerY, 7 * s, 12 * s, secondaryColor, 0.95, 0.2);

    final angle2 = (60 + orbitAngleOffset * 20) * pi / 180;
    _drawDot(canvas, cx + rx * cos(angle2), centerY + ry * sin(angle2), 5.5 * s, 10 * s, const Color(0xFF9B8AFF), 0.9, 0.15);
    _drawDot(canvas, cx + rx * cos(angle2 + pi), centerY + ry * sin(angle2 + pi), 5.5 * s, 10 * s, const Color(0xFF9B8AFF), 0.9, 0.15);

    final angle3 = (-60 + orbitAngleOffset * 30) * pi / 180;
    _drawDot(canvas, cx + rx * cos(angle3), centerY + ry * sin(angle3), 5 * s, 9 * s, const Color(0xFF67E8F9), 0.75, 0.12);
    _drawDot(canvas, cx + rx * cos(angle3 + pi), centerY + ry * sin(angle3 + pi), 5 * s, 9 * s, const Color(0xFF67E8F9), 0.75, 0.12);
  }

  void _drawDot(Canvas canvas, double x, double y, double innerR, double outerR, Color color, double innerOpacity, double outerOpacity) {
    final outerPaint = Paint()
      ..color = color.withOpacity(outerOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), outerR, outerPaint);

    final innerPaint = Paint()
      ..color = color.withOpacity(innerOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), innerR, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _GnssVisionIconPainter old) {
    return orbitAngleOffset != old.orbitAngleOffset ||
        primaryColor != old.primaryColor ||
        secondaryColor != old.secondaryColor ||
        showOrbits != old.showOrbits ||
        showSatellites != old.showSatellites ||
        showGlow != old.showGlow;
  }
}

class AnimatedGnssVisionIcon extends StatefulWidget {
  final double size;
  final bool showOrbits;
  final bool showSatellites;
  final bool showGlow;
  final Color? primaryColor;
  final Color? secondaryColor;

  const AnimatedGnssVisionIcon({
    super.key,
    this.size = 120,
    this.showOrbits = true,
    this.showSatellites = true,
    this.showGlow = true,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<AnimatedGnssVisionIcon> createState() => _AnimatedGnssVisionIconState();
}

class _AnimatedGnssVisionIconState extends State<AnimatedGnssVisionIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return GnssVisionIcon(
          size: widget.size,
          showOrbits: widget.showOrbits,
          showSatellites: widget.showSatellites,
          showGlow: widget.showGlow,
          orbitAngleOffset: _controller.value,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
        );
      },
    );
  }
}