import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

class LoggerUtils {
  static const String _logFileName = 'app.log';
  static const Duration _logRetentionDuration = Duration(days: 7);

  // 获取日志目录
  static Future<Directory> getLogDirectory() async {
    Directory? directory = await getExternalStorageDirectory();
    // 如果外部存储不可用，回退到应用文档目录
    directory ??= await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/logs')..createSync(recursive: true);
  }

  // 获取日志文件
  static Future<File> _getLogFile() async {
    final Directory logDir = await getLogDirectory();
    return File('${logDir.path}/$_logFileName');
  }

  // 追加日志
  static Future<void> appendLog(String log) async {
    final File logFile = await _getLogFile();
    final IOSink sink = logFile.openWrite(mode: FileMode.append);
    sink.writeln('[${DateTime.now()}] $log');
    await sink.close();
  }

  // 判断是否需要上传日志
  static Future<bool> shouldUploadLogs() async {
    final Directory logDir = await getLogDirectory();
    final List<FileSystemEntity> logFiles = logDir.listSync();
    const int maxFiles = 5;
    const int maxSizeBytes = 10 * 1024 * 1024; // 10 MB

    int totalSize = 0;
    for (final FileSystemEntity entity in logFiles) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return logFiles.length > maxFiles || totalSize > maxSizeBytes;
  }

  // 清理过期日志（默认 7 天前的日志）
  static Future<void> cleanOldLogs() async {
    final Directory logDir = await getLogDirectory();

    // 获取文件列表（这里依然使用异步获取目录下的文件列表，因为可能目录下文件较多等情况异步更好）
    final List<FileSystemEntity> logFiles = logDir.listSync();

    final DateTime now = DateTime.now();

    for (final FileSystemEntity entity in logFiles) {
      if (entity is File) {
        try {
          final DateTime lastModified = entity.statSync().modified;
          if (now.difference(lastModified) > _logRetentionDuration) {
            debugPrint('Deleting old log file: ${entity.path}');
            entity.deleteSync();
          }
        } catch (e) {
          debugPrint('Error reading last modified time for ${entity.path}: $e');
        }
      }
    }
  }
}
