import 'dart:ui';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class CVCore {
  cv.Mat? _oldGray;
  cv.VecPoint2f? _p0;

  Offset _smoothedVector = Offset.zero;
  Offset _vectorVelocity = Offset.zero;

  final double _posAlpha = 0.15;
  final double _velAlpha = 0.05; // Độ đầm/nặng của vô lăng

  Map<String, dynamic> processFrame(cv.Mat frame) {
    List<Offset> trackedPoints = [];
    Offset rawMoveVector = Offset.zero;
    List<Rect> staticRois = [];

    try {
      cv.Mat frameGray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY);

      // KHUNG LƯỚI & HÌNH THANG (UI Setup)
      int roiWidth = frameGray.cols;
      int roiHeight = (frameGray.rows ~/ 2) + 40;
      int roiX = 0;
      int roiY = frameGray.rows - roiHeight;

      double cellW = roiWidth / 3;
      double cellH = roiHeight / 2;
      for (int r = 0; r < 2; r++) {
        for (int c = 0; c < 3; c++) {
          staticRois.add(Rect.fromLTWH(roiX + (c * cellW), roiY + (r * cellH), cellW, cellH));
        }
      }

      // ==========================================================
      // BƯỚC 1: TÍNH TOÁN OPTICAL FLOW (Luôn luôn tính nếu có điểm)
      // ==========================================================
      List<cv.Point2f> goodNewPoints = [];

      if (_p0 != null && _oldGray != null) {
        // Nâng maxLevel lên 3 để thuật toán bám dính tốt hơn khi xe chạy tốc độ cao
        var (p1, status, err) = cv.calcOpticalFlowPyrLK(
          _oldGray!,
          frameGray,
          _p0!,
          cv.VecPoint2f(),
          winSize: (21, 21), // Mở rộng cửa sổ tìm kiếm lên 21x21
          maxLevel: 3,
        );

        List<cv.Point2f> oldPoints = _p0!.toList();
        List<List<double>> colDx = [[], [], []];
        List<List<double>> colDy = [[], [], []];

        if (status != null && p1 != null) {
          for (int i = 0; i < status.length; i++) {
            if (status[i] == 1) {
              double nx = p1[i].x;
              double ny = p1[i].y;
              double ox = oldPoints[i].x;
              double oy = oldPoints[i].y;

              if (nx >= 0 && nx < frameGray.cols && ny >= 0 && ny < frameGray.rows) {
                trackedPoints.add(Offset(nx, ny));
                goodNewPoints.add(cv.Point2f(nx, ny));

                // Chuẩn hóa phối cảnh
                double yRatio = (oy - roiY) / roiHeight;
                yRatio = yRatio.clamp(0.2, 1.0);

                double dx = (ox - nx) / yRatio;
                double dy = (oy - ny) / yRatio;

                if (ox >= roiX && ox < roiX + roiWidth && oy >= roiY && oy < roiY + roiHeight) {
                  int col = ((ox - roiX) / cellW).floor().clamp(0, 2);
                  colDx[col].add(dx);
                  colDy[col].add(dy);
                }
              }
            }
          }
        }

        // BỘ LỌC MAD (Sát thủ điểm rác)
        List<double> filterByMAD(List<double> list) {
          if (list.length < 5) return list;
          list.sort();
          double median = list[list.length ~/ 2];

          List<double> deviations = list.map((x) => (x - median).abs()).toList();
          deviations.sort();
          double mad = deviations[deviations.length ~/ 2];

          if (mad == 0.0) mad = 0.001;
          return list.where((x) => (x - median).abs() <= 1.5 * mad).toList();
        }

        double? getCleanAverage(List<double> rawList) {
          List<double> cleanList = filterByMAD(rawList);
          if (cleanList.isEmpty) return null;
          double sum = 0;
          for (var v in cleanList) sum += v;
          return sum / cleanList.length;
        }

        double? mDxLeft = getCleanAverage(colDx[0]);
        double? mDxCenter = getCleanAverage(colDx[1]);
        double? mDxRight = getCleanAverage(colDx[2]);

        double finalDx = 0;
        int dxVotes = 0;

        if (mDxCenter != null) { finalDx += mDxCenter; dxVotes += 1; }
        if (mDxLeft != null && mDxRight != null) { finalDx += (mDxLeft + mDxRight) / 2; dxVotes += 1; }

        if (dxVotes > 0) {
          finalDx /= dxVotes;
        } else if (mDxLeft != null) {
          finalDx = mDxLeft;
        } else if (mDxRight != null) {
          finalDx = mDxRight;
        }

        double? mDyLeft = getCleanAverage(colDy[0]);
        double? mDyCenter = getCleanAverage(colDy[1]);
        double? mDyRight = getCleanAverage(colDy[2]);

        List<double> validDy = [];
        if (mDyLeft != null) validDy.add(mDyLeft);
        if (mDyCenter != null) validDy.add(mDyCenter);
        if (mDyRight != null) validDy.add(mDyRight);

        double finalDy = 0;
        if (validDy.isNotEmpty) {
          validDy.sort();
          finalDy = validDy[validDy.length ~/ 2];
        }

        if (finalDy > 0) finalDy = -0.1;

        rawMoveVector = Offset(finalDx, finalDy);
        if (rawMoveVector.distance < 0.2) {
          rawMoveVector = Offset.zero;
        }

        // ==========================================================
        // 🌟 THUẬT TOÁN ĐỘNG HỌC KÉP (DOUBLE INERTIA MODEL) 🌟
        // ==========================================================
        // 1. Tính gia tốc của chuyển động (Tốc độ xoay vô lăng)
        Offset targetVelocity = Offset(
            rawMoveVector.dx - _smoothedVector.dx,
            rawMoveVector.dy - _smoothedVector.dy
        );

        // 2. Làm mượt gia tốc (Vô lăng không thể bị khựng đột ngột)
        _vectorVelocity = Offset(
            (_vectorVelocity.dx * (1 - _velAlpha)) + (targetVelocity.dx * _velAlpha),
            (_vectorVelocity.dy * (1 - _velAlpha)) + (targetVelocity.dy * _velAlpha)
        );

        // 3. Cập nhật vị trí vô lăng dựa trên gia tốc đã làm mượt
        _smoothedVector = Offset(
            _smoothedVector.dx + _vectorVelocity.dx * _posAlpha,
            _smoothedVector.dy + _vectorVelocity.dy * _posAlpha
        );
      }

      // ==========================================================
      // BƯỚC 2: QUẢN LÝ ĐIỂM THEO DÕI (ZERO-BLACKOUT)
      // ==========================================================
      // Nếu là khung hình đầu tiên, HOẶC số lượng điểm còn lại quá ít (< 100)
      if (_p0 == null || goodNewPoints.length < 100) {

        cv.Mat mask = cv.Mat.zeros(frameGray.rows, frameGray.cols, cv.MatType.CV_8UC1);
        int topY = frameGray.rows ~/ 2 + 20;
        int bottomY = frameGray.rows - 40;
        int topWidth = frameGray.cols ~/ 3;
        int topLeftX = (frameGray.cols - topWidth) ~/ 2;

        var pts = cv.VecVecPoint.fromList([
          [
            cv.Point(topLeftX, topY),
            cv.Point(topLeftX + topWidth, topY),
            cv.Point(frameGray.cols, bottomY),
            cv.Point(0, bottomY)
          ]
        ]);

        cv.fillPoly(mask, pts, cv.Scalar.fromRgb(255, 255, 255));

        // Rải lại điểm MỚI trên khung hình HIỆN TẠI
        _p0 = cv.goodFeaturesToTrack(
            frameGray,
            300,
            0.05,
            5.0,
            mask: mask
        );

        // Cực kỳ quan trọng: Nếu là khung hình đầu tiên thì chưa có Vector
        if (_oldGray == null) {
          _smoothedVector = Offset.zero;
          _vectorVelocity = Offset.zero;
        }
      } else {
        // Cập nhật các điểm sống sót để dùng cho vòng lặp sau
        _p0 = cv.VecPoint2f.fromList(goodNewPoints);
      }

      // Cập nhật ảnh quá khứ thành ảnh hiện tại
      _oldGray = frameGray.clone();

    } catch (e) {
      print("Lỗi OpenCV: $e");
    }

    return {
      'points': trackedPoints,
      'center': null,
      'vector': _smoothedVector,
      'staticRois': staticRois,
    };
  }

  void resetTracking() {
    _oldGray = null; // Ép hệ thống tạo lại điểm từ đầu
    _p0 = null;
    _smoothedVector = Offset.zero;
    _vectorVelocity = Offset.zero;
  }
}