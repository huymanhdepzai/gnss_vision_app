import 'dart:math' as math;
import 'kalman_filter.dart';

class SensorFusion {
  double _fusedHeading = 0.0;
  final KalmanFilterAngle _headingKalman;

  double _lastVisionConfidence = 0.0;
  double _lastTrackQuality = 0.0;

  int _consecutiveLowConfidence = 0;
  int _consecutiveHighConfidence = 0;

  SensorFusion()
    : _headingKalman = KalmanFilterAngle(
        processNoise: 0.05,
        measurementNoise: 2.5,
      );

  double update({
    required double visionDx,
    required double gpsHeading,
    required double imuAccelY,
    required bool hasValidGps,
    required int trackedPointsCount,
    required double gpsAccuracy,
    double visionConfidence = 0.5,
    double visionQuality = 0.5,
  }) {
    _lastVisionConfidence = visionConfidence;
    _lastTrackQuality = visionQuality;

    if (visionConfidence < 0.2) {
      _consecutiveLowConfidence++;
      _consecutiveHighConfidence = 0;
    } else if (visionConfidence > 0.6) {
      _consecutiveHighConfidence++;
      _consecutiveLowConfidence = 0;
    } else {
      _consecutiveLowConfidence = (_consecutiveLowConfidence * 0.8).toInt();
      _consecutiveHighConfidence = (_consecutiveHighConfidence * 0.8).toInt();
    }

    double safeVisionDx = -visionDx; // Invert dx: pixels moving left (negative dx) means turning right (positive heading change)
    if (imuAccelY.abs() > 3.0) {
      double bumpFactor = (imuAccelY.abs() - 3.0) / 10.0;
      safeVisionDx *= math.max(0.0, 1.0 - bumpFactor);
    }

    double visionHeadingDelta = safeVisionDx * 0.3;

    double baseAlpha = 0.90;

    double visionWeight = 0.5;
    if (visionConfidence > 0.7 && visionQuality > 0.5) {
      visionWeight = 0.8;
    } else if (visionConfidence > 0.5) {
      visionWeight = 0.6;
    } else if (visionConfidence > 0.3) {
      visionWeight = 0.4;
    } else {
      visionWeight = 0.2;
    }

    if (trackedPointsCount < 15) {
      visionWeight *= 0.3;
      baseAlpha -= 0.3;
    } else if (trackedPointsCount < 30) {
      visionWeight *= 0.6;
      baseAlpha -= 0.15;
    }

    if (gpsAccuracy > 20.0) {
      baseAlpha += visionWeight * 0.15;
    } else if (gpsAccuracy > 15.0) {
      baseAlpha += visionWeight * 0.08;
    }

    if (_consecutiveLowConfidence > 5) {
      baseAlpha = math.max(0.5, baseAlpha - 0.1);
    }
    if (_consecutiveHighConfidence > 10) {
      baseAlpha = math.min(0.95, baseAlpha + 0.05);
    }

    baseAlpha = baseAlpha.clamp(0.1, 0.98);

    if (!hasValidGps) {
      _headingKalman.predict(0.033);

      double predictedVelocity = _headingKalman.getAngularVelocity();
      double predictedDelta = predictedVelocity * 0.033;

      double visionPredictedDelta =
          visionHeadingDelta *
          (visionConfidence > 0.5 ? 1.0 : visionConfidence * 2);

      double finalDelta = predictedDelta * 0.3 + visionPredictedDelta * 0.7;

      _fusedHeading += finalDelta;

      _headingKalman.update(_fusedHeading);
    } else {
      double predictedHeading = _fusedHeading + visionHeadingDelta;

      double diff = gpsHeading - predictedHeading;
      while (diff <= -180) diff += 360;
      while (diff > 180) diff -= 360;

      double gpsWeight = (1 - baseAlpha);

      if (visionConfidence > 0.7) {
        gpsWeight *= 0.6;
      }

      double fusedChange = gpsWeight * diff;
      _fusedHeading = predictedHeading + fusedChange;

      _headingKalman.predict(0.033);
      _headingKalman.update(_fusedHeading);
    }

    while (_fusedHeading < 0) _fusedHeading += 360;
    while (_fusedHeading >= 360) _fusedHeading -= 360;

    return _fusedHeading;
  }

  double getConfidence() => _lastVisionConfidence;
  double getQuality() => _lastTrackQuality;
  int getLowConfidenceStreak() => _consecutiveLowConfidence;
  int getHighConfidenceStreak() => _consecutiveHighConfidence;

  void reset(double initialHeading) {
    _fusedHeading = initialHeading;
    _headingKalman.reset(initialHeading);
    _lastVisionConfidence = 0.0;
    _lastTrackQuality = 0.0;
    _consecutiveLowConfidence = 0;
    _consecutiveHighConfidence = 0;
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'heading': _fusedHeading,
      'visionConfidence': _lastVisionConfidence,
      'visionQuality': _lastTrackQuality,
      'lowStreak': _consecutiveLowConfidence,
      'highStreak': _consecutiveHighConfidence,
    };
  }
}
