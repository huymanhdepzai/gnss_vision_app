import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Class mang dữ liệu từ Isolate về Controller
class IsolateResult {
  final Uint8List? imageBytes;
  final List<Offset> points;
  final List<Rect> forbiddenZones;
  final Offset moveVector;
  final double currentFrame;
  final Size imageSize;
  final double confidence;
  final int inlierCount;
  final double quality;
  final int trackCount;
  final List<String> detectedLabels;
  final Rect? targetBox;

  IsolateResult({
    required this.imageBytes,
    required this.points,
    required this.forbiddenZones,
    required this.moveVector,
    required this.currentFrame,
    required this.imageSize,
    this.confidence = 0.5,
    this.inlierCount = 0,
    this.quality = 0.5,
    this.trackCount = 0,
    this.detectedLabels = const [],
    this.targetBox,
  });
}

/// Các lệnh gửi tới Isolate
class IsolateCommand {
  final String type; // 'START', 'PAUSE', 'RESUME', 'SEEK', 'STOP', 'CAMERA_FRAME', 'SET_TARGET'
  final String? path;
  final double? value;
  final List<Rect>? aiObstacles;
  final Uint8List? imageData;
  final int? width;
  final int? height;
  final Offset? point;

  IsolateCommand(this.type, {
    this.path, 
    this.value, 
    this.aiObstacles, 
    this.imageData,
    this.width,
    this.height,
    this.point,
  });
}

class DetectedObject {
  final Rect rect;
  final String label;
  DetectedObject({required this.rect, required this.label});
}
