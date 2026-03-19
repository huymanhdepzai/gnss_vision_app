import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../vision/cv_core.dart';
import '../widgets/flow_painter.dart';

class FlowScreen extends StatefulWidget {
  const FlowScreen({Key? key}) : super(key: key);

  @override
  _FlowScreenState createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  final CVCore _cvCore = CVCore();
  cv.VideoCapture? _cap;

  List<Offset> _pointsToDraw = [];
  Offset? _objectCenter;
  Offset _moveVector = Offset.zero;
  Size _imageSize = Size.zero;
// Thay thế Rect? _staticRoi; bằng dòng dưới
  List<Rect>? _staticRois;
  // CÁC BIẾN QUẢN LÝ TRẠNG THÁI VIDEO
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isDraggingSlider = false;

  double _totalFrames = 1.0;
  double _currentFrame = 0.0;
  double _fps = 30.0;
  double _playbackSpeed = 1.0; // Tốc độ phát (0.5x, 1.0x, 2.0x)

  Uint8List? _currentFrameBytes;
  double _steeringAngle = 0.0;

  Future<void> _pickAndPlayVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      _processVideo(video.path);
    }
  }

  Future<void> _processVideo(String path) async {
    // Đóng video cũ nếu có
    if (_cap != null && _cap!.isOpened) {
      _cap!.release();
      _isPlaying = false;
    }

    _cap = cv.VideoCapture.fromFile(path);

    if (!_cap!.isOpened) {
      print("Không thể mở video");
      return;
    }

    // LẤY THÔNG TIN VIDEO
    _totalFrames = _cap!.get(cv.CAP_PROP_FRAME_COUNT);
    _fps = _cap!.get(cv.CAP_PROP_FPS);
    if (_fps <= 0) _fps = 30.0; // Dự phòng nếu video không có meta fps

    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _currentFrame = 0.0;
      _playbackSpeed = 1.0;
    });

    while (_isPlaying) {
      // 1. TẠM DỪNG HOẶC ĐANG KÉO SLIDER
      if (_isPaused || _isDraggingSlider) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      // 2. ĐỌC KHUNG HÌNH
      var (ret, frame) = _cap!.read();

      // Nếu hết video
      if (!ret || frame.isEmpty) {
        setState(() {
          _isPaused = true; // Chuyển sang pause thay vì tắt hẳn để người dùng có thể tua lại
          _currentFrame = _totalFrames;
        });
        continue;
      }

      // Cập nhật vị trí thanh trượt
      _currentFrame = _cap!.get(cv.CAP_PROP_POS_FRAMES);

      // 3. XỬ LÝ OPTICAL FLOW
      Map<String, dynamic> result = _cvCore.processFrame(frame);
      var (success, encodedFrame) = cv.imencode(".jpg", frame);

      if (success) {
        setState(() {
          _pointsToDraw = result['points'];
          _objectCenter = result['center'];
          _moveVector = result['vector'];
          _staticRois = result['staticRois'];
          _currentFrameBytes = encodedFrame;
          _imageSize = Size(frame.cols.toDouble(), frame.rows.toDouble());

          if (_moveVector.distance > 0.1) {
            _steeringAngle = math.atan2(_moveVector.dy, _moveVector.dx) + (math.pi / 2);
          } else {
            _steeringAngle = 0.0;
          }
        });
      }

      // 4. KIỂM SOÁT TỐC ĐỘ PHÁT (Tua nhanh / chậm)
      int delayMs = (1000 / (_fps * _playbackSpeed)).round();
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    _cap?.release();
  }

  // HÀM TUA VIDEO TỚI VỊ TRÍ BẤT KỲ
  void _seekTo(double frameNum) {
    if (_cap != null && _cap!.isOpened) {
      // Đặt lại vị trí đọc của OpenCV
      _cap!.set(cv.CAP_PROP_POS_FRAMES, frameNum);

      // Xóa bộ nhớ đệm Optical Flow để tránh mũi tên bị giật loạn xạ khi nhảy cóc
      _cvCore.resetTracking();

      // Nếu đang Pause, ta đọc ép 1 frame để hiển thị ra màn hình cho người dùng xem trước
      if (_isPaused || _isDraggingSlider) {
        var (ret, frame) = _cap!.read();
        if (ret && frame.isEmpty) {
          var (success, encodedFrame) = cv.imencode(".jpg", frame);
          if (success) {
            setState(() { _currentFrameBytes = encodedFrame; });
          }
          // Trả lại đúng vị trí frame để play tiếp không bị mất 1 frame
          _cap!.set(cv.CAP_PROP_POS_FRAMES, frameNum);
        }
      }
    }
  }

  // HÀM ĐỔI TỐC ĐỘ (Vòng lặp: 1x -> 1.5x -> 2x -> 0.5x -> 1x)
  void _cycleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) _playbackSpeed = 1.5;
      else if (_playbackSpeed == 1.5) _playbackSpeed = 2.0;
      else if (_playbackSpeed == 2.0) _playbackSpeed = 0.5;
      else _playbackSpeed = 1.0;
    });
  }

  // Đổi giây sang định dạng MM:SS
  String _formatTime(double totalFrames, double fps) {
    if (fps == 0) return "00:00";
    int totalSeconds = (totalFrames / fps).round();
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _isPlaying = false;
    _cap?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text("Autonomous Navigation"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ==============================
          // NỬA TRÊN: MÀN HÌNH CAMERA/VIDEO
          // ==============================
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: _currentFrameBytes != null && _imageSize != Size.zero
                  ? Center(
                child: AspectRatio(
                  aspectRatio: _imageSize.width / _imageSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        _currentFrameBytes!,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                      CustomPaint(
                        painter: FlowPainter(
                          points: _pointsToDraw,
                          imageSize: _imageSize,
                          staticRois: _staticRois, // Cập nhật tên biến
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : const Center(
                child: Icon(Icons.videocam_off, color: Colors.white54, size: 60),
              ),
            ),
          ),

          // ==============================
          // NỬA DƯỚI: DASHBOARD ĐIỀU HƯỚNG & CONTROL
          // ==============================
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

                  // 1. LA BÀN ĐIỀU HƯỚNG
                  Column(
                    children: [
                      AnimatedRotation(
                        turns: _steeringAngle / (2 * math.pi),
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                              border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 3),
                              boxShadow: [
                                BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 15, spreadRadius: 5)
                              ]
                          ),
                          child: const Center(
                            child: Icon(Icons.navigation, color: Colors.redAccent, size: 45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _moveVector.distance < 0.1 ? "HOLDING" : "MOVING",
                        style: TextStyle(
                            color: _moveVector.distance < 0.1 ? Colors.white54 : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                        ),
                      )
                    ],
                  ),

                  // 2. VIDEO TIMELINE (THANH TRƯỢT)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(_formatTime(_currentFrame, _fps), style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            value: _currentFrame.clamp(0.0, _totalFrames > 0 ? _totalFrames : 1.0),
                            min: 0.0,
                            max: _totalFrames > 0 ? _totalFrames : 1.0,
                            activeColor: Colors.cyanAccent,
                            inactiveColor: Colors.white24,
                            onChangeStart: (val) {
                              setState(() { _isDraggingSlider = true; });
                            },
                            onChanged: (val) {
                              setState(() { _currentFrame = val; });
                              _seekTo(val); // Cập nhật hình ảnh lập tức khi kéo
                            },
                            onChangeEnd: (val) {
                              setState(() { _isDraggingSlider = false; });
                            },
                          ),
                        ),
                        Text(_formatTime(_totalFrames, _fps), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),

                  // 3. CÁC NÚT ĐIỀU KHIỂN (Play/Pause, Tốc độ)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Nút tải Video
                      IconButton(
                        icon: const Icon(Icons.video_library),
                        color: Colors.white54,
                        iconSize: 30,
                        onPressed: _isPlaying && !_isPaused ? null : _pickAndPlayVideo,
                      ),

                      // Nút Tốc Độ Phát
                      TextButton(
                        onPressed: _isPlaying ? _cycleSpeed : null,
                        style: TextButton.styleFrom(backgroundColor: Colors.white10, shape: const StadiumBorder()),
                        child: Text("${_playbackSpeed}x", style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ),

                      // Nút Play / Pause khổng lồ
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withOpacity(0.8)),
                        child: IconButton(
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                          color: Colors.white,
                          iconSize: 45,
                          onPressed: () {
                            if (_isPlaying) {
                              setState(() { _isPaused = !_isPaused; });
                            }
                          },
                        ),
                      ),

                      // Nút Reset Tracking
                      IconButton(
                        icon: const Icon(Icons.restart_alt),
                        color: Colors.white54,
                        iconSize: 30,
                        onPressed: () { _cvCore.resetTracking(); },
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}