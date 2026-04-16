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

    for (var box in aiObstacles!) {
      Rect scaledBox = Rect.fromLTRB(
        box.left * scaleX,
        box.top * scaleY,
        box.right * scaleX,
        box.bottom * scaleY,
      );

      final glowPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      RRect roundedBox = RRect.fromRectAndRadius(
        scaledBox,
        const Radius.circular(12),
      );

      canvas.drawRRect(roundedBox, glowPaint);

      final borderPaint = Paint()
        ..color = Colors.red.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawRRect(roundedBox, borderPaint);

      final fillPaint = Paint()
        ..color = Colors.red.withOpacity(0.12)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(roundedBox, fillPaint);

      final cornerPaint = Paint()
        ..color = Colors.red.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final cornerLen = 20.0;
      final corners = [
        [
          Offset(scaledBox.left, scaledBox.top + cornerLen),
          Offset(scaledBox.left, scaledBox.top),
          Offset(scaledBox.left + cornerLen, scaledBox.top),
        ],
        [
          Offset(scaledBox.right - cornerLen, scaledBox.top),
          Offset(scaledBox.right, scaledBox.top),
          Offset(scaledBox.right, scaledBox.top + cornerLen),
        ],
        [
          Offset(scaledBox.left, scaledBox.bottom - cornerLen),
          Offset(scaledBox.left, scaledBox.bottom),
          Offset(scaledBox.left + cornerLen, scaledBox.bottom),
        ],
        [
          Offset(scaledBox.right - cornerLen, scaledBox.bottom),
          Offset(scaledBox.right, scaledBox.bottom),
          Offset(scaledBox.right, scaledBox.bottom - cornerLen),
        ],
      ];

      for (var corner in corners) {
        final path = Path()..moveTo(corner[0].dx, corner[0].dy);
        for (int i = 1; i < corner.length; i++) {
          path.lineTo(corner[i].dx, corner[i].dy);
        }
        canvas.drawPath(path, cornerPaint);
      }

      _drawWarningIcon(
        canvas,
        scaledBox.center,
        (scaledBox.width + scaledBox.height) / 8,
      );
    }
  }

  void _drawWarningIcon(Canvas canvas, Offset center, double size) {
    final iconPaint = Paint()
      ..color = Colors.red.shade300
      ..style = PaintingStyle.fill;

    final path = Path();
    final halfSize = size / 2;

    path.moveTo(center.dx, center.dy - halfSize);
    path.lineTo(center.dx - halfSize + size / 6, center.dy + halfSize);
    path.lineTo(center.dx + halfSize - size / 6, center.dy + halfSize);
    path.close();

    canvas.drawPath(path, iconPaint);

    final exclaimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx, center.dy - size / 4),
      Offset(center.dx, center.dy + size / 8),
      exclaimPaint,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + size / 4),
      1.5,
      Paint()..color = Colors.white,
    );
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
    final radius = size.width / 2 - 20;

    _drawOuterRing(canvas, center, radius);
    _drawTickMarks(canvas, center, radius);
    _drawDirectionCardinals(canvas, center, radius);
    _drawInnerGlow(canvas, center, radius);
    _drawMainArrow(canvas, center, radius);
    _drawConfidenceRing(canvas, center, radius);
    if (showPath && turnIntensity.abs() > 0.05) {
      _drawTurnIndicator(canvas, center, radius);
    }
  }

  void _drawOuterRing(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, ringPaint);

    final gradientPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor.withOpacity(0.3),
          accentColor.withOpacity(0.3),
          primaryColor.withOpacity(0.3),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, gradientPaint);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    final majorTickPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final minorTickPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 360; i += 5) {
      final angle = (i - 90) * math.pi / 180;
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 15 : 8;
      final paint = isMajor ? majorTickPaint : minorTickPaint;

      final innerRadius = radius - tickLength;
      final outerRadius = radius;

      canvas.drawLine(
        Offset(
          center.dx + innerRadius * math.cos(angle),
          center.dy + innerRadius * math.sin(angle),
        ),
        Offset(
          center.dx + outerRadius * math.cos(angle),
          center.dy + outerRadius * math.sin(angle),
        ),
        paint,
      );
    }
  }

  void _drawDirectionCardinals(Canvas canvas, Offset center, double radius) {
    final directions = ['N', 'E', 'S', 'W'];
    final angles = [0, 90, 180, 270];

    for (int i = 0; i < directions.length; i++) {
      final angle = (angles[i] - 90) * math.pi / 180;
      final textOffset = Offset(
        center.dx + (radius - 35) * math.cos(angle),
        center.dy + (radius - 35) * math.sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: directions[i] == 'N'
                ? accentColor
                : Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          textOffset.dx - textPainter.width / 2,
          textOffset.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawInnerGlow(Canvas canvas, Offset center, double radius) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.15),
          accentColor.withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6));

    canvas.drawCircle(center, radius * 0.6, glowPaint);
  }

  void _drawMainArrow(Canvas canvas, Offset center, double radius) {
    final arrowPath = Path();
    final arrowSize = radius * 0.6;
    final arrowWidth = arrowSize * 0.35;

    arrowPath.moveTo(0, -arrowSize);
    arrowPath.lineTo(arrowWidth, arrowSize * 0.4);
    arrowPath.lineTo(arrowWidth * 0.5, arrowSize * 0.2);
    arrowPath.lineTo(arrowWidth * 0.5, arrowSize * 0.6);
    arrowPath.lineTo(-arrowWidth * 0.5, arrowSize * 0.6);
    arrowPath.lineTo(-arrowWidth * 0.5, arrowSize * 0.2);
    arrowPath.lineTo(-arrowWidth, arrowSize * 0.4);
    arrowPath.close();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * math.pi / 180);

    final shadowPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawPath(arrowPath, shadowPaint);

    final gradientPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accentColor, accentColor.withOpacity(0.8), primaryColor],
          ).createShader(
            Rect.fromLTWH(
              -arrowWidth,
              -arrowSize,
              arrowWidth * 2,
              arrowSize * 1.6,
            ),
          );

    canvas.drawPath(arrowPath, gradientPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(arrowPath, borderPaint);

    canvas.restore();
  }

  void _drawConfidenceRing(Canvas canvas, Offset center, double radius) {
    final sweepAngle = confidence * 2 * math.pi;

    final confidencePaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          Colors.green.shade400,
          Colors.green.shade300,
          Colors.transparent,
        ],
        stops: [0.0, confidence, confidence],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.75),
      -math.pi / 2,
      sweepAngle,
      false,
      confidencePaint,
    );
  }

  void _drawTurnIndicator(Canvas canvas, Offset center, double radius) {
    final turnPaint = Paint()
      ..color = turnIntensity.abs() > 0.3
          ? Colors.orange.shade400
          : Colors.blue.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final arcRadius = radius * 0.85;
    // Start from Top (North)
    final startAngle = -math.pi / 2;
    // Sweep based on turn intensity (positive = right/clockwise, negative = left/counter-clockwise)
    final sweepAngle = turnIntensity * math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius),
      startAngle,
      sweepAngle,
      false,
      turnPaint,
    );

    final arrowAngle = startAngle + sweepAngle;
    final arrowPos = Offset(
      center.dx + arcRadius * math.cos(arrowAngle),
      center.dy + arcRadius * math.sin(arrowAngle),
    );

    final arrowHeadPaint = Paint()
      ..color = turnPaint.color
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    const double arrowSize = 10;

    // Rotate arrow head to point in the direction of the turn
    canvas.save();
    canvas.translate(arrowPos.dx, arrowPos.dy);
    canvas.rotate(arrowAngle + (turnIntensity > 0 ? math.pi / 2 : -math.pi / 2));

    arrowPath.moveTo(0, -arrowSize / 2);
    arrowPath.lineTo(arrowSize, 0);
    arrowPath.lineTo(0, arrowSize / 2);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowHeadPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DirectionArrowPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.turnIntensity != turnIntensity ||
        oldDelegate.confidence != confidence;
  }
}
