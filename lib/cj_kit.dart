import 'dart:async';

import 'package:cj_kit/logger/logger_uploader.dart';
import 'package:cj_kit/logger/logger_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as dart;

export 'package:cj_kit/fps/fps_utils.dart';
export 'package:cj_kit/logger/app_logger.dart';
export 'package:cj_kit/logger/logger_uploader.dart';

typedef LogCallback = void Function(String);

class CjKit {
  static Future<void> runApp({
    required Widget app,
    Future<void> Function()? preRun,
    LogCallback? logCallback,
  }) async {
    await runZonedGuarded(
      () async {
        await preRun?.call();
        // _initializeLogTasks();
        dart.runApp(app);
      },
      (Object error, StackTrace stackTrace) {
        // 异常处理逻辑
        final String logMessage = 'Caught error: $error\nStack trace: $stackTrace';
        if (logCallback != null) {
          logCallback(logMessage);
        } else {
          debugPrint(logMessage);
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          parent.print(zone, line);
          logCallback?.call(line);
        },
      ),
    );
  }

  // 初始化日志上传和清理的定时任务
  static void _initializeLogTasks() {
    Timer.periodic(const Duration(hours: 24), (Timer timer) async {
      // 上传日志和清理旧日志
      await LoggerUploader.uploadLogsBatch();
      await LoggerUtils.cleanOldLogs();
    });
  }
}
