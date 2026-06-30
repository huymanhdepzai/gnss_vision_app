import 'dart:ui';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'motion_estimator.dart';
import 'kalman_filter.dart';
import 'feature_tracker.dart';

enum TrackingMode { environment, objectFocus }

class CVCore {
  TrackingMode _mode = TrackingMode.environment;
  Rect? _targetBox;
  String? _relativeWarning;
  int _unmatchedYoloCount = 0;

  cv.Mat? _oldGray;
  cv.VecPoint2f? _p0;

  final KalmanFilter2D _motionKalman;
  final MotionEstimator _motionEstimator;
  final FeatureTracker _featureTracker;

  Offset _smoothedVector = Offset.zero;
  Offset _velocity = Offset.zero;
  final double _posAlpha = 0.15;
  final double _velAlpha = 0.15;

  List<Rect> _lastKnownObstacles = [];
  int _framesSinceLastYolo = 0;
  double _lastConfidence = 0.0;
  int _lastInlierCount = 0;
  double _lastQuality = 0.0;
  bool _kalmanInitialized = false;

  CVCore({double processNoise = 0.08, double measurementNoise = 1.5})
      : _motionKalman = KalmanFilter2D(
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        ),
        _motionEstimator = MotionEstimator(),
        _featureTracker = FeatureTracker()..initializeGrid();

