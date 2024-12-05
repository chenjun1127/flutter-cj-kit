import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cj_kit/logger/logger_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

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

  // 将日志文件压缩成 zip
  static Future<File> _createZipFromLogs(List<FileSystemEntity> logFiles, String logDirPath) async {
    final String zipFilePath = p.join(logDirPath, 'logs_${DateTime.now().toIso8601String()}.zip');
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
}
