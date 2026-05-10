import 'package:flutter/foundation.dart';

class AppLogger {
  static void e(String tag, Object error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR: $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
  }
}
