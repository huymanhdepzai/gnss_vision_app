import 'package:equatable/equatable.dart';
import '../../domain/entities/trip.dart';
import '../../domain/entities/media_file.dart';

abstract class TripEvent extends Equatable {
  const TripEvent();

  @override
  List<Object?> get props => [];
}

class LoadTrips extends TripEvent {
  const LoadTrips();
}

class LoadTrip extends TripEvent {
  final String tripId;
  const LoadTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class CreateTrip extends TripEvent {
  final Trip trip;
  const CreateTrip(this.trip);

  @override
  List<Object?> get props => [trip];
}

class UpdateTrip extends TripEvent {
  final Trip trip;
  const UpdateTrip(this.trip);

  @override
  List<Object?> get props => [trip];
}

class DeleteTrip extends TripEvent {
  final String tripId;
  const DeleteTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class LoadMediaFiles extends TripEvent {
  final String tripId;
  const LoadMediaFiles(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class AddMedia extends TripEvent {
  final String tripId;
  final String filePath;
  const AddMedia(this.tripId, this.filePath);

  @override
  List<Object?> get props => [tripId, filePath];
}

class DeleteMedia extends TripEvent {
  final String mediaId;
  const DeleteMedia(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}
