import 'package:logging/logging.dart';

/// Internal logger mixin. Not exported.
mixin LoggerMixin {
  static final Logger _logger = Logger('flutter_openai_realtime_api');

  void logInfo(String message) => _logger.info(message);
  void logWarning(String message) => _logger.warning(message);
  void logError(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
  void logVerbose(String message) => _logger.fine(message);
}

/// Optional helper to attach a console listener to the package's logger.
///
/// Call once at app startup if you want library logs printed.
class RealtimeLogging {
  static bool _attached = false;

  /// Routes the package's logger to `print`. Subsequent calls are no-ops.
  ///
  /// [level] sets the minimum severity that will be printed. Defaults to
  /// [Level.INFO]; pass [Level.ALL] for verbose debugging.
  static void enableConsoleOutput({Level level = Level.INFO}) {
    if (_attached) return;
    _attached = true;
    Logger.root.level = level;
    Logger.root.onRecord.listen((r) {
      // ignore: avoid_print
      print('[${r.time.toIso8601String()}] ${r.level.name} '
          '${r.loggerName}: ${r.message}');
      if (r.error != null) {
        // ignore: avoid_print
        print('  error: ${r.error}');
      }
      if (r.stackTrace != null) {
        // ignore: avoid_print
        print(r.stackTrace);
      }
    });
  }
}
