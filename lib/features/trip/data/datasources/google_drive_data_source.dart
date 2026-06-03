import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class GoogleDriveDataSource {
  final http.Client client;
  late drive.DriveApi _driveApi;
  static const String _folderName = 'GNSS_Vision_Trips';

  GoogleDriveDataSource(this.client) {
    _driveApi = drive.DriveApi(client);
  }

  /// Tải file lên Google Drive và trả về link
  Future<Map<String, String>> uploadFile(File file, {String? folderId}) async {
    final String fileName = p.basename(file.path);
    
    final drive.File fileMetadata = drive.File();
    fileMetadata.name = fileName;
    if (folderId != null) {
      fileMetadata.parents = [folderId];
    }

    final drive.Media media = drive.Media(file.openRead(), file.lengthSync());

    final drive.File uploadedFile = await _driveApi.files.create(
      fileMetadata,
      uploadMedia: media,
    );

    if (uploadedFile.id == null) {
      throw Exception('Không thể tải file lên Google Drive');
    }

    // Lấy webViewLink (yêu cầu file phải có quyền view)
    // Với drive.file scope, app chỉ có quyền với file nó tạo ra.
    // Ta lấy link cơ bản, sau này có thể dùng fileId để download trực tiếp.
    return {
      'id': uploadedFile.id!,
      'name': uploadedFile.name ?? fileName,
    };
  }

  /// Lấy hoặc tạo thư mục gốc cho ứng dụng
  Future<String> getOrCreateRootFolder() async {
    final String query = "name = '$_folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final drive.FileList folderList = await _driveApi.files.list(q: query);

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id!;
    }

    // Tạo mới nếu chưa có
    final drive.File folderMetadata = drive.File();
    folderMetadata.name = _folderName;
    folderMetadata.mimeType = 'application/vnd.google-apps.folder';

    final drive.File folder = await _driveApi.files.create(folderMetadata);
    return folder.id!;
  }

  /// Tải file từ Google Drive về máy
  Future<void> downloadFile(String fileId, String savePath) async {
    final drive.Media media = await _driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final saveFile = File(savePath);
    await saveFile.parent.create(recursive: true);
    final IOSink sink = saveFile.openWrite();

    await media.stream.pipe(sink);
    await sink.close();
  }

  /// Tạo thư mục cho chuyến đi cụ thể
  Future<String> createTripFolder(String tripName, String rootFolderId) async {
    final drive.File folderMetadata = drive.File();
    folderMetadata.name = tripName;
    folderMetadata.mimeType = 'application/vnd.google-apps.folder';
    folderMetadata.parents = [rootFolderId];

    final drive.File folder = await _driveApi.files.create(folderMetadata);
    return folder.id!;
  }

  /// Xóa file hoặc thư mục trên Google Drive
  Future<void> deleteFile(String fileId) async {
    try {
      await _driveApi.files.delete(fileId);
      print('GoogleDriveDataSource: Successfully deleted $fileId');
    } catch (e) {
      print('GoogleDriveDataSource: Error deleting $fileId: $e');
      // Ignore if file doesn't exist, but log it to know what happened
    }
  }

  /// Tìm và xóa thư mục dựa trên tên
  Future<void> deleteFolderByName(String folderName, String parentId) async {
    try {
      final String query = "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and '$parentId' in parents and trashed = false";
      final drive.FileList folderList = await _driveApi.files.list(q: query);

      if (folderList.files != null && folderList.files!.isNotEmpty) {
        for (var file in folderList.files!) {
          await deleteFile(file.id!);
          print('GoogleDriveDataSource: Successfully deleted folder $folderName');
        }
      }
    } catch (e) {
      print('GoogleDriveDataSource: Error deleting folder $folderName: $e');
    }
  }
}
