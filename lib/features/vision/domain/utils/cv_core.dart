import 'dart:ui';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class CVCore {
  cv.Mat? _oldGray;
  cv.VecPoint2f? _p0;
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

  CVCore();

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
            double sumDx = 0;
            double sumDy = 0;
            int count = 0;
            for (int i = 0; i < oldPointsForRansac.length; i++) {
              sumDx += newPointsForRansac[i].dx - oldPointsForRansac[i].dx;
              sumDy += newPointsForRansac[i].dy - oldPointsForRansac[i].dy;
              count++;
            }
            if (count > 0) {
              rawMoveVector = Offset(sumDx / count, sumDy / count);
              _lastConfidence = count / 60.0;
              _lastInlierCount = count;
              _lastQuality = _lastConfidence;
            }
          }

          p1.dispose();
          status.dispose();
          err?.dispose();
        }
      }

      int targetPoints = 60;
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

      // Apply smoothing
      Offset targetVelocity = Offset(
        rawMoveVector.dx - _smoothedVector.dx,
        rawMoveVector.dy - _smoothedVector.dy,
      );
      _velocity = Offset(
        (_velocity.dx * (1 - _velAlpha)) + (targetVelocity.dx * _velAlpha),
        (_velocity.dy * (1 - _velAlpha)) + (targetVelocity.dy * _velAlpha),
      );
      _smoothedVector = Offset(
        _smoothedVector.dx + _velocity.dx * _posAlpha,
        _smoothedVector.dy + _velocity.dy * _posAlpha,
      );

      if (_oldGray != null) _oldGray!.dispose();
      _oldGray = frameGray.clone();
    } catch (e) {
      // Handle error silently
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
    };
  }

  void resetTracking() {
    _oldGray?.dispose();
    _oldGray = null;
    _p0?.dispose();
    _p0 = null;
    _smoothedVector = Offset.zero;
    _velocity = Offset.zero;
    _lastKnownObstacles.clear();
    _kalmanInitialized = false;
    _lastConfidence = 0.0;
    _lastInlierCount = 0;
    _lastQuality = 0.0;
  }
}
