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

import '../vision/cv_core.dart';
import '../fusion/sensor_fusion.dart';

/// Class mang dữ liệu từ Isolate về Controller
class IsolateResult {
  final Uint8List? imageBytes;
  final List<Offset> points;
  final List<Rect> forbiddenZones;
  final Offset moveVector;
  final double currentFrame;
  final Size imageSize;

  IsolateResult({
    required this.imageBytes,
    required this.points,
    required this.forbiddenZones,
    required this.moveVector,
    required this.currentFrame,
    required this.imageSize,
  });
}

/// Các lệnh gửi tới Isolate
class IsolateCommand {
  final String type; // 'START', 'PAUSE', 'RESUME', 'SEEK', 'STOP'
  final String? path;
  final double? value;
  final List<Rect>? aiObstacles;

  IsolateCommand(this.type, {this.path, this.value, this.aiObstacles});
}

class FlowController extends ChangeNotifier {
  // ================= NOTIFIERS =================
  final ValueNotifier<Uint8List?> frameNotifier = ValueNotifier<Uint8List?>(null);
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> headingNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);


  // ================= MODULES =================
  final SensorFusion fusionCore = SensorFusion();
  late FlutterVision vision;
  
  // ================= ISOLATE =================
  Isolate? _workerIsolate;
  SendPort? _toWorkerPort;
  final ReceivePort _fromWorkerPort = ReceivePort();

  // ================= TRẠNG THÁI =================
  final bool isDemoMode = true;
  bool isModelLoaded = false;
  bool hasValidGps = false;
  bool isPlaying = false;
  bool isPaused = false;
  
  double totalFrames = 1.0;
  double fps = 30.0;
  double playbackSpeed = 1.0;
  Size imageSize = Size.zero;
  List<Offset> pointsToDraw = [];
  List<Rect>? staticRois;
  List<Rect> aiObstacles = [];
  List<Rect> forbiddenZones = [];
  
  double currentGpsHeading = 0.0;
  double currentGpsSpeed = 0.0;
  double currentGpsAccuracy = 0.0;
  double currentImuAccelY = 0.0;
  double finalFusedHeading = 0.0;

  final List<String> targetVehicles = ['car', 'motorcycle', 'bus', 'truck', 'person', 'bicycle'];
  StreamSubscription<Position>? gpsSubscription;
  StreamSubscription<UserAccelerometerEvent>? imuSubscription;

  // ================= INIT =================
  Future<void> init() async {
    vision = FlutterVision();
    await _loadYoloModel();
    await _initSensors();
    await _startWorkerIsolate();
  }

  Future<void> _startWorkerIsolate() async {
    _workerIsolate = await Isolate.spawn(_videoWorker, _fromWorkerPort.sendPort);
    _fromWorkerPort.listen((message) {
      if (message is SendPort) {
        _toWorkerPort = message;
      } else if (message is IsolateResult) {
        _handleFrameResult(message);
      } else if (message is Map<String, dynamic> && message['type'] == 'METADATA') {
        totalFrames = message['totalFrames'];
        fps = message['fps'];
        notifyListeners();
      }
    });
  }

  Future<void> _loadYoloModel() async {
    await vision.loadYoloModel(
      labels: 'assets/labels.txt',
      modelPath: 'assets/yolov8n.tflite',
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

    imuSubscription = userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((event) {
      currentImuAccelY = event.y;
    });

    gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1)
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
  
  void _handleFrameResult(IsolateResult res) async {
    _frameCounter++;
    pointsToDraw = res.points;
    imageSize = res.imageSize;
    
    // Chạy AI trên Isolate chính (vì plugin vision thường không chạy được trong background isolate)
    // Nhưng chỉ chạy mỗi 10 frame để không gây lag
    if (_frameCounter % 10 == 0 && res.imageBytes != null) {
      _runAI(res.imageBytes!, res.imageSize);
    }

    finalFusedHeading = fusionCore.update(
      visionDx: res.moveVector.dx,
      gpsHeading: currentGpsHeading,
      imuAccelY: currentImuAccelY,
      hasValidGps: hasValidGps,
      trackedPointsCount: res.points.length,
      gpsAccuracy: currentGpsAccuracy,
    );

    frameNotifier.value = res.imageBytes;
    headingNotifier.value = finalFusedHeading;
    progressNotifier.value = res.currentFrame;
  }

  Future<void> _runAI(Uint8List bytes, Size size) async {
    final result = await vision.yoloOnImage(
      bytesList: bytes, imageHeight: size.height.toInt(), imageWidth: size.width.toInt(),
      iouThreshold: 0.4, confThreshold: 0.2,
    );

    List<Rect> detected = [];
    for (var obj in result) {
      List<dynamic> box = obj['box'];
      String tag = obj['tag'].toString().trim().toLowerCase();
      if (targetVehicles.contains(tag)) {
        detected.add(Rect.fromLTRB(box[0].toDouble(), box[1].toDouble(), box[2].toDouble(), box[3].toDouble()));
      }
    }
    aiObstacles = detected;
    _toWorkerPort?.send(IsolateCommand('AI_UPDATE', aiObstacles: aiObstacles));
  }

  // ================= ĐIỀU KHIỂN =================
  Future<void> pickAndPlayVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      isPlaying = true;
      isPaused = false;
      _toWorkerPort?.send(IsolateCommand('START', path: video.path));
      notifyListeners();
    }
  }

  void togglePause() {
    isPaused = !isPaused;
    _toWorkerPort?.send(IsolateCommand(isPaused ? 'PAUSE' : 'RESUME'));
    notifyListeners();
  }

  void seekTo(double val) {
    _toWorkerPort?.send(IsolateCommand('SEEK', value: val));
  }

  void cycleSpeed() {
    if (playbackSpeed == 1.0) playbackSpeed = 1.5;
    else if (playbackSpeed == 1.5) playbackSpeed = 2.0;
    else if (playbackSpeed == 2.0) playbackSpeed = 0.5;
    else playbackSpeed = 1.0;
    _toWorkerPort?.send(IsolateCommand('SPEED', value: playbackSpeed));
    notifyListeners();
  }

  void resetTracking() {
    _toWorkerPort?.send(IsolateCommand('RESET'));
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
    _toWorkerPort?.send(IsolateCommand('STOP'));
    _fromWorkerPort.close();
    _workerIsolate?.kill();
    vision.closeYoloModel();
    gpsSubscription?.cancel();
    imuSubscription?.cancel();
    super.dispose();
  }

  // ================= WORKER ISOLATE (HÀM TÁCH BIỆT) =================
  static void _videoWorker(SendPort mainSendPort) {
    final ReceivePort workerReceivePort = ReceivePort();
    mainSendPort.send(workerReceivePort.sendPort);

    cv.VideoCapture? cap;
    CVCore cvCore = CVCore();
    bool isPlaying = false;
    bool isPaused = false;
    double speed = 1.0;
    List<Rect> obstacles = [];

    workerReceivePort.listen((message) async {
      if (message is IsolateCommand) {
        switch (message.type) {
          case 'START':
            cap?.release();
            cap = cv.VideoCapture.fromFile(message.path!);
            if (cap!.isOpened) {
              isPlaying = true;
              mainSendPort.send({
                'type': 'METADATA',
                'totalFrames': cap!.get(cv.CAP_PROP_FRAME_COUNT),
                'fps': cap!.get(cv.CAP_PROP_FPS),
              });
              _runLoop(cap!, cvCore, mainSendPort, () => isPlaying && !isPaused, () => speed, () => obstacles);
            }
            break;
          case 'PAUSE': isPaused = true; break;
          case 'RESUME': isPaused = false; break;
          case 'SPEED': speed = message.value!; break;
          case 'AI_UPDATE': obstacles = message.aiObstacles!; break;
          case 'SEEK': 
            cap?.set(cv.CAP_PROP_POS_FRAMES, message.value!);
            break;
          case 'RESET': cvCore.resetTracking(); break;
          case 'STOP': isPlaying = false; cap?.release(); break;
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
    List<Rect> Function() getObstacles
  ) async {
    while (true) {
      if (!shouldRun()) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      Stopwatch timer = Stopwatch()..start();
      var (ret, frame) = cap.read();
      if (!ret || frame.isEmpty) break;

      // 1. Resize cực nhanh
      double scale = 240.0 / frame.cols;
      cv.Mat smallFrame = cv.resize(frame, (240, (frame.rows * scale).toInt()));
      frame.dispose();

      // 2. CV Processing
      Map<String, dynamic> cvRes = cvCore.processFrame(smallFrame, aiObstacles: getObstacles());
      
      // 3. Encode
      var (ok, encoded) = cv.imencode(".jpg", smallFrame, params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 50]));
      
      // Gửi kết quả về main
      sendPort.send(IsolateResult(
        imageBytes: ok ? encoded : null,
        points: cvRes['points'],
        forbiddenZones: cvRes['forbiddenZones'],
        moveVector: cvRes['vector'],
        currentFrame: cap.get(cv.CAP_PROP_POS_FRAMES),
        imageSize: Size(smallFrame.cols.toDouble(), smallFrame.rows.toDouble()),
      ));

      smallFrame.dispose();
      timer.stop();

      // Điều tiết FPS
      int targetMs = (1000 / (30 * getSpeed())).round();
      int wait = targetMs - timer.elapsedMilliseconds;
      if (wait > 0) {
        await Future.delayed(Duration(milliseconds: wait));
      } else {
        // Skip frame nếu quá chậm
        cap.set(cv.CAP_PROP_POS_FRAMES, cap.get(cv.CAP_PROP_POS_FRAMES) + 1);
        await Future.delayed(const Duration(milliseconds: 2));
      }
    }
  }
}
