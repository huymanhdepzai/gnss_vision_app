import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/trip_repository.dart';
import 'trip_event.dart';
import 'trip_state.dart';

class TripBloc extends Bloc<TripEvent, TripState> {
  final TripRepository tripRepository;

  TripBloc({required this.tripRepository}) : super(const TripInitial()) {
    on<LoadTrips>(_onLoadTrips);
    on<LoadTrip>(_onLoadTrip);
    on<CreateTrip>(_onCreateTrip);
    on<UpdateTrip>(_onUpdateTrip);
    on<DeleteTrip>(_onDeleteTrip);
    on<LoadMediaFiles>(_onLoadMediaFiles);
    on<AddMedia>(_onAddMedia);
    on<DeleteMedia>(_onDeleteMedia);
  }

  Future<void> _onLoadTrips(LoadTrips event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    final result = await tripRepository.getAllTrips();
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (trips) => emit(TripsLoaded(trips)),
    );
  }

  Future<void> _onLoadTrip(LoadTrip event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    final result = await tripRepository.getTripById(event.tripId);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (trip) => trip != null
          ? emit(TripLoaded(trip))
          : emit(const TripError('Trip not found')),
    );
  }

  Future<void> _onCreateTrip(CreateTrip event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    final result = await tripRepository.createTrip(event.trip);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (trip) => emit(TripOperationSuccess('Trip created successfully')),
    );
  }

  Future<void> _onUpdateTrip(UpdateTrip event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    final result = await tripRepository.updateTrip(event.trip);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (trip) => emit(TripOperationSuccess('Trip updated successfully')),
    );
  }

  Future<void> _onDeleteTrip(DeleteTrip event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    final result = await tripRepository.deleteTrip(event.tripId);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (_) => emit(const TripOperationSuccess('Trip deleted successfully')),
    );
  }

  Future<void> _onLoadMediaFiles(
    LoadMediaFiles event,
    Emitter<TripState> emit,
  ) async {
    emit(const TripLoading());
    final result = await tripRepository.getMediaForTrip(event.tripId);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (mediaFiles) => emit(MediaFilesLoaded(mediaFiles)),
    );
  }

  Future<void> _onAddMedia(AddMedia event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    final result = await tripRepository.addMedia(event.tripId, event.filePath);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (_) => emit(const TripOperationSuccess('Media added successfully')),
    );
  }

  Future<void> _onDeleteMedia(
    DeleteMedia event,
    Emitter<TripState> emit,
  ) async {
    emit(const TripLoading());
    final result = await tripRepository.deleteMedia(event.mediaId);
    result.fold(
      (failure) => emit(TripError(failure.message)),
      (_) => emit(const TripOperationSuccess('Media deleted successfully')),
    );
  }
}
