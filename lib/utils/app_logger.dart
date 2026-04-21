import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 统一日志工具
/// - Debug 模式：输出到控制台 + developer.log
/// - Release 模式：仅记录到 developer.log（不输出到控制台）
class AppLogger {
  static const String _defaultTag = 'InsureCRM';

  /// 调试日志
  static void debug(String message, {String tag = _defaultTag, Object? error}) {
    _log(LogLevel.debug, message, tag: tag, error: error);
  }

  /// 信息日志
  static void info(String message, {String tag = _defaultTag, Object? error}) {
    _log(LogLevel.info, message, tag: tag, error: error);
  }

  /// 警告日志
  static void warning(String message, {String tag = _defaultTag, Object? error}) {
    _log(LogLevel.warning, message, tag: tag, error: error);
  }

  /// 错误日志
  static void error(String message, {String tag = _defaultTag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void _log(LogLevel level, String message, {String tag = _defaultTag, Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = '[$timestamp] [${level.name.toUpperCase()}] [$tag]';
    final fullMessage = error != null ? '$prefix $message | Error: $error' : '$prefix $message';

    // Always log to developer.log
    developer.log(fullMessage, name: tag, level: level.value, error: error, stackTrace: stackTrace);

    // In debug mode, also print to console
    if (kDebugMode) {
      switch (level) {
        case LogLevel.error:
          developer.log(fullMessage, name: tag, level: 1000, error: error, stackTrace: stackTrace);
          break;
        default:
          break;
      }
    }
  }
}

enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const LogLevel(this.value);
  final int value;
  String get name => switch (this) {
    LogLevel.debug => 'debug',
    LogLevel.info => 'info',
    LogLevel.warning => 'warning',
    LogLevel.error => 'error',
  };
}
