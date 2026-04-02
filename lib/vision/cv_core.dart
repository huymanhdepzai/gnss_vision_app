import 'dart:ui';
import 'dart:math' as math;
import 'package:opencv_dart/opencv_dart.dart' as cv;

class CVCore {
  cv.Mat? _oldGray;
  cv.VecPoint2f? _p0;

  Offset _smoothedVector = Offset.zero;
  Offset _vectorVelocity = Offset.zero;

  final double _posAlpha = 0.15;
  final double _velAlpha = 0.15;

  List<Rect> _lastKnownObstacles = [];
  int _framesSinceLastYolo = 0;

  Map<String, dynamic> processFrame(cv.Mat frame, {List<Rect> aiObstacles = const []}) {
    List<Offset> trackedPoints = [];
    Offset rawMoveVector = Offset.zero;
    List<Rect> forbiddenZones = [];

    // Khởi tạo các biến Mat để có thể dispose tập trung
    cv.Mat? frameGray;
    cv.Mat? mask;

    try {
      frameGray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY);

      int frameW = frameGray.cols;
      int frameH = frameGray.rows;

      // 1. CẬP NHẬT VÙNG CẤM (FORBIDDEN ZONES) TỪ AI

      if (aiObstacles.isNotEmpty) {
        _lastKnownObstacles = List.from(aiObstacles);
        _framesSinceLastYolo = 0;
      } else {
        _framesSinceLastYolo++;
        if (_framesSinceLastYolo > 15) { // Giữ ký ức lâu hơn một chút
          _lastKnownObstacles.clear();
        }
      }

      for (var box in _lastKnownObstacles) {
        if (box.width > frameW * 0.7 || box.height > frameH * 0.7) continue;
        
        // Mở rộng vùng cấm một chút để đảm bảo an toàn
        double expansion = 0.1;
        double left = (box.left - box.width * expansion).clamp(0.0, frameW.toDouble());
        double top = (box.top - box.height * expansion).clamp(0.0, frameH.toDouble());
        double right = (box.right + box.width * expansion).clamp(0.0, frameW.toDouble());
        double bottom = (box.bottom + box.height * expansion).clamp(0.0, frameH.toDouble());

        forbiddenZones.add(Rect.fromLTRB(left, top, right, bottom));
      }

      List<cv.Point2f> goodNewPoints = [];

      // 2. OPTICAL FLOW (LUCAS-KANADE)
      if (_p0 != null && _oldGray != null && _p0!.isNotEmpty) {
        var (p1, status, err) = cv.calcOpticalFlowPyrLK(
          _oldGray!, frameGray, _p0!, cv.VecPoint2f(),
          winSize: (15, 15), // Giảm winSize để tăng tốc
          maxLevel: 1,       // Giảm maxLevel vì ảnh đã nhỏ (240px)
        );

        List<cv.Point2f> oldPoints = _p0!.toList();

        if (status != null && p1 != null) {
          double sumDx = 0;
          double sumDy = 0;
          int validFlowCount = 0;

          for (int i = 0; i < status.length; i++) {
            if (status[i] == 1) {
              double nx = p1[i].x;
              double ny = p1[i].y;
              double ox = oldPoints[i].x;
              double oy = oldPoints[i].y;

              // Kiểm tra xem điểm mới có nằm trong vùng cấm không
              bool isInsideForbidden = false;
              for (var zone in forbiddenZones) {
                if (zone.contains(Offset(nx, ny))) {
                  isInsideForbidden = true;
                  break;
                }
              }

              if (nx >= 0 && nx < frameW && ny >= 0 && ny < frameH && !isInsideForbidden) {
                trackedPoints.add(Offset(nx, ny));
                goodNewPoints.add(cv.Point2f(nx, ny));

                sumDx += (ox - nx);
                sumDy += (oy - ny);
                validFlowCount++;
              }
            }
          }

          if (validFlowCount > 0) {
            double finalDx = sumDx / validFlowCount;
            double finalDy = sumDy / validFlowCount;

            // Loại bỏ nhiễu nhỏ
            if (finalDx.abs() < 0.2) finalDx = 0.0;
            rawMoveVector = Offset(finalDx, finalDy);

            // Bộ lọc mượt (Smoothing)
            Offset targetVelocity = Offset(rawMoveVector.dx - _smoothedVector.dx, rawMoveVector.dy - _smoothedVector.dy);
            _vectorVelocity = Offset((_vectorVelocity.dx * (1 - _velAlpha)) + (targetVelocity.dx * _velAlpha), (_vectorVelocity.dy * (1 - _velAlpha)) + (targetVelocity.dy * _velAlpha));
            _smoothedVector = Offset(_smoothedVector.dx + _vectorVelocity.dx * _posAlpha, _smoothedVector.dy + _vectorVelocity.dy * _posAlpha);
          }
          
          p1.dispose();
          status.dispose();
          err?.dispose();
        }
      }

      // 3. TÁI TẠO ĐIỂM ĐẶC TRƯNG (KHI CẦN THIẾT)
      if (_p0 == null || _p0!.isEmpty || goodNewPoints.length < 30) {
        mask = cv.Mat.zeros(frameH, frameW, cv.MatType.CV_8UC1);
        
        // Chỉ tìm điểm ở nửa dưới bức ảnh (mặt đường)
        int roiY = (frameH * 0.5).toInt();
        cv.rectangle(mask, cv.Rect(0, roiY, frameW, frameH - roiY), cv.Scalar.fromRgb(255, 255, 255), thickness: -1);

        // Loại bỏ vùng AI đã cảnh báo khỏi mask
        for (var zone in forbiddenZones) {
          cv.rectangle(mask, cv.Rect(zone.left.toInt(), zone.top.toInt(), zone.width.toInt(), zone.height.toInt()), cv.Scalar.fromRgb(0, 0, 0), thickness: -1);
        }

        if (_p0 != null) _p0!.dispose();
        _p0 = cv.goodFeaturesToTrack(
            frameGray,
            60, // Giảm số lượng điểm xuống 60 để cực nhanh
            0.03,
            10.0,
            mask: mask
        );
      } else {
        if (_p0 != null) _p0!.dispose();
        _p0 = cv.VecPoint2f.fromList(goodNewPoints);
      }

      if (_oldGray != null) _oldGray!.dispose();
      _oldGray = frameGray.clone();

    } catch (e) {
      print("Lỗi CVCore: $e");
    } finally {
      frameGray?.dispose();
      mask?.dispose();
    }

    return {
      'points': trackedPoints,
      'vector': _smoothedVector,
      'forbiddenZones': forbiddenZones,
    };
  }

  void resetTracking() {
    _oldGray?.dispose();
    _oldGray = null;
    _p0?.dispose();
    _p0 = null;
    _smoothedVector = Offset.zero;
    _vectorVelocity = Offset.zero;
    _lastKnownObstacles.clear();
  }
}
