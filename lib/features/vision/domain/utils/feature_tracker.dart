import 'dart:math' as math;
import 'dart:ui';

class TrackedPoint {
  final Offset position;
  final double quality;
  final int lifetime;
  final int gridCell;
  final int trackId;

  TrackedPoint({
    required this.position,
    required this.quality,
    required this.lifetime,
    required this.gridCell,
    required this.trackId,
  });

  TrackedPoint copyWith({
    Offset? position,
    double? quality,
    int? lifetime,
    int? gridCell,
  }) {
    return TrackedPoint(
      position: position ?? this.position,
      quality: quality ?? this.quality,
      lifetime: lifetime ?? this.lifetime,
      gridCell: gridCell ?? this.gridCell,
      trackId: trackId,
    );
  }
}

class FeatureTracker {
  static const int _gridSizeX = 4;
  static const int _gridSizeY = 3;
  static const int _maxPointsPerCell = 5;
  static const int _minPointsPerCell = 1;
  static const int _maxLifetime = 90;
  static const double _minQuality = 0.01;

  final Map<int, List<TrackedPoint>> _gridPoints = {};
  int _frameCount = 0;
  int _nextTrackId = 0;

  int _getGridCell(Offset point, int frameWidth, int frameHeight) {
    int cellX = (point.dx / frameWidth * _gridSizeX).floor().clamp(
      0,
      _gridSizeX - 1,
    );
    int cellY = (point.dy / frameHeight * _gridSizeY).floor().clamp(
      0,
      _gridSizeY - 1,
    );
    return cellY * _gridSizeX + cellX;
  }

  void initializeGrid() {
    _gridPoints.clear();
    for (int i = 0; i < _gridSizeX * _gridSizeY; i++) {
      _gridPoints[i] = [];
    }
    _nextTrackId = 0;
  }

  void updatePoints(
    List<Offset> newPositions,
    List<double> qualities,
    int frameWidth,
    int frameHeight,
  ) {
    _frameCount++;

    Map<int, List<TrackedPoint>> newGridPoints = {};
    for (int i = 0; i < _gridSizeX * _gridSizeY; i++) {
      newGridPoints[i] = [];
    }

    for (int i = 0; i < newPositions.length && i < qualities.length; i++) {
      int cell = _getGridCell(newPositions[i], frameWidth, frameHeight);

      TrackedPoint? existingPoint = _findExistingPoint(cell, newPositions[i]);

      TrackedPoint newPoint;
      if (existingPoint != null) {
        newPoint = existingPoint.copyWith(
          position: newPositions[i],
          quality: math.max(
            existingPoint.quality,
            qualities[i] * 0.8 + existingPoint.quality * 0.2,
          ),
          lifetime: existingPoint.lifetime + 1,
        );
      } else {
        newPoint = TrackedPoint(
          position: newPositions[i],
          quality: qualities[i],
          lifetime: 1,
          gridCell: cell,
          trackId: _nextTrackId++,
        );
      }

      newGridPoints[cell]!.add(newPoint);
    }

    for (int cell = 0; cell < _gridSizeX * _gridSizeY; cell++) {
      List<TrackedPoint> cellPoints = newGridPoints[cell]!;

      cellPoints.removeWhere((p) => p.lifetime > _maxLifetime);
      cellPoints.removeWhere((p) => p.quality < _minQuality);

      cellPoints.sort((a, b) => b.quality.compareTo(a.quality));
      if (cellPoints.length > _maxPointsPerCell) {
        cellPoints = cellPoints.sublist(0, _maxPointsPerCell);
      }

      newGridPoints[cell] = cellPoints;
    }

    for (int cell = 0; cell < _gridSizeX * _gridSizeY; cell++) {
      _gridPoints[cell] = newGridPoints[cell]!;
    }
  }

  TrackedPoint? _findExistingPoint(int cell, Offset newPosition) {
    List<TrackedPoint>? cellPoints = _gridPoints[cell];
    if (cellPoints == null) return null;

    const double threshold = 15.0;

    for (var point in cellPoints) {
      double dx = (point.position.dx - newPosition.dx).abs();
      double dy = (point.position.dy - newPosition.dy).abs();
      if (dx < threshold && dy < threshold) {
        return point;
      }
    }

    return null;
  }

  List<Offset> getAllPoints() {
    List<Offset> points = [];
    for (var cellPoints in _gridPoints.values) {
      for (var p in cellPoints) {
        points.add(p.position);
      }
    }
    return points;
  }

  List<TrackedPoint> getAllTrackedPoints() {
    List<TrackedPoint> points = [];
    for (var cellPoints in _gridPoints.values) {
      points.addAll(cellPoints);
    }
    return points;
  }

  List<int> getCellsNeedingPoints(int frameWidth, int frameHeight) {
    List<int> needPoints = [];
    for (int cell = 0; cell < _gridSizeX * _gridSizeY; cell++) {
      List<TrackedPoint>? cellPoints = _gridPoints[cell];
      if (cellPoints == null || cellPoints.length < _minPointsPerCell) {
        needPoints.add(cell);
      }
    }
    return needPoints;
  }

  double getTrackingQuality() {
    int totalCells = _gridSizeX * _gridSizeY;
    int activeCells = 0;
    double totalQuality = 0.0;
    int pointCount = 0;

    for (var cellPoints in _gridPoints.values) {
      if (cellPoints.isNotEmpty) {
        activeCells++;
        for (var p in cellPoints) {
          totalQuality += p.quality;
          pointCount++;
        }
      }
    }

    double coverageScore = activeCells / totalCells;
    double qualityScore = pointCount > 0 ? totalQuality / pointCount : 0.0;

    return (coverageScore * 0.4 + qualityScore * 0.6).clamp(0.0, 1.0);
  }

  int getTotalPointCount() {
    int count = 0;
    for (var cellPoints in _gridPoints.values) {
      count += cellPoints.length;
    }
    return count;
  }

  Map<String, dynamic> getStats() {
    return {
      'totalPoints': getTotalPointCount(),
      'activeCells': _gridPoints.values.where((p) => p.isNotEmpty).length,
      'totalCells': _gridSizeX * _gridSizeY,
      'quality': getTrackingQuality(),
      'frameCount': _frameCount,
    };
  }

  void reset() {
    for (int i = 0; i < _gridSizeX * _gridSizeY; i++) {
      _gridPoints[i] = [];
    }
    _frameCount = 0;
    _nextTrackId = 0;
  }
}
