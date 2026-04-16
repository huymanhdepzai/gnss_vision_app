import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import 'tts_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSServiceImpl implements TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isEnabled = true;

  @override
  Future<Either<Failure, void>> initialize() async {
    try {
      final languages = await _tts.getLanguages;

      String targetLanguage = 'vi-VN';
      bool hasVi = languages.any(
        (lang) =>
            lang.toString().toLowerCase().contains('vi') ||
            lang.toString().toLowerCase().contains('vietnam'),
      );

      if (!hasVi) {
        targetLanguage = 'en-US';
      }

      await _tts.setLanguage(targetLanguage);
      await _tts.setSpeechRate(0.9);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
      });

      _isInitialized = true;
      return Right(null);
    } catch (e) {
      return Left(VisionFailure(message: 'Failed to initialize TTS: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> speak(
    String message, {
    bool urgent = false,
  }) async {
    if (!_isEnabled || !_isInitialized) {
      return Left(VisionFailure(message: 'TTS not enabled or initialized'));
    }

    try {
      await _tts.speak(message);
      return Right(null);
    } catch (e) {
      return Left(VisionFailure(message: 'Failed to speak: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> stop() async {
    try {
      await _tts.stop();
      return Right(null);
    } catch (e) {
      return Left(VisionFailure(message: 'Failed to stop TTS: $e'));
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!enabled && _isSpeaking) {
      await _tts.stop();
    }
  }

  @override
  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  bool get isEnabled => _isEnabled;
}
