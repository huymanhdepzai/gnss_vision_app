import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/process_frame.dart';
import '../../domain/usecases/detect_obstacles.dart';
import '../../domain/usecases/get_heading.dart';
import 'vision_event.dart';
import 'vision_state.dart';

class VisionBloc extends Bloc<VisionEvent, VisionState> {
  final ProcessFrame processFrame;
  final DetectObstacles detectObstacles;
  final GetHeading getHeading;

  VisionBloc({
    required this.processFrame,
    required this.detectObstacles,
    required this.getHeading,
  }) : super(const VisionInitial()) {
    on<InitializeVision>(_onInitialize);
    on<LoadVideo>(_onLoadVideo);
    on<PlayVideo>(_onPlay);
    on<PauseVideo>(_onPause);
    on<SeekVideo>(_onSeek);
    on<SetPlaybackSpeed>(_onSetSpeed);
    on<ResetVision>(_onReset);
    on<ToggleVoice>(_onToggleVoice);
    on<ToggleDebugMode>(_onToggleDebug);
    on<FrameProcessed>(_onFrameProcessed);
    on<ObstaclesDetected>(_onObstaclesDetected);
    on<HeadingUpdated>(_onHeadingUpdated);
    on<ErrorOccurred>(_onError);
  }

  Future<void> _onInitialize(
    InitializeVision event,
    Emitter<VisionState> emit,
  ) async {
    emit(const VisionLoading());
    // TODO: Initialize repository
    emit(
      const VisionReady(isModelLoaded: false, hasVideo: false, totalFrames: 0),
    );
  }

  Future<void> _onLoadVideo(LoadVideo event, Emitter<VisionState> emit) async {
    emit(const VisionLoading());
    // TODO: Load video from path
    emit(VisionReady(isModelLoaded: true, hasVideo: true, totalFrames: 0));
  }

  Future<void> _onPlay(PlayVideo event, Emitter<VisionState> emit) async {
    if (state is VisionProcessing) {
      emit((state as VisionProcessing).copyWith(isPaused: false));
    }
  }

  Future<void> _onPause(PauseVideo event, Emitter<VisionState> emit) async {
    if (state is VisionProcessing) {
      emit((state as VisionProcessing).copyWith(isPaused: true));
    }
  }

  Future<void> _onSeek(SeekVideo event, Emitter<VisionState> emit) async {
    if (state is VisionProcessing) {
      emit((state as VisionProcessing).copyWith(progress: event.position));
    }
  }

  Future<void> _onSetSpeed(
    SetPlaybackSpeed event,
    Emitter<VisionState> emit,
  ) async {
    // TODO: Implement speed change
  }

  Future<void> _onReset(ResetVision event, Emitter<VisionState> emit) async {
    // TODO: Implement reset
    emit(const VisionInitial());
  }

  Future<void> _onToggleVoice(
    ToggleVoice event,
    Emitter<VisionState> emit,
  ) async {
    if (state is VisionProcessing) {
      final currentState = state as VisionProcessing;
      emit(currentState.copyWith(voiceEnabled: !currentState.voiceEnabled));
    }
  }

  Future<void> _onToggleDebug(
    ToggleDebugMode event,
    Emitter<VisionState> emit,
  ) async {
    if (state is VisionProcessing) {
      final currentState = state as VisionProcessing;
      emit(currentState.copyWith(debugMode: !currentState.debugMode));
    }
  }

  Future<void> _onFrameProcessed(
    FrameProcessed event,
    Emitter<VisionState> emit,
  ) async {
    if (state is VisionProcessing) {
      emit((state as VisionProcessing).copyWith(frameResult: event.result));
    }
  }

  Future<void> _onObstaclesDetected(
    ObstaclesDetected event,
    Emitter<VisionState> emit,
  ) async {
    if (state is VisionProcessing) {
      emit((state as VisionProcessing).copyWith(obstacles: event.obstacles));
    }
  }

  Future<void> _onHeadingUpdated(
    HeadingUpdated event,
    Emitter<VisionState> emit,
  ) async {
    if (state is VisionProcessing) {
      emit((state as VisionProcessing).copyWith(heading: event.heading));
    }
  }

  Future<void> _onError(ErrorOccurred event, Emitter<VisionState> emit) async {
    emit(VisionError(event.message));
  }
}
