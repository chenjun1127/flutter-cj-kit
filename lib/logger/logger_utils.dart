import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LoggerUtils {
  static const String _logFileName = 'app.log';

  // 获取日志目录
  static Future<Directory> getLogDirectory() async {
    Directory directory;
    if (Platform.isAndroid) {
      directory = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
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

  // 清理过期日志
  // [retentionDays] 保留天数，默认7天
  static Future<void> cleanOldLogs([int retentionDays = 7]) async {
    final Directory logDir = await getLogDirectory();
    final List<FileSystemEntity> logFiles = logDir.listSync();
    final DateTime now = DateTime.now();
    final Duration retentionDuration = Duration(days: retentionDays);

    int deletedCount = 0;
    int totalSize = 0;

    for (final FileSystemEntity entity in logFiles) {
      if (entity is File) {
        try {
          final DateTime lastModified = entity.statSync().modified;
          if (now.difference(lastModified) > retentionDuration) {
            final int fileSize = entity.statSync().size;
            totalSize += fileSize;
            debugPrint(
                '删除过期日志: ${path.basename(entity.path)} ($fileSize bytes, ${now.difference(lastModified).inDays} 天前)');
            entity.deleteSync();
            deletedCount++;
          }
        } catch (e) {
          debugPrint('读取文件 ${entity.path} 修改时间失败: $e');
        }
      }
    }

    if (deletedCount > 0) {
      debugPrint('清理完成: 删除 $deletedCount 个过期日志文件，释放 ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB 空间');
    } else {
      debugPrint('没有发现过期日志文件（保留期: $retentionDays 天）');
    }
  }

  /// 获取日志统计信息
  static Future<Map<String, dynamic>> getLogStats() async {
    final Directory logDir = await getLogDirectory();
    final List<FileSystemEntity> logFiles = logDir.listSync();

    int totalFiles = 0;
    int totalSize = 0;
    DateTime? oldestDate;
    DateTime? newestDate;

    for (final FileSystemEntity entity in logFiles) {
      if (entity is File && entity.path.endsWith('.log')) {
        totalFiles++;
        totalSize += entity.statSync().size;

        final DateTime modified = entity.statSync().modified;
        if (oldestDate == null || modified.isBefore(oldestDate)) {
          oldestDate = modified;
        }
        if (newestDate == null || modified.isAfter(newestDate)) {
          newestDate = modified;
        }
      }
    }

    return <String, dynamic>{
      'totalFiles': totalFiles,
      'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      'oldestDate': oldestDate?.toString(),
      'newestDate': newestDate?.toString(),
    };
  }
}
