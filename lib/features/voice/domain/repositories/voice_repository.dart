import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/voice_command.dart';

abstract class VoiceRepository {
  Future<Either<Failure, void>> initialize();

  Future<Either<Failure, void>> startListening();

  Future<Either<Failure, void>> stopListening();

  Stream<VoiceCommand> get commandStream;

  Stream<String> get recognizedTextStream;

  Stream<bool> get isListeningStream;

  Future<Either<Failure, void>> speak(String message);

  Future<Either<Failure, void>> stopSpeaking();

  bool get isListening;

  bool get isSpeaking;
}
