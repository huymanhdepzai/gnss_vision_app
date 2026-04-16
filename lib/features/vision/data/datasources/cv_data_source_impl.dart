import 'dart:ui';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../../domain/utils/kalman_filter.dart';
import '../../domain/utils/motion_estimator.dart';

class CVDataSourceImpl {
  cv.Mat? _oldGray;
  cv.VecPoint2f? _p0;

  final KalmanFilter2D _motionKalman;
  final MotionEstimator _motionEstimator;

  Offset _legacySmoothedVector = Offset.zero;
  Offset _velocity = Offset.zero;
  final double _posAlpha = 0.15;
  final double _velAlpha = 0.15;

  List<Rect> _lastKnownObstacles = [];
  int _framesSinceLastYolo = 0;

  double _lastConfidence = 0.0;
  int _lastInlierCount = 0;
  double _lastQuality = 0.0;

  int _frameCounter = 0;
  bool _kalmanInitialized = false;

  CVDataSourceImpl({double processNoise = 0.08, double measurementNoise = 1.5})
    : _motionKalman = KalmanFilter2D(
        processNoise: processNoise,
        measurementNoise: measurementNoise,
      ),
      _motionEstimator = MotionEstimator();

  Map<String, dynamic> processFrame(
    cv.Mat frame, {
    List<Rect> aiObstacles = const [],
  }) {
    List<Offset> trackedPoints = [];
    Offset rawMoveVector = Offset.zero;
    List<Rect> forbiddenZones = [];

    cv.Mat? frameGray;
    cv.Mat? mask;

    _frameCounter++;

    try {
      frameGray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY);

      int frameW = frameGray.cols;
      int frameH = frameGray.rows;

      if (aiObstacles.isNotEmpty) {
        _lastKnownObstacles = List.from(aiObstacles);
        _framesSinceLastYolo = 0;
      } else {
        _framesSinceLastYolo++;
        if (_framesSinceLastYolo > 20) {
          _lastKnownObstacles.clear();
        }
      }

      for (var box in _lastKnownObstacles) {
        if (box.width > frameW * 0.7 || box.height > frameH * 0.7) continue;

        double expansion = 0.15;
        double left = (box.left - box.width * expansion).clamp(
          0.0,
          frameW.toDouble(),
        );
        double top = (box.top - box.height * expansion).clamp(
          0.0,
          frameH.toDouble(),
        );
        double right = (box.right + box.width * expansion).clamp(
          0.0,
          frameW.toDouble(),
        );
        double bottom = (box.bottom + box.height * expansion).clamp(
          0.0,
          frameH.toDouble(),
        );

        forbiddenZones.add(Rect.fromLTRB(left, top, right, bottom));
      }

      List<cv.Point2f> goodNewPoints = [];
      List<Offset> oldPointsForRansac = [];
      List<Offset> newPointsForRansac = [];

      if (_p0 != null && _oldGray != null && _p0!.isNotEmpty) {
        var (p1, status, err) = cv.calcOpticalFlowPyrLK(
          _oldGray!,
          frameGray,
          _p0!,
          cv.VecPoint2f(),
          winSize: (15, 15),
          maxLevel: 2,
        );

        List<cv.Point2f> oldPoints = _p0!.toList();

        if (status != null && p1 != null) {
          for (int i = 0; i < status.length; i++) {
            if (status[i] == 1) {
              double nx = p1[i].x;
              double ny = p1[i].y;
              double ox = oldPoints[i].x;
              double oy = oldPoints[i].y;

              bool isInsideForbidden = false;
              for (var zone in forbiddenZones) {
                if (zone.contains(Offset(nx, ny))) {
                  isInsideForbidden = true;
                  break;
                }
              }

              if (nx >= 0 &&
                  nx < frameW &&
                  ny >= 0 &&
                  ny < frameH &&
                  !isInsideForbidden) {
                trackedPoints.add(Offset(nx, ny));
                goodNewPoints.add(cv.Point2f(nx, ny));
                oldPointsForRansac.add(Offset(ox, oy));
                newPointsForRansac.add(Offset(nx, ny));
              }
            }
          }

          if (oldPointsForRansac.length >= 8) {
            var result = _motionEstimator.estimateMotion(
              oldPointsForRansac,
              newPointsForRansac,
            );

            rawMoveVector = result.vector;
            _lastInlierCount = result.inliers;
            _lastQuality = result.quality;

            if (result.inliers >= 8 && result.confidence > 0.3) {
              if (!_kalmanInitialized) {
                _motionKalman.setPosition(rawMoveVector);
                _kalmanInitialized = true;
              }

              _motionKalman.predict(0.033);
              _motionKalman.update(rawMoveVector.dx, rawMoveVector.dy);

              Offset smoothed = _motionKalman.getPosition();
              double uncertainty = _motionKalman.getUncertainty();

              if (uncertainty < 10.0 && rawMoveVector.distance < 50.0) {
                _legacySmoothedVector = smoothed;
                _lastConfidence =
                    result.confidence * (1.0 - uncertainty / 10.0);
              } else {
                _applyLegacySmoothing(rawMoveVector);
                _lastConfidence = result.confidence * 0.5;
              }
            } else {
              _applyLegacySmoothing(rawMoveVector);
              _lastConfidence = result.confidence * 0.3;
            }
          } else {
            _lastConfidence = 0.0;
            _lastInlierCount = 0;
            _lastQuality = 0.0;
          }

          p1.dispose();
          status.dispose();
          err?.dispose();
        }
      }

      int targetPoints = _calculateAdaptivePointCount(_lastConfidence);

      if (_p0 == null ||
          _p0!.isEmpty ||
          goodNewPoints.length < targetPoints ~/ 2) {
        mask = cv.Mat.zeros(frameH, frameW, cv.MatType.CV_8UC1);

        int roiY = (frameH * 0.4).toInt();
        cv.rectangle(
          mask,
          cv.Rect(0, roiY, frameW, frameH - roiY),
          cv.Scalar.fromRgb(255, 255, 255),
          thickness: -1,
        );

        for (var zone in forbiddenZones) {
          cv.rectangle(
            mask,
            cv.Rect(
              zone.left.toInt(),
              zone.top.toInt(),
              zone.width.toInt(),
              zone.height.toInt(),
            ),
            cv.Scalar.fromRgb(0, 0, 0),
            thickness: -1,
          );
        }

        if (_p0 != null) _p0!.dispose();
        _p0 = cv.goodFeaturesToTrack(
          frameGray,
          targetPoints,
          0.03,
          8.0,
          mask: mask,
        );

        _kalmanInitialized = false;
      } else {
        if (_p0 != null) _p0!.dispose();
        _p0 = cv.VecPoint2f.fromList(goodNewPoints);
      }

      if (_oldGray != null) _oldGray!.dispose();
      _oldGray = frameGray.clone();
    } catch (e) {
      print("CVDataSourceImpl error: $e");
    } finally {
      frameGray?.dispose();
      mask?.dispose();
    }

