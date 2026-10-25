import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i('[RESQ] $message', error: error, stackTrace: stackTrace);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w('[RESQ] $message', error: error, stackTrace: stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e('[RESQ] $message', error: error, stackTrace: stackTrace);
  }

  static void mesh(String message) {
    _logger.d('📡 [MESH] $message');
  }

  static void ai(String message) {
    _logger.d('🧠 [AI-EDGE] $message');
  }
}
