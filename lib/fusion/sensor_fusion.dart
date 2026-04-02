import 'dart:math' as math;

class SensorFusion {
  double _fusedHeading = 0.0;

  double update({
    required double visionDx,
    required double gpsHeading,
    required double imuAccelY,
    required bool hasValidGps,
    required int trackedPointsCount,
    required double gpsAccuracy,
  }) {

    // 1. PHƯƠNG ÁN BÙ TRỪ IMU (LỌC Ổ GÀ)
    double safeVisionDx = visionDx;
    if (imuAccelY.abs() > 3.0) {
      safeVisionDx = 0.0;
    }

    double visionHeadingDelta = safeVisionDx * 0.3;

    if (!hasValidGps) {
      _fusedHeading += visionHeadingDelta;
    } else {

      double dynamicAlpha = 0.90;

      // Phạt Vision: Nếu đường quá tối, mất vạch kẻ, ít điểm đặc trưng
      if (trackedPointsCount < 20) {
        dynamicAlpha -= 0.40;
      }

      // Phạt GPS: Nếu sai số > 15 mét (đang ở dưới hầm chui, mây mù che khuất)
      if (gpsAccuracy > 15.0) {
        dynamicAlpha += 0.08;
      }

      dynamicAlpha = dynamicAlpha.clamp(0.1, 0.98);

      double predictedHeading = _fusedHeading + visionHeadingDelta;

      double diff = gpsHeading - predictedHeading;
      while (diff <= -180) diff += 360;
      while (diff > 180) diff -= 360;
      _fusedHeading = predictedHeading + ((1 - dynamicAlpha) * diff);
    }

    // Chuẩn hóa góc UI (0 - 360)
    while (_fusedHeading < 0) _fusedHeading += 360;
    while (_fusedHeading >= 360) _fusedHeading -= 360;

    return _fusedHeading;
  }

  void reset(double initialHeading) {
    _fusedHeading = initialHeading;
  }
}