    return {
      'points': trackedPoints,
      'vector': _legacySmoothedVector,
      'forbiddenZones': forbiddenZones,
      'confidence': _lastConfidence,
      'inlierCount': _lastInlierCount,
      'quality': _lastQuality,
      'trackCount': trackedPoints.length,
    };
  }

  void _applyLegacySmoothing(Offset rawVector) {
    Offset targetVelocity = Offset(
      rawVector.dx - _legacySmoothedVector.dx,
      rawVector.dy - _legacySmoothedVector.dy,
    );

    _velocity = Offset(
      (_velocity.dx * (1 - _velAlpha)) + (targetVelocity.dx * _velAlpha),
      (_velocity.dy * (1 - _velAlpha)) + (targetVelocity.dy * _velAlpha),
    );

    _legacySmoothedVector = Offset(
      _legacySmoothedVector.dx + _velocity.dx * _posAlpha,
      _legacySmoothedVector.dy + _velocity.dy * _posAlpha,
    );
  }

  int _calculateAdaptivePointCount(double confidence) {
    int baseCount = 60;

    if (confidence > 0.7) {
      return (baseCount * 0.7).toInt();
    } else if (confidence > 0.5) {
      return (baseCount * 0.85).toInt();
    } else if (confidence > 0.3) {
      return baseCount;
    } else {
      return (baseCount * 1.2).toInt();
    }
  }

  void reset() {
    _oldGray?.dispose();
    _oldGray = null;
    _p0?.dispose();
    _p0 = null;
    _legacySmoothedVector = Offset.zero;
    _velocity = Offset.zero;
    _lastKnownObstacles.clear();
    _motionKalman.reset();
    _kalmanInitialized = false;
    _lastConfidence = 0.0;
    _lastInlierCount = 0;
    _lastQuality = 0.0;
    _frameCounter = 0;
  }
}
