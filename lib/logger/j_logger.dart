import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class JLogger {
  factory JLogger() {
    _instance ??= JLogger._();
    init();
    return _instance!;
  }

  JLogger._();

  static JLogger? _instance;
  static late Logger _logger;

  static void init() {
    _logger = Logger(
      filter: LoggerFilter(),
      output: kReleaseMode ? FileLoggerOutput() : LoggerOutput(),
      // printer: PrettyPrinter(
      //   methodCount: 2,
      //   errorMethodCount: 10,
      //   lineLength: 200,
      //   colors: false,
      //   printTime: true,
      // ),
      printer: SimpleLogPrinter(),
    );
  }

  static void v(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.v(message, error, stackTrace);
  }

  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error, stackTrace);
  }

  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error, stackTrace);
  }

  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error, stackTrace);
  }

  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error, stackTrace);
  }

  static void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.wtf(message, error, stackTrace);
  }
}

class FileLoggerOutput extends LogOutput {
  FileLoggerOutput({String? fileName}) {
    logFileName = fileName ?? 'logs.txt';
  }

  String? logFileName;

  @override
  void output(OutputEvent event) {
    for (final String i in event.lines) {
      if (_sink != null) {
        _sink!.write('$i\n');
      }
    }
  }

  IOSink? _sink;

  @override
  Future<void> init() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory.path}/$logFileName');
    // print(file);
    // 日志保存在应用程序的沙盒目录中，这是应用程序具有写入权限的地方。存放在模拟器中设备地方
    // /data/user/0/com.example.flutter_advanced/app_flutter/logs.txt
    _sink = file.openWrite(mode: FileMode.append);
  }

  @override
  void destroy() {
    _sink?.close();
    _sink = null;
  }
}

class LoggerFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    } else {
      return true;
    }
  }
}

class LoggerOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    event.lines.forEach(debugPrint);
  }
}

class SimpleLogPrinter extends LogPrinter {
  SimpleLogPrinter({this.lineLength = 800});

  //日志字符限制800个
  int? lineLength;

  @override
  List<String> log(LogEvent event) {
    final StackTrace stackTrace = StackTrace.current;
    final String currentFrame = stackTrace.toString().split("\n").elementAt(4);
    // final String? methodName = RegExp(r'\.(\w+)\s').firstMatch(currentFrame)?.group(1);
    final String? lineNumber = RegExp(r':(\d+):').firstMatch(currentFrame)?.group(1);
    // final String className = currentFrame.split(".").elementAt(0).trim();
    final String? emoji = PrettyPrinter.levelEmojis[event.level];
    final List<String> currentFrameList =
    currentFrame.split(' ').where((String part) => part.isNotEmpty && !part.contains('#')).toList();
    final String classNameAndMethodName = currentFrameList[0];
    final String filePath = currentFrameList.where((String element) => element.contains('(')).first;
    final int lastSlashIndex = filePath.lastIndexOf('/');
    final String fileNameWithLine = filePath.substring(lastSlashIndex + 1);
    final String fileName = fileNameWithLine.substring(0, fileNameWithLine.indexOf(':'));
    String logMessage = event.message as String;
    if (logMessage.length > lineLength!) {
      logMessage = logMessage.substring(0, lineLength);
    }
    final String color = _getLogColor2(event.level);
    final String color2 = levelColors2[event.level]!;
    // 通过在日志消息中插入颜色代码，并使用 ANSI 转义码将其包裹起来
    // \x1B 是 ANSI 转义序列的开始，用于指示后续字符是一个转义码。
    // \x1B[0m 是用于重置颜色样式的 ANSI 转义码。
    // 下现两种添加日志颜色写法都可以
    // return <String>[
    //   "\x1B[$color2${DateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(event.time)} $emoji${levelAbbr[event.level]}/$fileName [$classNameAndMethodName:$lineNumber]: $logMessage\x1B[0m"
    // ];
    return <String>[
      "$color${DateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(event.time)} $emoji${levelAbbr[event.level]}/$fileName [$classNameAndMethodName:$lineNumber]: $logMessage\x1B[0m"
    ];
  }

  static final Map<Level, String> levelAbbr = <Level, String>{
    Level.verbose: 'V',
    Level.debug: 'D',
    Level.info: 'I',
    Level.warning: 'W',
    Level.error: 'E',
    Level.wtf: 'F',
  };

  static final Map<Level, String> levelColors2 = <Level, String>{
    Level.verbose: '0;37m',
    Level.debug: '0;34m',
    Level.info: '0;32m',
    Level.warning: '0;33m',
    Level.error: '0;31m',
    Level.wtf: '0m',
  };

  static String _getLogColor2(Level level) {
    return PrettyPrinter.levelColors[level].toString();
  }
}

// JLogger logger = JLogger();
