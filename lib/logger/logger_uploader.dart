import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cj_kit/logger/logger_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LoggerUploader {
  // 批量上传日志文件
  static Future<void> uploadLogsBatch() async {
    final Directory logDir = await LoggerUtils.getLogDirectory();
    final List<FileSystemEntity> logFiles = logDir.listSync();

    if (logFiles.isEmpty) {
      debugPrint('No log files to upload.');
      return;
    }

    final File zipFile = await _createZipFromLogs(logFiles, logDir.path);

    try {
      await _uploadToCloud(zipFile);
      debugPrint('Successfully uploaded logs to cloud.');

      // 上传成功后清理已上传的日志文件
      for (final FileSystemEntity entity in logFiles) {
        if (entity is File) {
          await entity.delete();
        }
      }

      // 上传后清理过期日志
      await LoggerUtils.cleanOldLogs();
    } catch (e) {
      debugPrint('Failed to upload logs: $e');
    }
  }

  // 导入日志文件，打包后上传到下载目录或通过分享
  static Future<void> uploadLogsToDownloads() async {
    final Directory logDir = await LoggerUtils.getLogDirectory();
    final List<FileSystemEntity> logFiles = logDir.listSync();

    if (logFiles.isEmpty) {
      debugPrint('No log files to upload.');
      return;
    }

    // 将日志文件压缩成 zip
    final File zipFile = await _createZipFromLogs(logFiles, logDir.path);

    try {
      // 获取手机的下载目录
      final Directory? downloadDir = await _getDownloadDirectory();
      if (downloadDir == null) {
        debugPrint('Download directory not found, attempting to share the log file.');
        // 如果无法获取下载目录，尝试分享日志文件
        await _shareLogFile(zipFile);
        return;
      }
      final String isoDate = DateTime.now().toIso8601String().replaceAll('T', '_').replaceAll(':', '-').split('.')[0];
      // 将 zip 文件保存到下载目录
      final String zipFilePath = p.join(downloadDir.path, 'logs_$isoDate.zip');
      final File savedZipFile = await zipFile.copy(zipFilePath);
      debugPrint('Logs saved to: ${savedZipFile.path}');

      // 上传成功后清理已上传的日志文件
      await _clearLogs(logFiles);
    } catch (e) {
      debugPrint('Failed to upload logs: $e');
    }
  }

  static Future<Directory?> _getDownloadDirectory() async {
    Directory? downloadDir;

    // 适配不同平台（Android 和 iOS）
    if (Platform.isAndroid) {
      downloadDir = await getExternalStorageDirectory();
      if (downloadDir != null) {
        // 获取 `Download` 文件夹路径
        downloadDir = Directory(p.join(downloadDir.path, 'Download'));
      }
    } else if (Platform.isIOS) {
      downloadDir = await getApplicationDocumentsDirectory();
    }

    return downloadDir?.existsSync() ?? false ? downloadDir : null;
  }

  // 清理日志文件
  static Future<void> _clearLogs(List<FileSystemEntity> logFiles) async {
    for (final FileSystemEntity entity in logFiles) {
      if (entity is File) {
        await entity.delete();
      }
    }

    // 上传后清理过期日志
    await LoggerUtils.cleanOldLogs();
  }

  // 将日志文件压缩成 zip
  static Future<File> _createZipFromLogs(List<FileSystemEntity> logFiles, String logDirPath) async {
    final String isoDate = DateTime.now().toIso8601String().replaceAll('T', '_').replaceAll(':', '-').split('.')[0];
    final String zipFilePath = p.join(logDirPath, 'logs_$isoDate.zip');
    final File zipFile = File(zipFilePath);

    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    for (final FileSystemEntity entity in logFiles) {
      if (entity is File) {
        await encoder.addFile(entity);
      }
    }
    await encoder.close();

    return zipFile;
  }

  // 模拟上传到云端
  static Future<void> _uploadToCloud(File file) async {
    await Future<void>.delayed(const Duration(seconds: 2)); // 模拟上传延迟
    debugPrint('Uploading ${file.path} to cloud...');
  }

  // 分享日志文件（iOS/Android 都支持）
  static Future<void> _shareLogFile(File logFile) async {
    try {
      // 使用 shareXFiles 来分享文件
      final ShareResult result = await Share.shareXFiles(<XFile>[
        XFile(logFile.path), // 将文件路径传给 XFile
      ]);

      if (result.status == ShareResultStatus.dismissed) {
        debugPrint('User dismissed the share dialog.');
      }
      debugPrint('Log file shared successfully.');
    } catch (e) {
      debugPrint('Failed to share log file: $e');
    }
  }
}
