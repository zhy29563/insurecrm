# 保险管理系统

一个基于 Flutter 3.x 的保险客户与产品管理系统，专为保险从业者设计。

## 功能特性

### 客户信息管理
- 姓名（支持别名）
- 年龄、性别
- 多个手机号
- 多个地址
- 产品购买历史记录
- 多次拜访记录
- 客户评级（购买意向）
- 支持按姓名、手机号、地址搜索
- 地图定位客户位置
- 按位置搜索附近客户（可选择半径）
- 客户关联功能（家人/同事）
- 添加合作同事信息

### 保险产品管理
- 产品所属公司
- 产品内容介绍
- 产品优势、产品分类
- 产品生效日期、结束日期
- 同公司产品对比
- 跨公司同类产品对比
- 根据客户信息智能推荐产品

### 界面要求
- 包含：登录页、首页、客户列表页、产品列表页、设置页
- UI 美观、简洁、专业、适合保险从业者使用
- 自适应手机、平板、电脑
- 支持深色/浅色模式

### 跨平台要求
- 支持：Android、iOS、鸿蒙、Windows、Linux、macOS、Web
- 纯 Flutter 原生实现，不引入复杂第三方依赖
- 本地数据存储，无需网络、无需后端

## 技术栈

- Flutter 3.x
- Dart
- SQLite (sqflite)
- Provider (状态管理)
- Google Maps Flutter
- Geolocator

## 运行项目

### 前提条件
- Flutter SDK 3.0 或更高版本
- Android Studio 或 VS Code
- 相应平台的开发环境

### 运行步骤
1. 克隆项目到本地
2. 进入项目目录
3. 运行以下命令：

```bash
# 安装依赖
flutter pub get

# 运行项目
flutter run
```

## 打包命令

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web
```

### Windows
```bash
flutter build windows
```

### Linux
```bash
flutter build linux
```

### macOS
```bash
flutter build macos
```

## 安装方法

### Android
1. 构建 APK 文件：`flutter build apk --release`
2. 在 `build/app/outputs/flutter-apk/` 目录找到 `app-release.apk` 文件
3. 将 APK 文件传输到 Android 设备并安装

### iOS
1. 构建 IPA 文件：`flutter build ios --release`
2. 使用 Xcode 打开 `ios/Runner.xcworkspace`
3. 在 Xcode 中选择目标设备并构建项目
4. 使用 Xcode 或 TestFlight 安装应用

### Web
1. 构建 Web 版本：`flutter build web`
2. 在 `build/web/` 目录找到构建产物
3. 将构建产物部署到 Web 服务器

### Windows
1. 构建 Windows 版本：`flutter build windows`
2. 在 `build/windows/runner/Release/` 目录找到可执行文件
3. 运行可执行文件或创建安装包

### Linux
1. 构建 Linux 版本：`flutter build linux`
2. 在 `build/linux/x64/release/bundle/` 目录找到可执行文件
3. 运行可执行文件

### macOS
1. 构建 macOS 版本：`flutter build macos`
2. 在 `build/macos/Build/Products/Release/` 目录找到应用
3. 运行应用或创建安装包

## 项目结构

```
insurance_app/
├── lib/
│   ├── database/          # 数据库相关
│   │   └── database_helper.dart
│   ├── models/            # 数据模型
│   │   ├── customer.dart
│   │   ├── product.dart
│   │   ├── visit.dart
│   │   └── colleague.dart
│   ├── pages/             # 页面
│   │   ├── login_page.dart
│   │   ├── home_page.dart
│   │   ├── customer_list_page.dart
│   │   ├── customer_detail_page.dart
│   │   ├── product_list_page.dart
│   │   ├── product_detail_page.dart
│   │   └── settings_page.dart
│   ├── providers/         # 状态管理
│   │   └── app_state.dart
│   └── main.dart          # 应用入口
├── android/               # Android 平台代码
├── ios/                   # iOS 平台代码
├── linux/                 # Linux 平台代码
├── macos/                 # macOS 平台代码
├── web/                   # Web 平台代码
├── windows/               # Windows 平台代码
└── pubspec.yaml           # 依赖配置
```

## 注意事项

- 首次运行时，应用会自动创建本地数据库
- 地图功能需要位置权限
- 本应用使用本地存储，数据保存在设备本地
- 支持离线使用，无需网络连接

## 版本信息

- 版本：1.0.0
- Flutter SDK：^3.11.5
- Dart SDK：^3.1.5