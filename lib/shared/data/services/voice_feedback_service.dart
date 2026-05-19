import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceAlertType {
  obstacleDetected,
  obstacleAhead,
  multipleObstacles,
  obstacleCleared,
  lowConfidence,
  highConfidenceTurning,
}

class VoiceFeedbackService extends ChangeNotifier {
  static const Duration _minInterval = Duration(seconds: 2);
  static const Duration _urgentInterval = Duration(seconds: 1);

  final FlutterTts _tts = FlutterTts();

  bool _isEnabled = true;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  DateTime? _lastSpeakTime;
  String _lastMessage = '';
  List<String> _availableLanguages = [];

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('=== VoiceFeedbackService: Initializing TTS ===');

      final dynamic languages = await _tts.getLanguages;
      if (languages is List) {
        _availableLanguages = languages.map((e) => e.toString()).toList();
      } else {
        _availableLanguages = [];
      }
      debugPrint('Available TTS languages: $_availableLanguages');

      String targetLanguage = 'vi-VN';
      bool hasVi = _availableLanguages.any(
        (lang) =>
            lang.toLowerCase().contains('vi') ||
            lang.toLowerCase().contains('vietnam'),
      );

      if (!hasVi) {
        debugPrint('Vietnamese TTS not available, falling back to en-US');
        targetLanguage = 'en-US';
      }

      await _tts.setLanguage(targetLanguage);
      await _tts.setSpeechRate(0.9);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        debugPrint('TTS: Started speaking');
        notifyListeners();
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint('TTS: Completed speaking');
        notifyListeners();
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('TTS Error: $msg');
        notifyListeners();
      });

      _isInitialized = true;
      debugPrint(
        'VoiceFeedbackService initialized successfully with language: $targetLanguage',
      );

      await _testSpeak();
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
      _isInitialized = false;
    }
  }

  Future<void> _testSpeak() async {
    try {
      debugPrint('TTS: Testing...');
      await _tts.speak('');
      debugPrint('TTS: Test complete');
    } catch (e) {
      debugPrint('TTS test error: $e');
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled && _isSpeaking) {
      _tts.stop();
    }
    debugPrint('VoiceFeedback: Enabled = $enabled');
    notifyListeners();
  }

  Future<void> speak(String message, {bool urgent = false}) async {
    debugPrint('=== TTS speak() called ===');
    debugPrint('  message: $message');
    debugPrint('  isEnabled: $_isEnabled');
    debugPrint('  isInitialized: $_isInitialized');
    debugPrint('  isSpeaking: $_isSpeaking');

    if (!_isEnabled) {
      debugPrint('  SKIPPED: Voice is disabled');
      return;
    }

    if (!_isInitialized) {
      debugPrint('  SKIPPED: TTS not initialized, trying to initialize...');
      await initialize();
      if (!_isInitialized) {
        debugPrint('  SKIPPED: TTS initialization failed');
        return;
      }
    }

    if (_isSpeaking) {
      debugPrint('  SKIPPED: Already speaking');
      return;
    }

    final now = DateTime.now();
    final interval = urgent ? _urgentInterval : _minInterval;

    if (_lastSpeakTime != null) {
      final elapsed = now.difference(_lastSpeakTime!);
      if (elapsed < interval && _lastMessage == message) {
        debugPrint(
          '  SKIPPED: Same message within interval (${elapsed.inMilliseconds}ms < ${interval.inMilliseconds}ms)',
        );
        return;
      }
    }

    try {
      debugPrint('  SPEAKING: $message');
      await _tts.speak(message);
      _lastSpeakTime = now;
      _lastMessage = message;
    } catch (e) {
      debugPrint('  ERROR: TTS speak error: $e');
    }
  }

  Future<void> alertObstacle({
    required int count,
    required List<String> labels,
    String? direction,
  }) async {
    debugPrint('=== alertObstacle called ===');
    debugPrint('  count: $count');
    debugPrint('  labels: $labels');

    String message;

    if (count == 0) {
      debugPrint('  SKIPPED: No obstacles');
      return;
    }

    if (count == 1) {
      final label = _translateLabel(labels.first);
      message = 'Canh bao! $label phia truoc';
    } else if (count <= 3) {
      final labelList = labels.take(3).map(_translateLabel).join(', ');
      message = 'Phat hien $count vat can: $labelList';
    } else {
      message = 'Canh bao! Nhieu vat can phia truoc, $count vat the';
    }

    if (direction != null && direction.isNotEmpty) {
      message += ' ben $direction';
    }

    debugPrint('  Message to speak: $message');
    await speak(message, urgent: true);
  }

  Future<void> alertTurn(String direction, double angle) async {
    if (!_isEnabled || !_isInitialized) return;

    String turnType;
    if (angle.abs() < 15) {
      return;
    } else if (angle.abs() < 45) {
      turnType = direction == 'left' ? 'Re nhe trai' : 'Re nhe phai';
    } else {
      turnType = direction == 'left' ? 'Re trai' : 'Re phai';
    }

    await speak(turnType, urgent: false);
  }

  String _translateLabel(String label) {
    final translations = {
      'car': 'xe hoi',
      'motorcycle': 'xe may',
      'bus': 'xe buyt',
      'truck': 'xe tai',
      'person': 'nguoi',
      'bicycle': 'xe dap',
      'bird': 'chim',
      'cat': 'meo',
      'dog': 'cho',
      'traffic light': 'den giao thong',
      'stop sign': 'bien stop',
    };

    return translations[label.toLowerCase()] ?? label;
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
