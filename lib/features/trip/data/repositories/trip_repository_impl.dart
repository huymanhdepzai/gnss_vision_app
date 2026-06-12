import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/trip.dart';
import '../../domain/entities/media_file.dart';
import '../../domain/repositories/trip_repository.dart';
import '../datasources/trip_local_data_source.dart';
import '../datasources/google_drive_data_source.dart';
import '../datasources/firestore_data_source.dart';
import '../../../auth/data/datasources/auth_remote_data_source.dart';
import '../models/trip_model.dart';
import '../models/media_file_model.dart';

class TripRepositoryImpl implements TripRepository {
  final TripLocalDataSource _localDataSource;
  final AuthRemoteDataSource _authRemoteDataSource;
  final FirestoreDataSource _firestoreDataSource;

  TripRepositoryImpl({
    required TripLocalDataSource localDataSource,
    required AuthRemoteDataSource authRemoteDataSource,
    required FirestoreDataSource firestoreDataSource,
  })  : _localDataSource = localDataSource,
        _authRemoteDataSource = authRemoteDataSource,
        _firestoreDataSource = firestoreDataSource;

  @override
  Future<Either<Failure, List<Trip>>> getAllTrips() async {
    final result = await _localDataSource.getAllTrips();
    return result.fold(
      (failure) => Left(failure),
      (trips) => Right(trips.map(_mapToEntity).toList()),
    );
  }

  @override
  Future<Either<Failure, Trip>> getTripById(String id) async {
    final result = await _localDataSource.getTripById(id);
    return result.fold(
      (failure) => Left(failure),
      (trip) => trip == null
          ? Left(CacheFailure(message: 'Trip not found'))
          : Right(_mapToEntity(trip)),
    );
  }

  @override
  Future<Either<Failure, Trip>> createTrip(Trip trip) async {
    final model = _mapToModel(trip);
    final result = await _localDataSource.saveTrip(model);
    return result.fold((failure) => Left(failure), (_) => Right(trip));
  }

  @override
  Future<Either<Failure, Trip>> updateTrip(Trip trip) async {
    final model = _mapToModel(trip);
    final result = await _localDataSource.saveTrip(model);
    return result.fold((failure) => Left(failure), (_) => Right(trip));
  }

  @override
  Future<Either<Failure, void>> deleteTrip(String id) async {
    // 1. Lấy thông tin trip và media để xóa trên Drive
    final tripResult = await _localDataSource.getTripById(id);
    final tripModel = tripResult.fold((l) => null, (r) => r);
    final mediaResult = await _localDataSource.getMediaFilesForTrip(id);
    final mediaFiles = mediaResult.fold((l) => <MediaFileModel>[], (r) => r);
    
    // 2. Thử xóa trên Cloud nếu đã đăng nhập
    try {
      final user = await _authRemoteDataSource.getCurrentUser();
      if (user != null) {
        final client = await _authRemoteDataSource.getAuthenticatedClient();
        if (client != null) {
          final driveDataSource = GoogleDriveDataSource(client);
          
          // Xóa từng file media
          for (final media in mediaFiles) {
            if (media.remoteId != null) {
              debugPrint('TripRepository: Deleting media ${media.remoteId} from Drive');
              await driveDataSource.deleteFile(media.remoteId!);
            }
          }
          
          // Xóa thư mục của Trip nếu có thể tìm thấy (dựa trên tên trip)
          if (tripModel != null && tripModel.title.isNotEmpty) {
            try {
              final rootFolderId = await driveDataSource.getOrCreateRootFolder();
              await driveDataSource.deleteFolderByName(tripModel.title, rootFolderId);
            } catch (e) {
              debugPrint('TripRepository: Failed to delete trip folder on Drive: $e');
            }
          }
        }
        
        debugPrint('TripRepository: Deleting trip $id from Firestore');
        await _firestoreDataSource.deleteTrip(user.id, id);
      }
    } catch (e) {
      debugPrint('TripRepository: Error deleting from cloud: $e');
      // Không throw error, vẫn tiếp tục xóa local
    }

    // 3. Xóa local
    return _localDataSource.deleteTrip(id);
  }

  @override
  Future<Either<Failure, List<MediaFile>>> getMediaForTrip(
    String tripId,
  ) async {
    final result = await _localDataSource.getMediaFilesForTrip(tripId);
    return result.fold(
      (failure) => Left(failure),
      (mediaFiles) => Right(mediaFiles.map(_mapMediaToEntity).toList()),
    );
  }

