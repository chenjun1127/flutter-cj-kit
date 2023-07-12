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
将runApp(App())替换为OrviboKit.runApp(app: OrviboKitApp(App(),appVersion: "1.0"))，
appVersion为可选参数,可直接修改OrviboKitApp.version变量。
```
