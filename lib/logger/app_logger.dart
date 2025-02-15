import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  factory AppLogger() {
    _instance ??= AppLogger._();
    return _instance!;
  }

  AppLogger._();

  static AppLogger? _instance;
  static late Logger _logger;

  static Future<void> init() async {
    _logger = Logger(
      filter: LoggerFilter(),
      output: await _createLogOutput(),
      printer: SimpleLogPrinter(),
    );
  }

  // 创建合适的日志输出
  static Future<LogOutput> _createLogOutput() async {
    if (kReleaseMode) {
      return FileLoggerOutput(
        fileName: 'app.log',
        maxSizeBytes: 100 * 1024 * 1024, // 100MB
        bufferSize: 50,
        flushInterval: const Duration(seconds: 5),
      );
    }
    return LoggerOutput();
  }

  static void t(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

/// 文件日志输出实现
class FileLoggerOutput extends LogOutput {
  FileLoggerOutput({
    required this.fileName,
    required this.maxSizeBytes,
    required this.bufferSize,
    required this.flushInterval,
  });

  final String fileName;
  final int maxSizeBytes;
  final int bufferSize;
  final Duration flushInterval;

  IOSink? _sink;
  final List<String> _buffer = <String>[];
  Timer? _flushTimer;

  @override
  Future<void> init() async {
    final File file = await _getLogFile();
    await file.create(recursive: true);
    _sink = file.openWrite(mode: FileMode.append);
    _startFlushTimer();
  }

  @override
  Future<void> destroy() async {
    await _flushBuffer();
    await _sink?.close();
    _flushTimer?.cancel();
    _sink = null;
  }

  @override
  void output(OutputEvent event) {
    _buffer.addAll(event.lines.map((String line) {
      // 先移除 ANSI 转义序列
      final String cleanLine = _removeAnsiEscape(line.trimRight());
      // 确保每行都以单个换行符结束
      return '$cleanLine\n';
    }));
    if (_buffer.length >= bufferSize) {
      _flushBuffer();
    }
    _checkFileSizeAndRotate();
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) {
      return;
    }

    final File file = await _getLogFile();
    final IOSink sink = file.openWrite(mode: FileMode.append);
    sink.writeAll(_buffer);
    await sink.flush();
    await sink.close();
    _buffer.clear();
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(flushInterval, (_) => _flushBuffer());
  }

  Future<void> _checkFileSizeAndRotate() async {
    final File file = await _getLogFile();
    if (await file.length() > maxSizeBytes) {
      final String newName = '${file.path}_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}';
      await file.rename(newName);
      await init();
    }
  }

  Future<File> _getLogFile() async {
    // 获取外部存储目录
    Directory? directory = await getExternalStorageDirectory();

    // 如果外部存储不可用，回退到应用文档目录
    directory ??= await getApplicationDocumentsDirectory();
    final Directory logsDir = Directory('${directory.path}/logs');
    if (!logsDir.existsSync()) {
      await logsDir.create(recursive: true); // 创建 logs 目录
    }
    return File('${logsDir.path}/$fileName');
  }

  String _removeAnsiEscape(String input) {
    return input.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
  }
}

class LoggerFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return !kReleaseMode || (kReleaseMode && event.level.index >= Level.info.index);
  }
}

class LoggerOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // 处理每一行输出，移除可能的额外换行符
    for (final String line in event.lines) {
      // 移除行尾的换行符（如果有的话）
      final String cleanLine = line.trimRight();
      if (cleanLine.isNotEmpty) {
        debugPrint(cleanLine);
      }
    }
  }
}

class SimpleLogPrinter extends LogPrinter {
  SimpleLogPrinter({this.lineLength = 800});

  final int lineLength;

  // 使用静态常量来定义所有映射关系
  static const Map<Level, String> levelEmojis = <Level, String>{
    Level.trace: '🔍',
    Level.debug: '🐞',
    Level.info: 'ℹ️',
    Level.warning: '⚠️',
    Level.error: '❌',
    Level.fatal: '🔥',
  };

  static const Map<Level, String> levelAbbr = <Level, String>{
    Level.trace: 'T',
    Level.debug: 'D',
    Level.info: 'I',
    Level.warning: 'W',
    Level.error: 'E',
    Level.fatal: 'F',
  };

  // ANSI 颜色代码优化，使用更清晰的命名和更合适的颜色
  static const Map<Level, String> _logColors = <Level, String>{
    Level.trace: '\x1B[37m', // 白色
    Level.debug: '\x1B[34m', // 蓝色
    Level.info: '\x1B[36m', // 青色
    Level.warning: '\x1B[93m', // 亮黄色
    Level.error: '\x1B[31m', // 红色
    Level.fatal: '\x1B[35m', // 紫色
  };

