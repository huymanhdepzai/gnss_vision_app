class AppConstants {
  AppConstants._();

  static const String appName = 'Vision Flow';
  static const String appVersion = '1.0.0';

  // Video Processing
  static const int defaultFps = 30;
  static const int aiProcessInterval = 10;
  static const int maxTrackPoints = 60;
  static const int minTrackPoints = 30;

  // AI Detection
  static const double yoloConfidenceThreshold = 0.2;
  static const double yoloIouThreshold = 0.4;
  static const String yoloModelPath = 'assets/yolov8n.tflite';
  static const String yoloLabelsPath = 'assets/labels.txt';

  // Sensor Fusion
  static const double kalmanProcessNoise = 0.08;
  static const double kalmanMeasurementNoise = 1.5;
  static const double gpsAccuracyThreshold = 10.0;
  static const double bumpAccelerationThreshold = 3.0;

  // RANSAC
  static const int ransacIterations = 80;
  static const double ransacThreshold = 4.0;
  static const int ransacMinInliers = 8;

  // Feature Tracking
  static const int gridCellsX = 4;
  static const int gridCellsY = 3;
  static const int maxPointsPerCell = 5;
  static const int maxFeatureLifetime = 90;

  // Voice
  static const Duration minVoiceInterval = Duration(seconds: 2);
  static const Duration urgentVoiceInterval = Duration(seconds: 1);

  // Animation Durations
  static const Duration fadeAnimationDuration = Duration(milliseconds: 800);
  static const Duration slideAnimationDuration = Duration(milliseconds: 600);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 1500);

  // Cache
  static const Duration cacheExpiration = Duration(hours: 24);
  static const int maxCacheSize = 100;
}

class TargetVehicles {
  TargetVehicles._();

  static const List<String> vehicleClasses = [
    'car',
    'motorcycle',
    'bus',
    'truck',
    'person',
    'bicycle',
  ];
}
