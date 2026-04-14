import 'dart:ui';
import 'package:equatable/equatable.dart';

class MotionVector extends Equatable {
  final Offset vector;
  final double confidence;
  final int inlierCount;
  final double quality;

  const MotionVector({
    required this.vector,
    required this.confidence,
    required this.inlierCount,
    required this.quality,
  });

  MotionVector copyWith({
    Offset? vector,
    double? confidence,
    int? inlierCount,
    double? quality,
  }) {
    return MotionVector(
      vector: vector ?? this.vector,
      confidence: confidence ?? this.confidence,
      inlierCount: inlierCount ?? this.inlierCount,
      quality: quality ?? this.quality,
    );
  }

  double get magnitude => vector.distance;

  @override
  List<Object?> get props => [vector, confidence, inlierCount, quality];
}
