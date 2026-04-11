import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../models/media_file.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      return await _saveFileToAppStorage(File(image.path), 'image');
    }
    return null;
  }

  Future<String?> pickVideoFromGallery() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      return await _saveFileToAppStorage(File(video.path), 'video');
    }
    return null;
  }

  Future<String?> captureImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image != null) {
      return await _saveFileToAppStorage(File(image.path), 'image');
    }
    return null;
  }

  Future<String?> captureVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
    if (video != null) {
      return await _saveFileToAppStorage(File(video.path), 'video');
    }
    return null;
  }

  Future<String> _saveFileToAppStorage(File file, String type) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String mediaDir = '${appDir.path}/media/$type';
    await Directory(mediaDir).create(recursive: true);

    final String fileName = '${const Uuid().v4()}.${file.path.split('.').last}';
    final String newPath = '$mediaDir/$fileName';

    await file.copy(newPath);
    return newPath;
  }

  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final VideoPlayerController controller = VideoPlayerController.file(
        File(videoPath),
      );
      await controller.initialize();

      final frame = await controller.seekTo(const Duration(milliseconds: 100));
      final image = controller.value.position;

      await controller.dispose();

      return videoPath;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> clearAllMedia() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory mediaDir = Directory('${appDir.path}/media');

      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  Future<int> getMediaStorageSize() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory mediaDir = Directory('${appDir.path}/media');

      if (!await mediaDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (var entity in mediaDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  MediaFile createMediaFile({
    required String tripId,
    required String filePath,
    required MediaType type,
    double? latitude,
    double? longitude,
    String? thumbnailPath,
  }) {
    return MediaFile(
      id: const Uuid().v4(),
      tripId: tripId,
      filePath: filePath,
      type: type,
      latitude: latitude,
      longitude: longitude,
      capturedAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
  }
}
