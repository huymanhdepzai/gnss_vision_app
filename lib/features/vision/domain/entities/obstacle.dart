import 'dart:ui';
import 'package:equatable/equatable.dart';

class Obstacle extends Equatable {
  final Rect boundingBox;
  final String label;
  final double confidence;

  const Obstacle({
    required this.boundingBox,
    required this.label,
    required this.confidence,
  });

  Obstacle copyWith({Rect? boundingBox, String? label, double? confidence}) {
    return Obstacle(
      boundingBox: boundingBox ?? this.boundingBox,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
    );
  }

  double get area => boundingBox.width * boundingBox.height;

  Offset get center => boundingBox.center;

  @override
  List<Object?> get props => [boundingBox, label, confidence];
}
