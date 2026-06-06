import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../controllers/flow_controller.dart';

class FlowPainter extends CustomPainter {
  final List<Offset> points;
  final Size imageSize;
  final List<Rect>? staticRois;
  final List<DetectedObject>? aiObstacles;
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

    // --- Calculate Fit and Offset (BoxFit.contain logic) ---
    final double imageAspect = imageSize.width / imageSize.height;
    final double screenAspect = size.width / size.height;

    double drawWidth, drawHeight;
    double offsetX = 0, offsetY = 0;

    if (screenAspect > imageAspect) {
      drawHeight = size.height;
      drawWidth = drawHeight * imageAspect;
      offsetX = (size.width - drawWidth) / 2;
    } else {
      drawWidth = size.width;
      drawHeight = drawWidth / imageAspect;
      offsetY = (size.height - drawHeight) / 2;
    }

    final double scaleX = drawWidth / imageSize.width;
    final double scaleY = drawHeight / imageSize.height;

    // Save the global context to draw background elements later
    _drawDebugGrid(canvas, size, scaleX, scaleY, offsetX, offsetY);
    _drawObstacles(canvas, size, scaleX, scaleY, offsetX, offsetY);
    _drawTrackingPoints(canvas, size, scaleX, scaleY, offsetX, offsetY);
    _drawMotionVector(canvas, size, scaleX, scaleY, offsetX, offsetY);
    _drawConfidenceIndicator(canvas, size);
  }

  void _drawDebugGrid(Canvas canvas, Size size, double scaleX, double scaleY, double dx, double dy) {
    if (!isDebugMode || staticRois == null) return;

    final hudPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var roi in staticRois!) {
      Rect scaledRoi = Rect.fromLTRB(
        roi.left * scaleX + dx,
        roi.top * scaleY + dy,
        roi.right * scaleX + dx,
        roi.bottom * scaleY + dy,
      );
      canvas.drawRect(scaledRoi, hudPaint);
    }
  }

  void _drawObstacles(Canvas canvas, Size size, double scaleX, double scaleY, double dx, double dy) {
    if (aiObstacles == null || aiObstacles!.isEmpty) return;

    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = Colors.red.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    for (var obj in aiObstacles!) {
      final box = obj.rect;
      double left = box.left;
      double top = box.top;
      double right = box.right;
      double bottom = box.bottom;

      if (left < 1.1 && right < 1.1 && top < 1.1 && bottom < 1.1) {
        left *= imageSize.width;
        top *= imageSize.height;
        right *= imageSize.width;
        bottom *= imageSize.height;
      }

      Rect scaledBox = Rect.fromLTRB(
        left * scaleX + dx,
        top * scaleY + dy,
        right * scaleX + dx,
        bottom * scaleY + dy,
      );

      // Draw box with shadow and glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledBox, const Radius.circular(8)),
        Paint()
          ..color = Colors.red.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      canvas.drawRRect(RRect.fromRectAndRadius(scaledBox, const Radius.circular(8)), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(scaledBox, const Radius.circular(8)), borderPaint);

      _drawBoldCorners(canvas, scaledBox);
      _drawLabelToBackground(canvas, size, scaledBox, obj.label, dx, dy);
    }
  }

  void _drawLabelToBackground(Canvas canvas, Size screenSize, Rect box, String label, double dx, double dy) {
    final leaderPaint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    Offset start, end;
    bool isLeft = box.center.dx < screenSize.width / 2;
    bool isTop = box.center.dy < screenSize.height / 2;

    // --- Optimized Exit Direction (Exclude Bottom) ---
    if (isTop && dy > 30) {
      // Priority 1: Top Area for objects in the upper half
      start = Offset(box.center.dx, box.top);
      double targetY = dy / 2;
      double targetX = (box.center.dx).clamp(40.0, screenSize.width - 40.0);
      end = Offset(targetX, targetY);
    } else if (dx > 25) {
      // Priority 2: Left/Right Sides for everything else (or if Top is small)
      start = isLeft ? Offset(box.left, box.top) : Offset(box.right, box.top);
      double targetX = isLeft ? dx / 2 : screenSize.width - (dx / 2);
      double targetY = (box.top - 20).clamp(50.0, screenSize.height - 180.0); // Stay away from bottom controls
      end = Offset(targetX, targetY);
    } else {
      // Fallback: Default to Top-Sides, avoiding downward lines
      start = isLeft ? Offset(box.left, box.top) : Offset(box.right, box.top);
      end = isLeft ? Offset(box.left - 40, box.top - 30) : Offset(box.right + 40, box.top - 30);
    }

    // Draw a subtle "elbow" path for a tech look
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    canvas.drawPath(path, leaderPaint);
    
    // Tiny node at the start
    canvas.drawCircle(start, 2.5, Paint()..color = Colors.red.withOpacity(0.8));

    // --- Draw Label ---
    final textPainter = TextPainter(
      text: TextSpan(
        text: ' ${label.toUpperCase()} ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          backgroundColor: Colors.red,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    
    // Center label on the end point
    double drawX = isLeft ? end.dx : end.dx - textPainter.width;
    if (dx <= 30 && dy <= 30) { // Fallback for small background
       drawX = isLeft ? end.dx - textPainter.width : end.dx;
    }
    
    textPainter.paint(canvas, Offset(drawX, end.dy - textPainter.height / 2));
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
    double dx,
    double dy,
  ) {
    if (!isDebugMode || points.isEmpty) return;

    final pointPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    for (var point in points) {
      double mappedX = point.dx * scaleX + dx;
      double mappedY = point.dy * scaleY + dy;

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
    double dx,
    double dy,
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