  Map<String, dynamic> processFrame(
    cv.Mat frame, {
    List<Rect> aiObstacles = const [],
  }) {
    List<Offset> trackedPoints = [];
    Offset rawMoveVector = Offset.zero;
    List<Rect> forbiddenZones = [];

    cv.Mat? frameGray;
    cv.Mat? mask;

    try {
      frameGray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY);

      int frameW = frameGray.cols;
      int frameH = frameGray.rows;

      if (aiObstacles.isNotEmpty) {
        _lastKnownObstacles = List.from(aiObstacles);
        _framesSinceLastYolo = 0;

        if (_mode == TrackingMode.objectFocus && _targetBox != null) {
          double maxIou = 0.0;
          Rect? bestMatch;
          for (var box in _lastKnownObstacles) {
            double intersection = _targetBox!.intersect(box).width.clamp(0.0, double.infinity) *
                                  _targetBox!.intersect(box).height.clamp(0.0, double.infinity);
            double union = _targetBox!.width * _targetBox!.height + box.width * box.height - intersection;
            double iou = union > 0 ? intersection / union : 0.0;

            if (iou > maxIou) {
              maxIou = iou;
              bestMatch = box;
            }
          }
          // Snap to YOLO box to prevent drift
          if (maxIou > 0.3 && bestMatch != null) {
            if (bestMatch.width > _targetBox!.width * 1.05) {
              _relativeWarning = "Khoảng cách đang hẹp lại! Chú ý phanh!";
            } else if (bestMatch.width < _targetBox!.width * 0.95) {
              _relativeWarning = "Mục tiêu đang xa dần.";
            } else {
              _relativeWarning = "Đang bám sát mục tiêu.";
            }
            _targetBox = bestMatch;
            _unmatchedYoloCount = 0;
          } else {
            _unmatchedYoloCount++;
            if (_unmatchedYoloCount > 15) { // ~0.5s without YOLO match
              _mode = TrackingMode.environment;
              _targetBox = null;
              _relativeWarning = null;
            }
          }
        }
      } else {
        _framesSinceLastYolo++;
        if (_framesSinceLastYolo > 20) {
          _lastKnownObstacles.clear();
        }
        if (_mode == TrackingMode.objectFocus) {
          _unmatchedYoloCount++;
          if (_unmatchedYoloCount > 15) {
            _mode = TrackingMode.environment;
            _targetBox = null;
            _relativeWarning = null;
          }
        }
      }

      if (_mode == TrackingMode.objectFocus && _targetBox != null) {
        // Check if target is out of frame or obscured >= 50% by the edge
        Rect frameRect = Rect.fromLTRB(0, 0, frameW.toDouble(), frameH.toDouble());
        Rect intersection = _targetBox!.intersect(frameRect);
        double intersectionArea = intersection.width.clamp(0.0, double.infinity) * 
                                  intersection.height.clamp(0.0, double.infinity);
        double targetArea = _targetBox!.width * _targetBox!.height;

        if (intersectionArea < targetArea * 0.5) {
          _mode = TrackingMode.environment;
          _targetBox = null;
          _relativeWarning = null;
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
          List<double> qualities = [];
          for (int i = 0; i < status.length; i++) {
            if (status[i] == 1) {
              double nx = p1[i].x;
              double ny = p1[i].y;
              double ox = oldPoints[i].x;
              double oy = oldPoints[i].y;

              bool isInsideForbidden = false;
              if (_mode == TrackingMode.environment) {
                for (var zone in forbiddenZones) {
                  if (zone.contains(Offset(nx, ny))) {
                    isInsideForbidden = true;
                    break;
                  }
                }
              } else if (_mode == TrackingMode.objectFocus && _targetBox != null) {
                Rect expandedTarget = Rect.fromLTRB(
                  _targetBox!.left - 20, _targetBox!.top - 20, 
                  _targetBox!.right + 20, _targetBox!.bottom + 20
                );
                if (!expandedTarget.contains(Offset(nx, ny))) {
                    isInsideForbidden = true;
                }
              }

              if (nx >= 0 &&
                  nx < frameW &&
                  ny >= 0 &&
                  ny < frameH &&
                  !isInsideForbidden) {
                goodNewPoints.add(cv.Point2f(nx, ny));
                oldPointsForRansac.add(Offset(ox, oy));
                newPointsForRansac.add(Offset(nx, ny));
                qualities.add(1.0); // Simple quality for now
              }
            }
          }

          // NÂNG CẤP 4: Sử dụng FeatureTracker để quản lý điểm theo lưới
          _featureTracker.updatePoints(
              newPointsForRansac, qualities, frameW, frameH);
          trackedPoints = _featureTracker.getAllPoints();

          if (oldPointsForRansac.length >= (_mode == TrackingMode.objectFocus ? 4 : 8)) {
            var result = _motionEstimator.estimateMotion(
              oldPointsForRansac,
              newPointsForRansac,
            );

            rawMoveVector = result.vector;
            _lastInlierCount = result.inliers;
            _lastQuality = result.quality;

            if (_mode == TrackingMode.objectFocus && _targetBox != null) {
              _targetBox = _targetBox!.shift(rawMoveVector);
            }

            if (result.inliers >= (_mode == TrackingMode.objectFocus ? 4 : 8) && result.confidence > 0.3) {
              if (!_kalmanInitialized) {
                _motionKalman.setPosition(rawMoveVector);
                _kalmanInitialized = true;
              }

              _motionKalman.predict(0.033);
              _motionKalman.update(rawMoveVector.dx, rawMoveVector.dy);

              Offset smoothed = _motionKalman.getPosition();
              double uncertainty = _motionKalman.getUncertainty();

              if (uncertainty < 10.0 && rawMoveVector.distance < 50.0) {
                _smoothedVector = smoothed;
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
            _applyLegacySmoothing(Offset.zero);
          }

          p1.dispose();
          status.dispose();
          err?.dispose();
        }
      }

      int targetPoints = _calculateAdaptivePointCount(_lastConfidence);
      if (_mode == TrackingMode.objectFocus) targetPoints = 30; // Fewer points needed for a single object

      bool needsReinit = _p0 == null || _p0!.isEmpty;
      
      if (_mode == TrackingMode.environment) {
        needsReinit = needsReinit ||
            _featureTracker.getTotalPointCount() < targetPoints ~/ 2 ||
            _featureTracker.getCellsNeedingPoints(frameW, frameH).isNotEmpty;
      } else {
        // Only re-init if points drop too low in the target box
        needsReinit = needsReinit || _featureTracker.getTotalPointCount() < 8;
      }

      if (needsReinit) {
        mask = cv.Mat.zeros(frameH, frameW, cv.MatType.CV_8UC1);

        if (_mode == TrackingMode.objectFocus && _targetBox != null) {
          cv.rectangle(
            mask,
            cv.Rect(
              _targetBox!.left.toInt().clamp(0, frameW),
              _targetBox!.top.toInt().clamp(0, frameH),
              _targetBox!.width.toInt().clamp(0, frameW),
              _targetBox!.height.toInt().clamp(0, frameH),
            ),
            cv.Scalar.fromRgb(255, 255, 255),
            thickness: -1,
          );
        } else {
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
      // Handle error
    } finally {
      frameGray?.dispose();
      mask?.dispose();
    }

    return {
      'points': trackedPoints,
      'vector': _smoothedVector,
      'forbiddenZones': forbiddenZones,
      'confidence': _lastConfidence,
      'inlierCount': _lastInlierCount,
      'quality': _lastQuality,
      'trackCount': trackedPoints.length,
      'trackingQuality': _featureTracker.getTrackingQuality(),
      'targetBox': _targetBox,
      'trackingMode': _mode,
      'relativeWarning': _relativeWarning,
    };
  }

  void _applyLegacySmoothing(Offset rawVector) {
    Offset targetVelocity = Offset(
      rawVector.dx - _smoothedVector.dx,
      rawVector.dy - _smoothedVector.dy,
    );
    _velocity = Offset(
      (_velocity.dx * (1 - _velAlpha)) + (targetVelocity.dx * _velAlpha),
      (_velocity.dy * (1 - _velAlpha)) + (targetVelocity.dy * _velAlpha),
    );
    _smoothedVector = Offset(
      _smoothedVector.dx + _velocity.dx * _posAlpha,
      _smoothedVector.dy + _velocity.dy * _posAlpha,
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

  void resetTracking() {
    _oldGray?.dispose();
    _oldGray = null;
    _p0?.dispose();
    _p0 = null;
    _smoothedVector = Offset.zero;
    _velocity = Offset.zero;
    _lastKnownObstacles.clear();
    _motionKalman.reset();
    _kalmanInitialized = false;
    _lastConfidence = 0.0;
    _lastInlierCount = 0;
    _lastQuality = 0.0;
    _mode = TrackingMode.environment;
    _targetBox = null;
    _relativeWarning = null;
  }

  void setTarget(Offset point, List<Rect> aiObstacles) {
    for (var box in aiObstacles) {
      if (box.contains(point)) {
        _targetBox = box;
        _mode = TrackingMode.objectFocus;
        _unmatchedYoloCount = 0;
        _p0?.dispose();
        _p0 = null;
        return;
      }
    }
    // Clicks outside reset tracking
    _mode = TrackingMode.environment;
    _targetBox = null;
    _relativeWarning = null;
    _p0?.dispose();
    _p0 = null;
  }
}
