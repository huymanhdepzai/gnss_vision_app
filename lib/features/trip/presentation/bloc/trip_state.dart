import 'package:equatable/equatable.dart';
import '../../domain/entities/trip.dart';
import '../../domain/entities/media_file.dart';

abstract class TripState extends Equatable {
  const TripState();

  @override
  List<Object?> get props => [];
}

class TripInitial extends TripState {
  const TripInitial();
}

class TripLoading extends TripState {
  const TripLoading();
}

class TripsLoaded extends TripState {
  final List<Trip> trips;
  const TripsLoaded(this.trips);

  @override
  List<Object?> get props => [trips];
}

class TripLoaded extends TripState {
  final Trip trip;
  const TripLoaded(this.trip);

  @override
  List<Object?> get props => [trip];
}

class MediaFilesLoaded extends TripState {
  final List<MediaFile> mediaFiles;
  const MediaFilesLoaded(this.mediaFiles);

  @override
  List<Object?> get props => [mediaFiles];
}

class TripOperationSuccess extends TripState {
  final String message;
  const TripOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TripError extends TripState {
  final String message;
  const TripError(this.message);

  @override
  List<Object?> get props => [message];
}