  @override
  List<String> log(LogEvent event) {
    final StackFrameInfo stackFrameInfo = _extractStackFrameInfo(StackTrace.current);
    String logMessage = _truncateMessage(event.message as String);
    final String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(event.time);
    if (!logMessage.endsWith('\n')) {
      logMessage = '$logMessage\n';
    }
    // 构建日志的基础部分
    final String baseLog = '${_logColors[event.level]}'
        '[$timestamp] '
        // '${levelEmojis[event.level]}'
        '${levelAbbr[event.level]}'
        '/${stackFrameInfo.fileName} ';
    // 根据 lineNumber 是否存在，决定是否添加行号
    final String formattedLog = stackFrameInfo.lineNumber != null
        ? '$baseLog[${stackFrameInfo.methodName}:${stackFrameInfo.lineNumber}]'
        : '$baseLog[${stackFrameInfo.methodName}]';
    // 移除消息中可能存在的额外换行符
    final String cleanMessage = logMessage.trimRight();

    // 返回格式化的日志行，不添加额外的换行符
    return <String>['$formattedLog: $cleanMessage\x1B[0m'];
  }

  StackFrameInfo _extractStackFrameInfo(StackTrace stackTrace) {
    final String frame = stackTrace.toString().split('\n')[4];

    // 分解栈帧信息，去除包含 '#' 的部分
    final List<String> frameParts = frame.split(' ').where((String p) => p.isNotEmpty && !p.contains('#')).toList();

    // 检查是否包含匿名闭包，并且去掉 "#4" 这样的部分
    String classNameAndMethodName;
    if (frame.contains('<anonymous')) {
      // 如果包含 <anonymous>，将整个方法名作为 classNameAndMethodName
      classNameAndMethodName = frame.split('(')[0].trim().replaceAll(RegExp(r'#\d+\s*'), '');
    } else {
      // 如果不包含匿名闭包，按原来方式提取，确保去掉 # 的部分
      classNameAndMethodName = frameParts.sublist(0, frameParts.length - 1).join(' ');
    }

    // 获取文件路径（文件名包括行号）
    final String filePath = frameParts.lastWhere((String element) => element.contains('('));
    final String fileName = _extractFileName(filePath);

    // 获取方法名（这里会使用匿名闭包的情况）
    final String methodName = _extractMethodName(classNameAndMethodName, frame);

    // 获取行号
    final String? lineNumber = _extractLineNumber(frame);

    return StackFrameInfo(
      fileName: fileName,
      methodName: methodName,
      lineNumber: lineNumber,
    );
  }

  String? _extractLineNumber(String frame) {
    final RegExp regExp = RegExp(r':(\d+):');
    final Match? match = regExp.firstMatch(frame);
    return match?.group(1);
  }

  // 提取文件名的辅助方法
  String _extractFileName(String filePath) {
    final int lastSlashIndex = filePath.lastIndexOf('/');
    final String fileNameWithLine = filePath.substring(lastSlashIndex + 1);
    return fileNameWithLine.substring(0, fileNameWithLine.indexOf(':'));
  }

  // 提取方法名的辅助方法
  String _extractMethodName(String classNameAndMethodName, String frame) {
    try {
      final List<String> parts = classNameAndMethodName.split('.');
      if (parts.isNotEmpty && parts[0] == 'new') {
        return parts.length == 1 ? _extractAnonymousMethodName(frame) : '${parts[1]}.${parts.last}';
      }

      final RegExp methodNameRegExp = RegExp(r'\.([^.<>]+)(?:<.*>)?$');
      final RegExpMatch? match = methodNameRegExp.firstMatch(classNameAndMethodName);
      if (match == null) {
        if (classNameAndMethodName.contains('<anonymous closure>') && classNameAndMethodName.startsWith('new')) {
          return _extractAnonymousMethodName(frame);
        }
        return classNameAndMethodName;
      }
      final String methodName = match.group(1)!;
      final String className = classNameAndMethodName.split('.').first;
      return '$className.$methodName';
    } catch (e) {
      return classNameAndMethodName;
    }
  }

  // 提取匿名闭包的方法名
  String _extractAnonymousMethodName(String frame) {
    final RegExp regExp = RegExp(r'([a-zA-Z0-9._]+)\._\.(<anonymous closure>)');
    final Match? match = regExp.firstMatch(frame);
    if (match != null) {
      final String className = match.group(1)!;
      final String closure = match.group(2)!;
      return '$className.$closure';
    }
    return 'AnonymousClosure'; // 如果没有匹配到，返回默认值
  }

  // 截断消息的辅助方法
  String _truncateMessage(String message) {
    return message.length > lineLength ? message.substring(0, lineLength) : message;
  }
}

// 捕获全局未处理异常
void setupErrorLogging() {
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.e('Flutter error: ${details.exceptionAsString()}', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.e('Dart error: $error', error, stack);
    return true;
  };
}

// 提取堆栈信息的模型类
class StackFrameInfo {
  StackFrameInfo({
    required this.fileName,
    required this.methodName,
    this.lineNumber,
  });

  final String fileName;
  final String methodName;
  final String? lineNumber;
}
