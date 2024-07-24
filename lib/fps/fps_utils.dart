import 'dart:collection';
import 'dart:ui';

import 'package:cj_kit/logger/j_logger.dart';
import 'package:flutter/cupertino.dart';

class FPSUtils {
  factory FPSUtils() => _instance ??= FPSUtils._();

  FPSUtils._({int maxFrames = 100, int refreshRate = 60}) {
    _maxFrames = maxFrames;
    _refreshRate = refreshRate;
    _frameInterval = Duration(microseconds: Duration.microsecondsPerSecond ~/ _refreshRate);
    lastFrames = ListQueue<FrameTiming>(_maxFrames);
  }

  static FPSUtils? _instance;

  late int _maxFrames; // 100 帧足够了，对于 60 fps 来说
  late int _refreshRate;
  late Duration _frameInterval;
  late ListQueue<FrameTiming> lastFrames;
  static DateTime _lastReportTime = DateTime.now();

  void addTimingsCallback() {
    try {
      WidgetsFlutterBinding.ensureInitialized().removeTimingsCallback(_onReportTimings);
    } catch (_) {}
    WidgetsFlutterBinding.ensureInitialized().addTimingsCallback(_onReportTimings);
  }

  void _onReportTimings(List<FrameTiming> timings) {
    //把 Queue 当作堆栈用
    //时间从小到大，也就表示老贞在前面小索引位置，新贞在后面的大索引位置
    // print(timing.timestampInMicroseconds(FramePhase.buildStart));
    // 时间大的(新贞)被安排在队列头部， 时间小的(老贞)被安排在队列尾部
    for (final FrameTiming element in timings) {
      lastFrames.addFirst(element);
    }

    // 只保留 maxframes
    while (lastFrames.length > _maxFrames) {
      //移除队列尾部的老贞
      lastFrames.removeLast();
    }
    final DateTime now = DateTime.now();
    final Duration duration = now.difference(_lastReportTime);
    final int inSec = duration.inSeconds.abs();
    if (inSec > 5) {
      _lastReportTime = now;
      JLogger.i('fps:$fps');
      // LauncherDaemon().watchdog();
    }
  }

  double get fps {
    final List<FrameTiming> lastFramesSet = <FrameTiming>[];
    for (final FrameTiming timing in lastFrames) {
      if (lastFramesSet.isEmpty) {
        lastFramesSet.add(timing);
      } else {
        final int lastStart = lastFramesSet.last.timestampInMicroseconds(FramePhase.buildStart);
        if (lastStart - timing.timestampInMicroseconds(FramePhase.rasterFinish) > (_frameInterval.inMicroseconds * 2)) {
          // in different set
          break;
        }
        lastFramesSet.add(timing);
      }
    }
    final int framesCount = lastFramesSet.length;
    final int costCount = lastFramesSet.map((FrameTiming t) {
      // 耗时超过 frameInterval 会导致丢帧
      return ((t.buildDuration.inMicroseconds + t.rasterDuration.inMicroseconds) ~/ _frameInterval.inMicroseconds) + 1;
    }).fold(0, (int a, int b) => a + b);
    return framesCount * _refreshRate / costCount;
  }
}
