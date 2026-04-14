import 'dart:math' as math;
import 'dart:ui';

class MotionEstimator {
  static const int _ransacIterations = 80;
  static const double _ransacThreshold = 4.0;
  static const int _minInliers = 8;

  final math.Random _random = math.Random(42);

  ({Offset vector, int inliers, double confidence, double quality})
  estimateMotion(List<Offset> oldPoints, List<Offset> newPoints) {
    if (oldPoints.length < _minInliers || newPoints.length < _minInliers) {
      return (vector: Offset.zero, inliers: 0, confidence: 0.0, quality: 0.0);
    }

    List<int> bestInliers = [];
    Offset bestMotion = Offset.zero;
    double bestError = double.infinity;

    for (int iter = 0; iter < _ransacIterations; iter++) {
      int idx = _random.nextInt(oldPoints.length);

      Offset sampleMotion = Offset(
        oldPoints[idx].dx - newPoints[idx].dx,
        oldPoints[idx].dy - newPoints[idx].dy,
      );

      List<int> currentInliers = [];
      double totalError = 0.0;

      for (int i = 0; i < oldPoints.length; i++) {
        double errorX = (oldPoints[i].dx - newPoints[i].dx - sampleMotion.dx)
            .abs();
        double errorY = (oldPoints[i].dy - newPoints[i].dy - sampleMotion.dy)
            .abs();
        double error = math.sqrt(errorX * errorX + errorY * errorY);

        if (error < _ransacThreshold) {
          currentInliers.add(i);
          totalError += error;
        }
      }

      if (currentInliers.length > bestInliers.length ||
          (currentInliers.length == bestInliers.length &&
              totalError < bestError)) {
        bestInliers = currentInliers;
        bestMotion = sampleMotion;
        bestError = totalError;
      }
    }

    if (bestInliers.isNotEmpty && bestInliers.length >= _minInliers) {
      double sumDx = 0;
      double sumDy = 0;
      double sumWeight = 0;

      for (int i in bestInliers) {
        double errorX = (oldPoints[i].dx - newPoints[i].dx - bestMotion.dx)
            .abs();
        double errorY = (oldPoints[i].dy - newPoints[i].dy - bestMotion.dy)
            .abs();
        double error = math.sqrt(errorX * errorX + errorY * errorY);

        double weight = 1.0 / (1.0 + error);

        sumDx += (oldPoints[i].dx - newPoints[i].dx) * weight;
        sumDy += (oldPoints[i].dy - newPoints[i].dy) * weight;
        sumWeight += weight;
      }

      if (sumWeight > 0) {
        bestMotion = Offset(sumDx / sumWeight, sumDy / sumWeight);
      }
    }

    double inlierRatio = bestInliers.length / oldPoints.length;
    double motionMagnitude = math.sqrt(
      bestMotion.dx * bestMotion.dx + bestMotion.dy * bestMotion.dy,
    );

    double confidence = inlierRatio * math.min(motionMagnitude / 3.0, 1.0);
    double quality =
        inlierRatio *
        (bestInliers.length >= _minInliers
            ? 1.0
            : bestInliers.length / _minInliers);

    return (
      vector: bestMotion,
      inliers: bestInliers.length,
      confidence: confidence.clamp(0.0, 1.0),
      quality: quality.clamp(0.0, 1.0),
    );
  }

  List<Offset> filterOutliers(
    List<Offset> oldPoints,
    List<Offset> newPoints,
    Offset expectedMotion,
    double threshold,
  ) {
    List<Offset> filtered = [];

    for (int i = 0; i < oldPoints.length && i < newPoints.length; i++) {
      double errorX = (oldPoints[i].dx - newPoints[i].dx - expectedMotion.dx)
          .abs();
      double errorY = (oldPoints[i].dy - newPoints[i].dy - expectedMotion.dy)
          .abs();

      if (errorX < threshold && errorY < threshold) {
        filtered.add(newPoints[i]);
      }
    }

    return filtered;
  }

  ({List<int> indices, double variance}) computeMotionStatistics(
    List<Offset> oldPoints,
    List<Offset> newPoints,
    Offset medianMotion,
  ) {
    if (oldPoints.isEmpty) {
      return (indices: <int>[], variance: 0.0);
    }

    List<double> magnitudes = [];
    List<int> validIndices = [];

    for (int i = 0; i < oldPoints.length && i < newPoints.length; i++) {
      double dx = oldPoints[i].dx - newPoints[i].dx;
      double dy = oldPoints[i].dy - newPoints[i].dy;
      double error = math.sqrt(
        (dx - medianMotion.dx) * (dx - medianMotion.dx) +
            (dy - medianMotion.dy) * (dy - medianMotion.dy),
      );

      if (error < _ransacThreshold * 2) {
        magnitudes.add(math.sqrt(dx * dx + dy * dy));
        validIndices.add(i);
      }
    }

    if (magnitudes.isEmpty) {
      return (indices: validIndices, variance: 0.0);
    }

    double mean = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    double variance =
        magnitudes.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) /
        magnitudes.length;

    return (indices: validIndices, variance: variance);
  }
}
