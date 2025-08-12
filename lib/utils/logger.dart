/// Simple logging utility for the app
/// Provides structured logging with different levels
library app_logger;

import 'dart:developer' as developer;

/// Log levels
enum LogLevel { debug, info, warning, error, success }

/// Application logger with structured output
class AppLogger {
  static const String _appName = 'TimexApp';

  /// Log debug message
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Log info message
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Log warning message
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Log error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// Log success message
  static void success(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.success, message, error, stackTrace);
  }

  /// Internal logging method
  static void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final String emoji = _getEmoji(level);
    final String levelName = level.name.toUpperCase();

    // Format message with emoji and level
    final String formattedMessage = '$emoji [$levelName] $message';

    // Use developer.log for better integration with debugging tools
    developer.log(
      formattedMessage,
      time: DateTime.now(),
      name: _appName,
      level: _getLogLevel(level),
      error: error,
      stackTrace: stackTrace,
    );

    // Also print to console for immediate visibility during development
    if (level == LogLevel.error) {
      print('🔴 ERROR: $message');
      if (error != null) print('   Error: $error');
      if (stackTrace != null) print('   Stack: $stackTrace');
    } else if (level == LogLevel.warning) {
      print('🟡 WARNING: $message');
    } else if (level == LogLevel.success) {
      print('🟢 SUCCESS: $message');
    } else {
      print('$emoji $message');
    }
  }

  /// Get emoji for log level
  static String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
    }
  }

  /// Get numeric log level for developer.log
  static int _getLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500; // FINE
      case LogLevel.info:
        return 800; // INFO
      case LogLevel.warning:
        return 900; // WARNING
      case LogLevel.error:
        return 1000; // SEVERE
      case LogLevel.success:
        return 800; // INFO level
    }
  }

  /// Log QPay specific events
  static void qpay(
    String action,
    String message, [
    Map<String, dynamic>? data,
  ]) {
    final String fullMessage = 'QPay.$action: $message';
    if (data != null && data.isNotEmpty) {
      info('$fullMessage | Data: $data');
    } else {
      info(fullMessage);
    }
  }

  /// Log Firebase specific events
  static void firebase(
    String action,
    String message, [
    Map<String, dynamic>? data,
  ]) {
    final String fullMessage = 'Firebase.$action: $message';
    if (data != null && data.isNotEmpty) {
      info('$fullMessage | Data: $data');
    } else {
      info(fullMessage);
    }
  }

  /// Log payment specific events
  static void payment(
    String status,
    String message, [
    Map<String, dynamic>? data,
  ]) {
    final String emoji = status.toLowerCase() == 'paid'
        ? '💰'
        : status.toLowerCase() == 'pending'
        ? '⏳'
        : status.toLowerCase() == 'failed'
        ? '💥'
        : '🔄';

    final String fullMessage = '$emoji Payment.$status: $message';
    if (data != null && data.isNotEmpty) {
      info('$fullMessage | Data: $data');
    } else {
      info(fullMessage);
    }
  }

  /// Log network requests
  static void network(
    String method,
    String url, {
    int? statusCode,
    String? error,
    Duration? duration,
  }) {
    final String emoji =
        statusCode != null && statusCode >= 200 && statusCode < 300
        ? '🌐'
        : '🚫';

    String message = '$emoji $method $url';

    if (statusCode != null) {
      message += ' → $statusCode';
    }

    if (duration != null) {
      message += ' (${duration.inMilliseconds}ms)';
    }

    if (error != null) {
      message += ' | Error: $error';
    }

    if (statusCode != null && (statusCode < 200 || statusCode >= 300)) {
      warning(message);
    } else {
      info(message);
    }
  }

  /// Log session events
  static void session(
    String event,
    String message, [
    Map<String, dynamic>? data,
  ]) {
    final String emoji = event.toLowerCase().contains('start')
        ? '🚀'
        : event.toLowerCase().contains('end')
        ? '🏁'
        : event.toLowerCase().contains('expired')
        ? '⏰'
        : '🔄';

    final String fullMessage = '$emoji Session.$event: $message';
    if (data != null && data.isNotEmpty) {
      info('$fullMessage | Data: $data');
    } else {
      info(fullMessage);
    }
  }
}
