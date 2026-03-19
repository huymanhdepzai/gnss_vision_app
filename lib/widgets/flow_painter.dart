import 'package:flutter/material.dart';

class FlowPainter extends CustomPainter {
  final List<Offset> points;
  final Size imageSize;

  // ĐỔI THÀNH LIST
  final List<Rect>? staticRois;

  FlowPainter({
    required this.points,
    required this.imageSize,
    this.staticRois,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // 1. VẼ 2 KHUNG RADAR (TRÁI & PHẢI)
    if (staticRois != null) {
      final hudPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      for (var roi in staticRois!) {
        Rect scaledRoi = Rect.fromLTRB(
          roi.left * scaleX,
          roi.top * scaleY,
          roi.right * scaleX,
          roi.bottom * scaleY,
        );

        canvas.drawRect(scaledRoi, hudPaint);

        // Vẽ tia crosshair ở giữa mỗi ô
        final centerHud = scaledRoi.center;
        canvas.drawLine(Offset(centerHud.dx - 10, centerHud.dy), Offset(centerHud.dx + 10, centerHud.dy), hudPaint);
        canvas.drawLine(Offset(centerHud.dx, centerHud.dy - 10), Offset(centerHud.dx, centerHud.dy + 10), hudPaint);
      }
    }

    if (points.isEmpty) return;

    // 2. VẼ CÁC CHẤM XANH
    final pointPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.fill;

    for (var point in points) {
      double mappedX = point.dx * scaleX;
      double mappedY = point.dy * scaleY;
      canvas.drawCircle(Offset(mappedX, mappedY), 3.0, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FlowPainter oldDelegate) {
    return true;
  }
}