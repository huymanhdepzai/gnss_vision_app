import 'package:equatable/equatable.dart';

class VoiceCommand extends Equatable {
  final String id;
  final String command;
  final String? parameter;
  final DateTime timestamp;
  final double? confidence;

  const VoiceCommand({
    required this.id,
    required this.command,
    this.parameter,
    required this.timestamp,
    this.confidence,
  });

  VoiceCommand copyWith({
    String? id,
    String? command,
    String? parameter,
    DateTime? timestamp,
    double? confidence,
  }) {
    return VoiceCommand(
      id: id ?? this.id,
      command: command ?? this.command,
      parameter: parameter ?? this.parameter,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  List<Object?> get props => [id, command, parameter, timestamp, confidence];
}

enum VoiceCommandType {
  startNavigation,
  stopNavigation,
  pauseNavigation,
  resumeNavigation,
  zoomIn,
  zoomOut,
  toggleMap,
  repeatInformation,
  unknown,
}
