# flutter-cj-kit
### 添加依赖
```bash
flutter_cj_kit:
    git:
      url: git@github.com:chenjun1127/flutter-cj-kit.git
      ref: 0.0.1-dev # tag 对应版本
```
### 修改App入口
```bash
将runApp(App())替换为CjKit.runApp(App())
```
### 使用示例
```dart
void setupLoggingSystem() async {
  // 方案1：使用默认配置（7天保留，24小时清理一次）
  await AppLogger.init();

  // 方案2：自定义配置
  await AppLogger.init(
    maxSizeBytes: 20 * 1024 * 1024, // 20MB
    retentionDays: 14,              // 保留14天
    cleanupInterval: Duration(hours: 12), // 12小时清理一次
    enableAutoCleanup: true,        // 启用自动清理
  );

  // 方案3：只在特定条件下清理
  await AppLogger.init(
    retentionDays: 30,              // 保留30天
    enableAutoCleanup: false,       // 不自动清理
  );

  // 手动清理（使用自定义天数）
  await AppLogger.cleanOldLogs(5); // 清理5天前的日志
}
```

### 日志管理功能

```dart
// 获取当前配置
Map<String, dynamic> config = AppLogger.getConfig();

// 停止自动清理
AppLogger.stopAutoCleanup();

// 获取日志统计
Map<String, dynamic> stats = await LoggerUtils.getLogStats();
```