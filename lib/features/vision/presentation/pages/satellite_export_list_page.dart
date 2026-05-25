import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/extensions/context_extensions.dart';

class SatelliteExportListPage extends StatefulWidget {
  const SatelliteExportListPage({super.key});

  @override
  State<SatelliteExportListPage> createState() => _SatelliteExportListPageState();
}

class _SatelliteExportListPageState extends State<SatelliteExportListPage> {
  List<File> _exportFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExportFiles();
  }

  Future<void> _loadExportFiles() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities = directory.listSync();
      
      final files = entities
          .whereType<File>()
          .where((file) {
            final name = p.basename(file.path);
            return name.startsWith('GNSS_') && p.extension(file.path) == '.csv';
          })
          .toList();
      
      // Sort by modified date descending
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      setState(() {
        _exportFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showModernSnackBar(
          message: 'Lỗi khi tải danh sách tệp: $e',
          icon: Icons.error_outline_rounded,
          color: context.errorColor,
        );
      }
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Dữ liệu vệ tinh GNSS');
    } catch (e) {
      if (mounted) {
        context.showModernSnackBar(
          message: 'Lỗi khi chia sẻ tệp: $e',
          icon: Icons.error_outline_rounded,
          color: context.errorColor,
        );
      }
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await context.showModernDialog<bool>(
      child: ModernConfirmDialog(
        title: 'Xóa tệp?',
        message: 'Bạn có chắc chắn muốn xóa tệp ${p.basename(file.path)}?',
        confirmLabel: 'XÓA',
        cancelLabel: 'HỦY',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        _loadExportFiles();
        if (mounted) {
          context.showModernSnackBar(
            message: 'Đã xóa tệp thành công',
            icon: Icons.delete_outline_rounded,
            color: AppTheme.successColor,
          );
        }
      } catch (e) {
        if (mounted) {
          context.showModernSnackBar(
            message: 'Lỗi khi xóa tệp: $e',
            icon: Icons.error_outline_rounded,
            color: context.errorColor,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: _isLoading
                      ? _buildLoading()
                      : _exportFiles.isEmpty
                          ? _buildEmptyState()
                          : _buildFileList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.backgroundColor,
              context.isDark ? Colors.black : Colors.white.withOpacity(0.9),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(UIConsts.spacingLG),
      padding: EdgeInsets.symmetric(
        horizontal: UIConsts.spacingLG,
        vertical: UIConsts.spacingMD,
      ),
      decoration: AppTheme.glassDecoration(isDark: context.isDark),
      child: Row(
        children: [
          PressScale(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(UIConsts.spacingSM),
              decoration: BoxDecoration(
                color: context.adaptiveOpacity(Colors.white, 0.1, 0.06),
                borderRadius: BorderRadius.circular(UIConsts.radiusMD),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.iconColor,
                size: UIConsts.iconSizeSM,
              ),
            ),
          ),
          SizedBox(width: UIConsts.spacingLG),
          Text(
            "DỮ LIỆU ĐÃ XUẤT",
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          PressScale(
            onTap: _loadExportFiles,
            child: Icon(
              Icons.refresh_rounded,
              color: context.iconColor,
              size: UIConsts.iconSizeMD,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 80,
            color: context.iconSecondaryColor.withOpacity(0.2),
          ),
          SizedBox(height: UIConsts.spacingLG),
          Text(
            "Chưa có tệp dữ liệu nào",
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: UIConsts.spacingLG),
      itemCount: _exportFiles.length,
      itemBuilder: (context, index) {
        final file = _exportFiles[index];
        final stat = file.statSync();
        final fileName = p.basename(file.path);
        final fileSize = (stat.size / 1024).toStringAsFixed(1);
        final date = DateFormat('dd/MM/yyyy HH:mm').format(stat.modified);

        return EntranceAnimation(
          delay: Duration(milliseconds: index * 50),
          type: EntranceType.fadeSlideUp,
          child: Container(
            margin: EdgeInsets.only(bottom: UIConsts.spacingMD),
            padding: EdgeInsets.all(UIConsts.spacingLG),
            decoration: AppTheme.cardDecoration(isDark: context.isDark),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(UIConsts.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(UIConsts.radiusLG),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(width: UIConsts.spacingLG),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: UIConsts.spacingXS),
                      Text(
                        "$date • $fileSize KB",
                        style: TextStyle(
                          color: context.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PressScale(
                      onTap: () => _shareFile(file),
                      child: Container(
                        padding: EdgeInsets.all(UIConsts.spacingSM),
                        child: Icon(
                          Icons.share_rounded,
                          color: AppTheme.primaryColor.withOpacity(0.7),
                          size: UIConsts.iconSizeSM,
                        ),
                      ),
                    ),
                    PressScale(
                      onTap: () => _deleteFile(file),
                      child: Container(
                        padding: EdgeInsets.all(UIConsts.spacingSM),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.accentColor.withOpacity(0.7),
                          size: UIConsts.iconSizeSM,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
