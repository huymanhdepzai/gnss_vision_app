import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlowPainter extends CustomPainter {
  final List<Offset> points;
  final Size imageSize;
  final List<Rect>? staticRois;
  final List<Rect>? aiObstacles;
  final bool isDebugMode;
  final double? confidence;
  final Offset? moveVector;

  FlowPainter({
    required this.points,
    required this.imageSize,
    this.staticRois,
    this.aiObstacles,
    this.isDebugMode = false,
    this.confidence,
    this.moveVector,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    _drawDebugGrid(canvas, size, scaleX, scaleY);
    _drawObstacles(canvas, size, scaleX, scaleY);
    _drawTrackingPoints(canvas, size, scaleX, scaleY);
    _drawMotionVector(canvas, size, scaleX, scaleY);
    _drawConfidenceIndicator(canvas, size);
  }

  void _drawDebugGrid(Canvas canvas, Size size, double scaleX, double scaleY) {
    if (!isDebugMode || staticRois == null) return;

    final hudPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var roi in staticRois!) {
      Rect scaledRoi = Rect.fromLTRB(
        roi.left * scaleX,
        roi.top * scaleY,
        roi.right * scaleX,
        roi.bottom * scaleY,
      );
      canvas.drawRect(scaledRoi, hudPaint);

      final centerHud = scaledRoi.center;
      canvas.drawLine(
        Offset(centerHud.dx - 10, centerHud.dy),
        Offset(centerHud.dx + 10, centerHud.dy),
        hudPaint,
      );
      canvas.drawLine(
        Offset(centerHud.dx, centerHud.dy - 10),
        Offset(centerHud.dx, centerHud.dy + 10),
        hudPaint,
      );
    }
  }

  void _drawObstacles(Canvas canvas, Size size, double scaleX, double scaleY) {
    if (aiObstacles == null || aiObstacles!.isEmpty) return;

    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = Colors.red.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    for (var box in aiObstacles!) {
      // Check if coordinates are normalized (0-1) or pixel-based
      double left = box.left;
      double top = box.top;
      double right = box.right;
      double bottom = box.bottom;

      if (left < 1.1 && right < 1.1 && top < 1.1 && bottom < 1.1) {
        // Assume normalized, scale to image size
        left *= imageSize.width;
        top *= imageSize.height;
        right *= imageSize.width;
        bottom *= imageSize.height;
      }

      Rect scaledBox = Rect.fromLTRB(
        left * scaleX,
        top * scaleY,
        right * scaleX,
        bottom * scaleY,
      );

      // Draw shadow/glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledBox, const Radius.circular(8)),
        Paint()
          ..color = Colors.red.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Draw main box
      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledBox, const Radius.circular(8)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledBox, const Radius.circular(8)),
        borderPaint,
      );

      // Draw bold corners
      _drawBoldCorners(canvas, scaledBox);
    }
  }

  void _drawBoldCorners(Canvas canvas, Rect rect) {
    final cornerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final len = (rect.width * 0.2).clamp(10.0, 30.0);
    
    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top + len), Offset(rect.left, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + len, rect.top), cornerPaint);
    
    // Top-Right
    canvas.drawLine(Offset(rect.right - len, rect.top), Offset(rect.right, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + len), cornerPaint);
    
    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom - len), Offset(rect.left, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + len, rect.bottom), cornerPaint);
    
    // Bottom-Right
    canvas.drawLine(Offset(rect.right - len, rect.bottom), Offset(rect.right, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - len), cornerPaint);
  }

  void _drawTrackingPoints(
    Canvas canvas,
    Size size,
    double scaleX,
    double scaleY,
  ) {
    if (!isDebugMode || points.isEmpty) return;

    final pointPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    for (var point in points) {
      double mappedX = point.dx * scaleX;
      double mappedY = point.dy * scaleY;

      final glowPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(Offset(mappedX, mappedY), 5, glowPaint);
      canvas.drawCircle(Offset(mappedX, mappedY), 2, pointPaint);
    }
  }

  void _drawMotionVector(
    Canvas canvas,
    Size size,
    double scaleX,
    double scaleY,
  ) {
    if (moveVector == null || !isDebugMode) return;

    final magnitude = moveVector!.distance;
    if (magnitude < 0.5) return;

    final center = Offset(size.width / 2, size.height / 2);
    final scaledVector = Offset(
      moveVector!.dx * scaleX * 10,
      moveVector!.dy * scaleY * 10,
    );
    final endPoint = Offset(
      center.dx + scaledVector.dx,
      center.dy + scaledVector.dy,
    );

    final arrowPaint = Paint()
      ..color = Colors.cyan.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, endPoint, arrowPaint);

    final angle = math.atan2(scaledVector.dy, scaledVector.dx);
    final arrowSize = 10.0;

    final path = Path();
    path.moveTo(endPoint.dx, endPoint.dy);
    path.lineTo(
      endPoint.dx - arrowSize * math.cos(angle - math.pi / 6),
      endPoint.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    path.moveTo(endPoint.dx, endPoint.dy);
    path.lineTo(
      endPoint.dx - arrowSize * math.cos(angle + math.pi / 6),
      endPoint.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    canvas.drawPath(path, arrowPaint);
  }

  void _drawConfidenceIndicator(Canvas canvas, Size size) {
    if (confidence == null || !isDebugMode) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Conf: ${(confidence! * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: confidence! > 0.7
              ? Colors.green.shade400
              : confidence! > 0.4
              ? Colors.orange.shade400
              : Colors.red.shade400,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(10, size.height - 30));
  }

  @override
  bool shouldRepaint(covariant FlowPainter oldDelegate) {
    return true;
  }
}

class DirectionArrowPainter extends CustomPainter {
  final double heading;
  final double turnIntensity;
  final double confidence;
  final bool showPath;
  final Color primaryColor;
  final Color accentColor;

  DirectionArrowPainter({
    required this.heading,
    this.turnIntensity = 0,
    this.confidence = 1.0,
    this.showPath = true,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    _drawFuturisticGlow(canvas, center, radius);
    _drawMainArrow(canvas, center, radius);
    if (showPath && turnIntensity.abs() > 0.05) {
      _drawDynamicPath(canvas, center, radius);
    }
  }

  void _drawFuturisticGlow(Canvas canvas, Offset center, double radius) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withOpacity(0.2),
          primaryColor.withOpacity(0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, glowPaint);
  }

  void _drawMainArrow(Canvas canvas, Offset center, double radius) {
    final arrowPath = Path();
    final arrowSize = radius * 0.8;
    final arrowWidth = arrowSize * 0.4;

    // Bold, sleek arrow shape
    arrowPath.moveTo(0, -arrowSize);
    arrowPath.lineTo(arrowWidth, arrowSize * 0.2);
    arrowPath.lineTo(0, 0); // Inner notch
    arrowPath.lineTo(-arrowWidth, arrowSize * 0.2);
    arrowPath.close();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    
    // Smoothly rotate based on heading and add a slight tilt for "3D" effect
    canvas.rotate(heading * math.pi / 180);

    // Outer Glow for the arrow
    final arrowGlow = Paint()
      ..color = accentColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(arrowPath, arrowGlow);

    // Gradient Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accentColor, primaryColor],
      ).createShader(Rect.fromLTWH(-arrowWidth, -arrowSize, arrowWidth * 2, arrowSize));
    
    canvas.drawPath(arrowPath, fillPaint);

    // Strong Border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(arrowPath, borderPaint);

    canvas.restore();
  }

  void _drawDynamicPath(Canvas canvas, Offset center, double radius) {
    final pathPaint = Paint()
      ..color = turnIntensity.abs() > 0.4 ? Colors.orangeAccent : accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.6);
    final sweepAngle = (turnIntensity * 90) * math.pi / 180;
    
    // Draw a bold arc representing the turn direction
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweepAngle,
      false,
      pathPaint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweepAngle,
      false,
      pathPaint..maskFilter = null,
    );
  }

  @override
  bool shouldRepaint(covariant DirectionArrowPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.turnIntensity != turnIntensity;
  }
}
