import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:flutter_vision/flutter_vision.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:camera/camera.dart';

import '../../domain/utils/cv_core.dart';
import '../../domain/utils/sensor_fusion.dart';
import '../../../../shared/data/services/voice_feedback_service.dart';

import 'vision_isolate_models.dart';

class CameraFlowController extends ChangeNotifier {
  // ================= NOTIFIERS =================
  final ValueNotifier<Uint8List?> frameNotifier = ValueNotifier<Uint8List?>(
    null,
  );
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> headingNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> turnIntensityNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);

  // ================= MODULES =================
  final SensorFusion fusionCore = SensorFusion();
  final VoiceFeedbackService voiceFeedback = VoiceFeedbackService();
  late FlutterVision vision;

  // ================= CAMERA =================
  CameraController? _cameraController;
  CameraController? get cameraController => _cameraController;
  bool isUsingCamera = false;
  bool _isProcessingCameraFrame = false;

  // ================= ISOLATE =================
  Isolate? _workerIsolate;
  SendPort? _toWorkerPort;
  final ReceivePort _fromWorkerPort = ReceivePort();

  // ================= TRẠNG THÁI =================
  bool isDemoMode = true; // Mặc định bật demo để phục vụ FlowPage
  bool isModelLoaded = false;
  bool hasValidGps = false;
  bool isPlaying = false;
  bool isPaused = false;
  bool voiceEnabled = true;

  double totalFrames = 1.0;
  double fps = 30.0;
  double playbackSpeed = 1.0;
  Size imageSize = Size.zero;
  List<Offset> pointsToDraw = [];
  final ValueNotifier<List<DetectedObject>> aiObstaclesNotifier = ValueNotifier<List<DetectedObject>>([]);
  List<Rect> get aiObstacles => aiObstaclesNotifier.value.map((e) => e.rect).toList();
  List<Rect>? staticRois;
  List<Rect> forbiddenZones = [];

  double currentGpsHeading = 0.0;
  double currentGpsSpeed = 0.0;
  double currentGpsAccuracy = 0.0;
  double currentImuAccelY = 0.0;
  double finalFusedHeading = 0.0;

  final List<String> targetVehicles = [
    'car',
    'motorcycle',
    'bus',
    'truck',
    'person',
    'bicycle',
    'traffic light',
    'stop sign',
    'fire hydrant',
    'bench',
    'dog',
    'cat',
  ];
  StreamSubscription<Position>? gpsSubscription;
  StreamSubscription<UserAccelerometerEvent>? imuSubscription;

  // ================= INIT =================
  Future<void> init() async {
    vision = FlutterVision();
    
    try {
      await _loadYoloModel();
    } catch (e) {
      debugPrint("Lỗi khi load YOLO model: $e");
    }

    try {
      await _initSensors();
    } catch (e) {
      debugPrint("Lỗi khi khởi tạo Sensors: $e");
    }

    try {
      await voiceFeedback.initialize();
    } catch (e) {
      debugPrint("Lỗi khi khởi tạo Voice Feedback: $e");
    }

    try {
      await _startWorkerIsolate();
    } catch (e) {
      debugPrint("Lỗi khi khởi tạo Isolate: $e");
    }
  }

  Future<void> _startWorkerIsolate() async {
    final ReceivePort errorPort = ReceivePort();
    errorPort.listen((message) {
      debugPrint("Worker Isolate Crashed: $message");
    });

    _workerIsolate = await Isolate.spawn(
      _videoWorker,
      _fromWorkerPort.sendPort,
      onError: errorPort.sendPort,
    );
    _fromWorkerPort.listen((message) {
      if (message is SendPort) {
        debugPrint("Đã nhận SendPort từ Isolate!");
        _toWorkerPort = message;
      } else if (message is IsolateResult) {
        _handleFrameResult(message);
      } else if (message is Map<String, dynamic>) {
        if (message['type'] == 'METADATA') {
          totalFrames = message['totalFrames'];
          fps = message['fps'];
          notifyListeners();
        } else if (message['type'] == 'ERROR') {
          debugPrint("Worker Isolate Error: ${message['message']}");
          isPlaying = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> _loadYoloModel() async {
    await vision.loadYoloModel(
      labels: 'assets/labels.txt',
      modelPath: 'assets/yolov8n_float16.tflite',
      modelVersion: "yolov8",
      numThreads: 4,
      useGpu: true,
    );
    isModelLoaded = true;
    notifyListeners();
  }

  Future<void> _initSensors() async {
    if (isDemoMode) {
      hasValidGps = true;
      currentGpsHeading = 0.0;
      currentGpsAccuracy = 5.0;
      fusionCore.reset(currentGpsHeading);
      notifyListeners();
      return;
    }

    imuSubscription =
        userAccelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen((event) {
          currentImuAccelY = event.y;
        });

    gpsSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1,
          ),
        ).listen((Position position) {
          hasValidGps = true;
          currentGpsSpeed = position.speed;
          currentGpsAccuracy = position.accuracy;
          if (position.speed > 1.0) currentGpsHeading = position.heading;
          speedNotifier.value = currentGpsSpeed;
          notifyListeners();
        });
  }

  // ================= XỬ LÝ KẾT QUẢ TỪ ISOLATE =================
  int _frameCounter = 0;
  bool _isAiBusy = false;
  int _consecutiveEmptyAiRuns = 0;

  void _handleFrameResult(IsolateResult res) async {
    _frameCounter++;
    pointsToDraw = res.points;
    imageSize = res.imageSize;

    // AI chạy cực nhanh: Mỗi 2 frame để bám sát video nhất có thể
    if (_frameCounter % 2 == 0 && res.imageBytes != null && !_isAiBusy) {
      _runAI(res.imageBytes!, res.imageSize);
    }

    finalFusedHeading = fusionCore.update(
      visionDx: res.moveVector.dx,
      gpsHeading: currentGpsHeading,
      imuAccelY: currentImuAccelY,
      hasValidGps: hasValidGps,
      trackedPointsCount: res.points.length,
      gpsAccuracy: currentGpsAccuracy,
      visionConfidence: res.confidence,
      visionQuality: res.quality,
    );

    if (!isUsingCamera) {
      frameNotifier.value = res.imageBytes;
    }
    headingNotifier.value = finalFusedHeading;
    turnIntensityNotifier.value = (res.moveVector.dx / 20).clamp(-1.0, 1.0);
    progressNotifier.value = res.currentFrame;
    
    // Đảm bảo UI cập nhật các thuộc tính khác (imageSize, pointsToDraw, ...)
    notifyListeners();
  }

  Future<void> _runAI(Uint8List bytes, Size size) async {
    _isAiBusy = true;
    try {
      final result = await vision.yoloOnImage(
        bytesList: bytes,
        imageHeight: size.height.toInt(),
        imageWidth: size.width.toInt(),
        iouThreshold: 0.4,
        confThreshold: 0.25,
      );

      List<DetectedObject> detected = [];
      List<String> detectedLabels = [];

      for (var obj in result) {
        List<dynamic> box = obj['box'];
        String tag = obj['tag'].toString().trim().toLowerCase();
        if (targetVehicles.contains(tag)) {
          detected.add(
            DetectedObject(
              rect: Rect.fromLTRB(
                box[0].toDouble(),
                box[1].toDouble(),
                box[2].toDouble(),
                box[3].toDouble(),
              ),
              label: tag,
            ),
          );
          detectedLabels.add(tag);
        }
      }

      bool wasEmpty = aiObstaclesNotifier.value.isEmpty;
      
      if (detected.isNotEmpty) {
        _consecutiveEmptyAiRuns = 0;
        aiObstaclesNotifier.value = detected;
        _toWorkerPort?.send(IsolateCommand('AI_UPDATE', aiObstacles: aiObstacles));
      } else {
        _consecutiveEmptyAiRuns++;
        if (_consecutiveEmptyAiRuns >= 1 && aiObstaclesNotifier.value.isNotEmpty) {
          aiObstaclesNotifier.value = [];
          _toWorkerPort?.send(IsolateCommand('AI_UPDATE', aiObstacles: []));
        }
      }

      if (voiceEnabled && detected.isNotEmpty && wasEmpty) {
        voiceFeedback.alertObstacle(
          count: detected.length,
          labels: detectedLabels,
        );
      }
    } catch (e) {
      debugPrint("Lỗi chạy AI: $e");
    } finally {
      _isAiBusy = false;
    }
  }

  // ================= ĐIỀU KHIỂN =================
  Future<void> startCamera() async {
    if (_cameraController != null) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      isUsingCamera = true;
      isPlaying = true;
      isPaused = false;
      
      _toWorkerPort?.send(IsolateCommand('CAMERA_START'));

      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessingCameraFrame || _toWorkerPort == null) return;
        _isProcessingCameraFrame = true;

        final bytes = image.planes[0].bytes;
        _toWorkerPort?.send(IsolateCommand(
          'CAMERA_FRAME',
          imageData: bytes,
          width: image.width,
          height: image.height,
        ));
        
        _isProcessingCameraFrame = false;
      });
      
      notifyListeners();
    } catch (e) {
      debugPrint("Lỗi khởi tạo camera: $e");
    }
  }

  Future<void> stopCamera() async {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }
    isUsingCamera = false;
    isPlaying = false;
    _toWorkerPort?.send(IsolateCommand('STOP'));
    notifyListeners();
  }









  void resetTracking() {
    _toWorkerPort?.send(IsolateCommand('RESET'));
  }

  void toggleVoice() {
    voiceEnabled = !voiceEnabled;
    voiceFeedback.setEnabled(voiceEnabled);
    notifyListeners();
  }

  String formatTime(double currentFrame, double fps) {
    if (fps <= 0) return "00:00";
    int sec = (currentFrame / fps).floor();
    int m = sec ~/ 60;
    int s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    stopCamera();
    _toWorkerPort?.send(IsolateCommand('STOP'));
    _fromWorkerPort.close();
    _workerIsolate?.kill();
    vision.closeYoloModel();
    gpsSubscription?.cancel();
    imuSubscription?.cancel();
    voiceFeedback.dispose();
    super.dispose();
  }

  // ================= WORKER ISOLATE (HÀM TÁCH BIỆT) =================
  static void _videoWorker(SendPort mainSendPort) {
    print("Worker Isolate: Đang khởi động...");
    final ReceivePort workerReceivePort = ReceivePort();
    mainSendPort.send(workerReceivePort.sendPort);
    print("Worker Isolate: Đã gửi SendPort về Main Isolate.");

    cv.VideoCapture? cap;
    CVCore? cvCore;
    try {
      cvCore = CVCore();
      print("Worker Isolate: Khởi tạo CVCore thành công.");
    } catch (e) {
      print("Worker Isolate: Lỗi khởi tạo CVCore: $e");
    }
    
    bool isPlaying = false;
    bool isPaused = false;
    bool isCamera = false;
    double speed = 1.0;
    List<Rect> obstacles = [];

    workerReceivePort.listen((message) async {
      if (message is IsolateCommand) {
        switch (message.type) {
            case 'START':
            // Removed
            break;
          case 'CAMERA_START':
            isCamera = true;
            isPlaying = true;
            isPaused = false;
            cap?.release();
            cap = null;
            cvCore?.resetTracking();
            break;
          case 'CAMERA_FRAME':
            if (!isCamera || message.imageData == null) return;
            
            final frameW = message.width!;
            final frameH = message.height!;
            
            // Khởi tạo Mat từ Plane Y (Grayscale)
            cv.Mat frame = cv.Mat.fromList(frameH, frameW, cv.MatType.CV_8UC1, message.imageData!);
            
            // Resize xuống 240w để hiệu năng ổn định
            double scale = 240.0 / frameW;
            cv.Mat smallGray = cv.resize(frame, (240, (frameH * scale).toInt()));
            frame.dispose();

            // Convert sang BGR để CVCore xử lý đồng bộ
            cv.Mat smallBGR = cv.cvtColor(smallGray, cv.COLOR_GRAY2BGR);
            smallGray.dispose();

            Map<String, dynamic> cvRes = cvCore!.processFrame(
              smallBGR,
              aiObstacles: obstacles,
            );

            var (ok, encoded) = cv.imencode(".jpg", smallBGR);

            mainSendPort.send(
              IsolateResult(
                imageBytes: ok ? encoded : null,
                points: cvRes['points'] ?? [],
                forbiddenZones: cvRes['forbiddenZones'] ?? [],
                moveVector: cvRes['vector'] ?? const Offset(0, 0),
                currentFrame: 0,
                imageSize: Size(
                  smallBGR.cols.toDouble(),
                  smallBGR.rows.toDouble(),
                ),
                confidence: cvRes['confidence'] ?? 0.5,
                inlierCount: cvRes['inlierCount'] ?? 0,
                quality: cvRes['quality'] ?? 0.5,
                trackCount: cvRes['trackCount'] ?? 0,
              ),
            );

            smallBGR.dispose();
            break;
          case 'PAUSE':
            isPaused = true;
            break;
          case 'RESUME':
            isPaused = false;
            break;
          case 'SPEED':
            speed = message.value!;
            break;
          case 'AI_UPDATE':
            obstacles = message.aiObstacles!;
            break;
          case 'SEEK':
            cap?.set(cv.CAP_PROP_POS_FRAMES, message.value!);
            break;
          case 'RESET':
            cvCore?.resetTracking();
            break;
          case 'STOP':
            isPlaying = false;
            isCamera = false;
            cap?.release();
            break;
        }
      }
    });
  }

  static void _runLoop(
    cv.VideoCapture cap,
    CVCore cvCore,
    SendPort sendPort,
    bool Function() shouldRun,
    double Function() getSpeed,
    List<Rect> Function() getObstacles,
  ) async {
    while (true) {
      if (!shouldRun()) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      Stopwatch timer = Stopwatch()..start();
      var (ret, frame) = cap.read();
      if (!ret || frame.isEmpty) break;

      double scale = 240.0 / frame.cols;
      cv.Mat smallFrame = cv.resize(frame, (240, (frame.rows * scale).toInt()));
      frame.dispose();

      Map<String, dynamic> cvRes = cvCore.processFrame(
        smallFrame,
        aiObstacles: getObstacles(),
      );

      var (ok, encoded) = cv.imencode(
        ".jpg",
        smallFrame,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 50]),
      );

      sendPort.send(
        IsolateResult(
          imageBytes: ok ? encoded : null,
          points: cvRes['points'] ?? [],
          forbiddenZones: cvRes['forbiddenZones'] ?? [],
          moveVector: cvRes['vector'] ?? const Offset(0, 0),
          currentFrame: cap.get(cv.CAP_PROP_POS_FRAMES) ?? 0.0,
          imageSize: Size(
            smallFrame.cols.toDouble(),
            smallFrame.rows.toDouble(),
          ),
          confidence: cvRes['confidence'] ?? 0.5,
          inlierCount: cvRes['inlierCount'] ?? 0,
          quality: cvRes['quality'] ?? 0.5,
          trackCount: cvRes['trackCount'] ?? 0,
        ),
      );

      smallFrame.dispose();
      timer.stop();

      double currentFps = 30 * getSpeed();
      if (currentFps <= 0) currentFps = 30;
      int targetMs = (1000 / currentFps).round();
      int wait = targetMs - timer.elapsedMilliseconds;
      if (wait > 0) {
        await Future.delayed(Duration(milliseconds: wait));
      } else {
        cap.set(cv.CAP_PROP_POS_FRAMES, (cap.get(cv.CAP_PROP_POS_FRAMES) ?? 0) + 1);
        await Future.delayed(const Duration(milliseconds: 2));
      }
    }
  }
}
