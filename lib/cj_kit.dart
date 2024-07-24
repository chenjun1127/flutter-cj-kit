import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as dart;
export 'package:cj_kit/fps/fps_utils.dart';

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
        dart.runApp(app);
      },
      (Object error, StackTrace stackTrace) {
        // 异常处理逻辑
        final String logMessage = 'Caught error: $error\nStack trace: $stackTrace';
        if (logCallback != null) {
          logCallback(logMessage);
        } else {
          print(logMessage);
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
}
