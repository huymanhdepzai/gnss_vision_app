import 'package:flutter/material.dart';

class FlowPainter extends CustomPainter {
  final List<Offset> points;
  final Size imageSize;
  final List<Rect>? staticRois;
  final List<Rect>? aiObstacles;
  final bool isDebugMode; // 🌟 THÊM BIẾN NÀY


  FlowPainter({
    required this.points,
    required this.imageSize,
    this.staticRois,
    this.aiObstacles,
    this.isDebugMode = false, // Mặc định là tắt
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Tránh lỗi khi frame chưa khởi tạo xong
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // =========================================================
    // 1. VẼ KHUNG LƯỚI RADAR (CHỈ VẼ KHI BẬT DEBUG MODE)
    // =========================================================
    if (isDebugMode && staticRois != null) {
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

        // Vẽ tâm chữ thập nhỏ cho từng ô lưới
        final centerHud = scaledRoi.center;
        canvas.drawLine(Offset(centerHud.dx - 10, centerHud.dy), Offset(centerHud.dx + 10, centerHud.dy), hudPaint);
        canvas.drawLine(Offset(centerHud.dx, centerHud.dy - 10), Offset(centerHud.dx, centerHud.dy + 10), hudPaint);
      }
    }

    // =========================================================
    // 2. VẼ VÙNG CẤM DO AI CẢNH BÁO VA CHẠM (LUÔN LUÔN VẼ)
    // =========================================================
    if (aiObstacles != null) {
      final aiPaint = Paint()
        ..color = Colors.redAccent.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5; // Làm viền mỏng và sắc nét hơn

      final aiFillPaint = Paint()
        ..color = Colors.redAccent.withOpacity(0.15) // Làm màu nền trong suốt hơn
        ..style = PaintingStyle.fill;

      for (var box in aiObstacles!) {
        Rect scaledBox = Rect.fromLTRB(
          box.left * scaleX,
          box.top * scaleY,
          box.right * scaleX,
          box.bottom * scaleY,
        );

        // Bo góc khung đỏ để giao diện trông hiện đại (Giống Tesla HUD)
        RRect roundedBox = RRect.fromRectAndRadius(scaledBox, const Radius.circular(12));

        canvas.drawRRect(roundedBox, aiFillPaint);
        canvas.drawRRect(roundedBox, aiPaint);

        // Đã xóa bỏ các đường chéo (cross lines) để giao diện không bị rối mắt
      }
    }

    if (points.isEmpty) return;

    // =========================================================
    // 3. VẼ CHẤM XANH OPTICAL FLOW (CHỈ VẼ KHI BẬT DEBUG MODE)
    // =========================================================
    if (isDebugMode) {
      final pointPaint = Paint()
        ..color = Colors.greenAccent
        ..strokeWidth = 4.0
        ..style = PaintingStyle.fill;

      for (var point in points) {
        double mappedX = point.dx * scaleX;
        double mappedY = point.dy * scaleY;
        canvas.drawCircle(Offset(mappedX, mappedY), 2.5, pointPaint); // Chấm nhỏ gọn hơn
      }
    }
  }

  @override
  bool shouldRepaint(covariant FlowPainter oldDelegate) {
    // Luôn luôn vẽ lại vì đây là video real-time
    return true;
  }
}