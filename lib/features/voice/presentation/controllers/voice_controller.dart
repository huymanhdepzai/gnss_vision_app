import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceController extends ChangeNotifier {
  static const String _voiceEnabledKey = 'voice_enabled';

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isEnabled = false;
  bool _isListening = false;
  bool _isInitialized = false;
  String _lastRecognizedWords = '';
  String _statusMessage = 'Nhấn để bật điều khiển bằng giọng nói';

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String get lastRecognizedWords => _lastRecognizedWords;
  String get statusMessage => _statusMessage;

  Function(String)? onCommandRecognized;

  VoiceController() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_voiceEnabledKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading voice settings: $e');
      _isEnabled = false;
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: false,
      );
      _statusMessage = _isInitialized
          ? 'Sẵn sàng lắng nghe'
          : 'Nhận dạng giọng nói không khả dụng';
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      _statusMessage = 'Không thể khởi tạo nhận dạng giọng nói';
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleEnabled() async {
    _isEnabled = !_isEnabled;

    if (!_isEnabled && _isListening) {
      await stopListening();
    }

    if (_isEnabled) {
      if (!_isInitialized) {
        await initialize();
      }
      if (_isInitialized) {
        await startListening();
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_voiceEnabledKey, _isEnabled);
    } catch (e) {
      debugPrint('Error saving voice settings: $e');
    }

    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_isEnabled || _isListening) return;

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    try {
      await _speech.listen(
        onResult: _handleResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onSoundLevelChange: (level) {},
        localeId: 'vi_VN',
        cancelOnError: true,
        partialResults: true,
      );
      _isListening = true;
      _statusMessage = 'Đang lắng nghe...';
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting to listen: $e');
      _statusMessage = 'Lỗi: Không thể bắt đầu lắng nghe';
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      _statusMessage = 'Sẵn sàng lắng nghe';
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping listening: $e');
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    _lastRecognizedWords = result.recognizedWords;

    if (result.finalResult) {
      _isListening = false;
      _statusMessage = 'Đã nhận diện lệnh';

      final words = result.recognizedWords.toLowerCase().trim();

      if (words.contains('gnss') ||
          words.contains('vision') ||
          words.contains('geennss') ||
          words.contains('định vị') ||
          words.contains('tầm nhìn')) {
        if (onCommandRecognized != null) {
          onCommandRecognized!('gnss-vision');
        }
      } else if (words.contains('satellite') ||
          words.contains('globe') ||
          words.contains('3d') ||
          words.contains('vệ tinh')) {
        if (onCommandRecognized != null) {
          onCommandRecognized!('satellite');
        }
      } else if (words.contains('home') ||
          words.contains('back') ||
          words.contains('return') ||
          words.contains('trang chủ') ||
          words.contains('quay lại')) {
        if (onCommandRecognized != null) {
          onCommandRecognized!('home');
        }
      }

      notifyListeners();
    }
  }

  void _handleError(SpeechRecognitionError error) {
    _isListening = false;
    _statusMessage = 'Error: ${error.errorMsg}';
    notifyListeners();
  }

  void _handleStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      _statusMessage = 'Sẵn sàng lắng nghe';
    } else if (status == 'listening') {
      _isListening = true;
      _statusMessage = 'Đang lắng nghe...';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
