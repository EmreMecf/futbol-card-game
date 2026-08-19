import 'dart:developer' as developer;

import '../config/app_config.dart';

/// Basit ve bagimsiz log yardimcisi.
/// Uretimde (release) sadece hatalar basilir.
class AppLogger {
  const AppLogger._();

  static void info(String message, {String tag = 'BILGI'}) {
    if (!AppConfig.enableLogging) return;
    developer.log(message, name: tag);
  }

  static void warning(String message, {String tag = 'UYARI'}) {
    if (!AppConfig.enableLogging) return;
    developer.log(message, name: tag);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = 'HATA',
  }) {
    developer.log(message, name: tag, error: error, stackTrace: stackTrace);
  }
}
