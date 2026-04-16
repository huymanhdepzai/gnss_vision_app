import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

abstract class TTSService {
  Future<Either<Failure, void>> initialize();

  Future<Either<Failure, void>> speak(String message, {bool urgent = false});

  Future<Either<Failure, void>> stop();

  Future<void> setEnabled(bool enabled);

  Future<void> setLanguage(String language);

  Future<void> setSpeechRate(double rate);

  Future<void> setVolume(double volume);

  bool get isInitialized;

  bool get isSpeaking;

  bool get isEnabled;
}
