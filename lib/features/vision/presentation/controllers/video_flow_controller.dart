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

class VideoFlowController extends ChangeNotifier {
  // ================= NOTIFIERS =================
  final ValueNotifier<Uint8List?> frameNotifier = ValueNotifier<Uint8List?>(
    null,
  );
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> headingNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> turnIntensityNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<Rect?> targetBoxNotifier = ValueNotifier<Rect?>(null);
  final ValueNotifier<String?> relativeWarningNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> autoFocusEnabledNotifier = ValueNotifier<bool>(false);

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
          if (!_isDisposed) notifyListeners();
        } else if (message['type'] == 'ERROR') {
          debugPrint("Worker Isolate Error: ${message['message']}");
          isPlaying = false;
          if (!_isDisposed) notifyListeners();
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
    if (_isDisposed) return;
    _frameCounter++;
    pointsToDraw = res.points;
    imageSize = res.imageSize;

    // Chạy AI mỗi 2 frame để đảm bảo không lọt mất vật thể
    if (_frameCounter % 2 == 0 && res.imageBytes != null && !_isAiBusy) {
      _runAI(res.imageBytes!, res.imageSize);
    }

    double appliedDx = res.moveVector.dx;
    if (res.trackingMode != null && res.trackingMode.toString().contains('objectFocus')) {
      appliedDx = -appliedDx;
    }

    finalFusedHeading = fusionCore.update(
      visionDx: appliedDx,
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
    turnIntensityNotifier.value = (appliedDx / 20).clamp(-1.0, 1.0);
    progressNotifier.value = res.currentFrame;
    targetBoxNotifier.value = res.targetBox;
    relativeWarningNotifier.value = res.relativeWarning;
    
    if (autoFocusEnabledNotifier.value && res.targetBox == null && aiObstaclesNotifier.value.isNotEmpty) {
      DetectedObject? bestObj;
      double maxScore = -1.0;
      final centerX = res.imageSize.width / 2;
      final centerY = res.imageSize.height / 2;

      for (var obj in aiObstaclesNotifier.value) {
        if (obj.confidence < 0.35) continue; // Bỏ qua nếu độ tin cậy quá thấp

        double confScore = obj.confidence;

        // Điểm vị trí trung tâm (ưu tiên vật nằm giữa màn hình, đặc biệt là theo trục ngang)
        double distX = (obj.rect.center.dx - centerX).abs() / centerX;
        double distY = (obj.rect.center.dy - centerY).abs() / centerY;
        double centerScore = 1.0 - (distX * 0.7 + distY * 0.3).clamp(0.0, 1.0);

        // Điểm kích thước (xe càng to tức là càng gần)
        double sizeScore = (obj.rect.width / res.imageSize.width).clamp(0.0, 1.0);

        // Công thức trọng số
        double finalScore = (confScore * 0.4) + (centerScore * 0.4) + (sizeScore * 0.2);

        if (finalScore > maxScore) {
          maxScore = finalScore;
          bestObj = obj;
        }
      }

      if (bestObj != null) {
        setTarget(bestObj.rect.center.dx, bestObj.rect.center.dy);
      }
    }

    // Đảm bảo UI cập nhật các thuộc tính khác (imageSize, pointsToDraw, ...)
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _runAI(Uint8List bytes, Size size) async {
    if (_isDisposed) return;
    _isAiBusy = true;
    try {
      final result = await vision.yoloOnImage(
        bytesList: bytes,
        imageHeight: size.height.toInt(),
        imageWidth: size.width.toInt(),
        iouThreshold: 0.4,
        confThreshold: 0.25,
      );

      if (_isDisposed) return;

      List<DetectedObject> detected = [];
      List<String> detectedLabels = [];

      for (var obj in result) {
        List<dynamic> box = obj['box'];
        double conf = box.length > 4 ? box[4].toDouble() : 0.0;
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
              confidence: conf,
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
        // Tăng giới hạn chịu đựng lên 3 lần AI rỗng liên tiếp mới xóa box
        if (_consecutiveEmptyAiRuns >= 3 && aiObstaclesNotifier.value.isNotEmpty) {
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



  Future<void> playVideo(String path) async {
    
    // Đảm bảo Isolate đã sẵn sàng
    int waitCount = 0;
    while (_toWorkerPort == null && waitCount < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    if (_toWorkerPort == null) {
      debugPrint("Lỗi: Isolate chưa sẵn sàng");
      return;
    }
    
    isPlaying = true;
    isPaused = false;
    _toWorkerPort?.send(IsolateCommand('START', path: path));
    notifyListeners();
  }

  Future<void> pickAndPlayVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      await playVideo(video.path);
    }
  }

  void togglePause() {
    if (isUsingCamera) return;
    isPaused = !isPaused;
    _toWorkerPort?.send(IsolateCommand(isPaused ? 'PAUSE' : 'RESUME'));
    notifyListeners();
  }

  void seekTo(double val) {
    if (isUsingCamera) return;
    _toWorkerPort?.send(IsolateCommand('SEEK', value: val));
  }

  void cycleSpeed() {
    if (isUsingCamera) return;
    if (playbackSpeed == 1.0) {
      playbackSpeed = 1.5;
    } else if (playbackSpeed == 1.5) {
      playbackSpeed = 2.0;
    } else if (playbackSpeed == 2.0) {
      playbackSpeed = 0.5;
    } else {
      playbackSpeed = 1.0;
    }
    _toWorkerPort?.send(IsolateCommand('SPEED', value: playbackSpeed));
    notifyListeners();
  }

  void resetTracking() {
    _toWorkerPort?.send(IsolateCommand('RESET'));
  }

  void setTarget(double x, double y) {
    if (isUsingCamera) return;
    _toWorkerPort?.send(IsolateCommand('SET_TARGET', point: Offset(x, y)));
  }

  void toggleVoice() {
    voiceEnabled = !voiceEnabled;
    voiceFeedback.setEnabled(voiceEnabled);
    notifyListeners();
  }

  void toggleAutoFocus() {
    autoFocusEnabledNotifier.value = !autoFocusEnabledNotifier.value;
    notifyListeners();
  }

  String formatTime(double currentFrame, double fps) {
    if (fps <= 0) return "00:00";
    int sec = (currentFrame / fps).floor();
    int m = sec ~/ 60;
    int s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _toWorkerPort?.send(IsolateCommand('STOP'));
    _fromWorkerPort.close();
    _workerIsolate?.kill(priority: Isolate.immediate);
    gpsSubscription?.cancel();
    imuSubscription?.cancel();
    voiceFeedback.dispose();
    
    _safeDisposeVision();
    super.dispose();
  }

  Future<void> _safeDisposeVision() async {
    // Chờ AI xử lý xong (tối đa 2s) trước khi close model để tránh crash native
    int waitMs = 0;
    while (_isAiBusy && waitMs < 2000) {
      await Future.delayed(const Duration(milliseconds: 50));
      waitMs += 50;
    }
    try {
      await vision.closeYoloModel();
    } catch (e) {
      debugPrint("Lỗi khi đóng YOLO model: $e");
    }
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
            isCamera = false;
            cap?.release();
            cap = cv.VideoCapture.fromFile(message.path!);
            if (cap!.isOpened) {
              isPlaying = true;
              mainSendPort.send({
                'type': 'METADATA',
                'totalFrames': cap!.get(cv.CAP_PROP_FRAME_COUNT) ?? 0.0,
                'fps': cap!.get(cv.CAP_PROP_FPS) ?? 30.0,
              });
              _runLoop(
                cap!,
                cvCore!,
                mainSendPort,
                () => isPlaying && !isPaused && !isCamera,
                () => speed,
                () => obstacles,
              );
            } else {
              mainSendPort.send({
                'type': 'ERROR',
                'message': 'Không thể mở video tại ${message.path}',
              });
            }
            break;
          case 'CAMERA_START':
            // Removed
            break;
          case 'CAMERA_FRAME':
            // Removed
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
          case 'SET_TARGET':
            if (message.point != null) {
              cvCore?.setTarget(message.point!, obstacles);
            }
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

      // Tăng độ phân giải lên 640px để hình ảnh rõ nét hơn (gốc là 240px)
      double scale = 640.0 / frame.cols;
      cv.Mat smallFrame = cv.resize(frame, (640, (frame.rows * scale).toInt()));
      frame.dispose();

      Map<String, dynamic> cvRes = cvCore.processFrame(
        smallFrame,
        aiObstacles: getObstacles(),
      );

      // Tăng chất lượng nén JPEG lên 75 (gốc là 50)
      var (ok, encoded) = cv.imencode(
        ".jpg",
        smallFrame,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 75]),
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
          targetBox: cvRes['targetBox'],
          trackingMode: cvRes['trackingMode'],
          relativeWarning: cvRes['relativeWarning'],
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
        cap.grab(); // Fast forward 1 frame without decoding
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }
  }
}
