import 'package:flutter/foundation.dart';

/// Debug-only logging. Replaces raw `print()` calls, which otherwise ship
/// straight into release console output (visible via `adb logcat` with no
/// root) and cost cycles formatting strings nobody will read in production.
///
/// Usage mirrors `print`: `AppLogger.d('message')`. Nothing is emitted
/// outside of debug builds (`kDebugMode`).
class AppLogger {
  AppLogger._();

  /// General debug output.
  static void d(Object? message) {
    if (kDebugMode) {
      debugPrint(message.toString());
    }
  }

  /// Non-fatal error/warning output — still debug-only, but visually
  /// distinct so real problems stand out while scrolling logs.
  static void e(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('⛔ $message${error != null ? ' — $error' : ''}');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