  @override
  Future<Either<Failure, MediaFile>> addMedia(
    String tripId,
    String filePath,
  ) async {
    final mediaFile = MediaFileModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tripId: tripId,
      filePath: filePath,
      type: MediaType.image,
      capturedAt: DateTime.now(),
    );

    final result = await _localDataSource.saveMediaFile(mediaFile);
    return result.fold((failure) => Left(failure), (_) async {
      await _localDataSource.addMediaToTrip(tripId, mediaFile.id);
      return Right(_mapMediaToEntity(mediaFile));
    });
  }

  @override
  Future<Either<Failure, void>> deleteMedia(String mediaId) async {
    final result = await _localDataSource.deleteMediaFile(mediaId);
    return result;
  }

  @override
  Future<Either<Failure, void>> syncTripToCloud(
    String tripId, {
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('TripRepository: Starting cloud sync for trip: $tripId');
    try {
      if (onProgress != null) onProgress(0.1);
      // 1. Kiểm tra đăng nhập và lấy client
      final user = await _authRemoteDataSource.getCurrentUser();
      if (user == null) {
        debugPrint('TripRepository: Sync aborted - user is null');
        return Left(AuthFailure(message: 'Vui lòng đăng nhập để đồng bộ'));
      }
      debugPrint('TripRepository: User found: ${user.id}');

      if (onProgress != null) onProgress(0.15);
      final client = await _authRemoteDataSource.getAuthenticatedClient();
      if (client == null) {
        debugPrint('TripRepository: Sync aborted - authenticated client is null');
        return Left(AuthFailure(message: 'Không thể xác thực với Google Drive'));
      }
      debugPrint('TripRepository: Authenticated client obtained');

      final driveDataSource = GoogleDriveDataSource(client);

      // 2. Lấy dữ liệu Trip từ local
      final tripResult = await _localDataSource.getTripById(tripId);
      final tripModel = tripResult.fold((l) => null, (r) => r);
      if (tripModel == null) {
        debugPrint('TripRepository: Sync aborted - trip not found in local DB');
        return Left(CacheFailure(message: 'Không tìm thấy chuyến đi'));
      }
      debugPrint('TripRepository: Trip data loaded: ${tripModel.title}');

      if (onProgress != null) onProgress(0.2);
      // 3. Lấy danh sách Media từ local
      final mediaResult = await _localDataSource.getMediaFilesForTrip(tripId);
      final mediaModels = mediaResult.fold((l) => <MediaFileModel>[], (r) => r);
      debugPrint('TripRepository: Found ${mediaModels.length} media files to sync');

      // 4. Khởi tạo thư mục trên Drive
      debugPrint('TripRepository: Checking/Creating root folder on Drive');
      final rootFolderId = await driveDataSource.getOrCreateRootFolder();
      debugPrint('TripRepository: Root folder ID: $rootFolderId');
      
      debugPrint('TripRepository: Checking/Creating trip folder on Drive');
      final tripFolderId = await driveDataSource.getOrCreateTripFolder(tripModel.title, rootFolderId);
      debugPrint('TripRepository: Trip folder ID: $tripFolderId');

      if (onProgress != null) onProgress(0.3);

      // 5. Upload từng file chưa sync
      final totalMedia = mediaModels.length;
      for (int i = 0; i < totalMedia; i++) {
        final media = mediaModels[i];
        if (!media.isSynced && File(media.filePath).existsSync()) {
          debugPrint('TripRepository: Uploading file: ${media.filePath}');
          final uploadResult = await driveDataSource.uploadFile(File(media.filePath), folderId: tripFolderId);
          
          final updatedMedia = media.copyWith(
            isSynced: true,
            remoteId: uploadResult['id'], // Lưu File ID từ Drive vào remoteId
          );
          
          debugPrint('TripRepository: File uploaded, updating local and Firestore');
          await _localDataSource.saveMediaFile(updatedMedia);
          await _firestoreDataSource.saveMediaFile(user.id, tripId, updatedMedia);
        } else if (media.isSynced) {
          debugPrint('TripRepository: File already synced, ensuring Firestore record exists');
          await _firestoreDataSource.saveMediaFile(user.id, tripId, media);
        } else {
          debugPrint('TripRepository: Skipping file (not found or already handled): ${media.filePath}');
        }
        
        if (onProgress != null && totalMedia > 0) {
          // Progress from 0.3 to 0.9
          double p = 0.3 + (0.6 * (i + 1) / totalMedia);
          onProgress(p);
        }
      }

      // 6. Lưu Trip lên Firestore
      debugPrint('TripRepository: Finalizing sync - saving trip metadata to Firestore');
      final syncedTripModel = tripModel.copyWith(isSynced: true);
      await _localDataSource.saveTrip(syncedTripModel);
      await _firestoreDataSource.saveTrip(user.id, syncedTripModel);

      if (onProgress != null) onProgress(1.0);
      debugPrint('TripRepository: Sync completed successfully');
      return const Right(null);
    } catch (e) {
      debugPrint('TripRepository: Sync failed with error: $e');
      return Left(ServerFailure(message: 'Lỗi đồng bộ: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> syncAllFromCloud() async {
    try {
      final user = await _authRemoteDataSource.getCurrentUser();
      if (user == null) {
        return Left(AuthFailure(message: 'Vui lòng đăng nhập để đồng bộ'));
      }

      final client = await _authRemoteDataSource.getAuthenticatedClient();
      if (client == null) {
        return Left(AuthFailure(message: 'Không thể xác thực với Google Drive để tải media'));
      }
      final driveDataSource = GoogleDriveDataSource(client);

      // 1. Xóa dữ liệu cũ của user khác
      await _localDataSource.deleteAllData();

      // 2. Lấy danh sách Trip từ Firestore
      final trips = await _firestoreDataSource.getSyncedTrips(user.id);
      
      final appDir = await getApplicationDocumentsDirectory();

      for (final trip in trips) {
        await _localDataSource.saveTrip(trip);
        
        // 3. Lấy danh sách Media cho từng Trip
        final mediaFiles = await _firestoreDataSource.getSyncedMediaFiles(user.id, trip.id);
        for (var media in mediaFiles) {
          String localPath = media.filePath;
          bool needsUpdate = false;

          if (!File(localPath).existsSync() && media.remoteId != null) {
            // Update local path relative to current app directory
            final fileName = localPath.split('/').last;
            final typeDir = media.type == MediaType.image ? 'image' : 'video';
            final newPath = '${appDir.path}/media/$typeDir/$fileName';

            try {
              debugPrint('TripRepository: Downloading media ${media.remoteId} to $newPath');
              await driveDataSource.downloadFile(media.remoteId!, newPath);
              localPath = newPath;
              needsUpdate = true;
            } catch (e) {
              debugPrint('TripRepository: Failed to download media ${media.remoteId}: $e');
            }
          } else if (!File(localPath).existsSync() && media.remoteId == null) {
             debugPrint('TripRepository: Media missing but no remoteId available: $localPath');
          } else {
             // File exists or path is valid
          }

          if (needsUpdate) {
            media = media.copyWith(filePath: localPath);
          }

          await _localDataSource.saveMediaFile(media);
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Lỗi đồng bộ từ đám mây: $e'));
    }
  }

  Trip _mapToEntity(TripModel model) {
    return Trip(
      id: model.id,
      name: model.title,
      description: model.description,
      createdAt: model.createdAt,
      updatedAt: model.completedAt,
      distance: model.distance,
      duration:
          double.tryParse(model.duration.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0,
      mediaCount: model.mediaFileIds.length,
      isSynced: model.isSynced,
    );
  }

  TripModel _mapToModel(Trip entity) {
    return TripModel(
      id: entity.id,
      title: entity.name,
      description: entity.description,
      startLat: 0,
      startLng: 0,
      endLat: 0,
      endLng: 0,
      mediaFileIds: [],
      createdAt: entity.createdAt,
      completedAt: entity.updatedAt,
      distance: entity.distance,
      duration: entity.duration.toString(),
      isActive: false,
      isSynced: entity.isSynced,
    );
  }

  MediaFile _mapMediaToEntity(MediaFileModel model) {
    return MediaFile(
      id: model.id,
      tripId: model.tripId,
      path: model.filePath,
      remoteId: model.remoteId,
      type: model.type == MediaType.image
          ? 'image'
          : model.type == MediaType.video
          ? 'video'
          : 'audio',
      createdAt: model.capturedAt,
      latitude: model.latitude,
      longitude: model.longitude,
      thumbnailPath: model.thumbnailPath,
      duration: model.duration,
      isSynced: model.isSynced,
    );
  }
}
