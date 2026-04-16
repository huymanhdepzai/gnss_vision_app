import 'dart:typed_data';
import 'dart:ui';
import 'package:equatable/equatable.dart';

class ObstacleModel extends Equatable {
  final Rect boundingBox;
  final String label;
  final double confidence;

  const ObstacleModel({
    required this.boundingBox,
    required this.label,
    required this.confidence,
  });

  factory ObstacleModel.fromJson(Map<String, dynamic> json) {
    final box = json['box'] as List<dynamic>;
    return ObstacleModel(
      boundingBox: Rect.fromLTRB(
        box[0].toDouble(),
        box[1].toDouble(),
        box[2].toDouble(),
        box[3].toDouble(),
      ),
      label: json['tag'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'box': [
        boundingBox.left,
        boundingBox.top,
        boundingBox.right,
        boundingBox.bottom,
      ],
      'tag': label,
      'confidence': confidence,
    };
  }

  @override
  List<Object?> get props => [boundingBox, label, confidence];
}

class MotionVectorModel extends Equatable {
  final Offset vector;
  final double confidence;
  final int inlierCount;
  final double quality;

  const MotionVectorModel({
    required this.vector,
    required this.confidence,
    required this.inlierCount,
    required this.quality,
  });

  @override
  List<Object?> get props => [vector, confidence, inlierCount, quality];
}

class FrameResultModel extends Equatable {
  final Uint8List? imageBytes;
  final List<Offset> trackedPoints;
  final MotionVectorModel? motionVector;
  final List<ObstacleModel> obstacles;
  final double heading;
  final double speed;
  final Size imageSize;

  const FrameResultModel({
    this.imageBytes,
    required this.trackedPoints,
    this.motionVector,
    required this.obstacles,
    required this.heading,
    required this.speed,
    required this.imageSize,
  });

  @override
  List<Object?> get props => [
    trackedPoints,
    motionVector,
    obstacles,
    heading,
    speed,
    imageSize,
  ];
}
