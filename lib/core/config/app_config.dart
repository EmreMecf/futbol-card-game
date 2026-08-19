import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Uygulama genelindeki ortam ayarlari.
///
/// Supabase birakildi; artik kendi backend'imize baglaniyoruz.
/// Adresler `.env` dosyasindan okunur ki emulator, gercek cihaz ve
/// yayin ortami icin ayri ayri derleme yapmak gerekmesin.
class AppConfig {
  const AppConfig._();

  /// Backend REST adresi.
  ///
  /// ADRES SECERKEN DIKKAT:
  ///   * Android emulator  -> http://10.0.2.2:8080   (127.0.0.1 emulatorun kendisidir)
  ///   * iOS simulator     -> http://localhost:8080
  ///   * Gercek telefon    -> `http://<bilgisayarinin-yerel-ip>:8080`
  ///                          (ornek: http://192.168.1.35:8080)
  static String get apiBaseUrl {
    final ham = _read('API_BASE_URL');
    return ham.endsWith('/') ? ham.substring(0, ham.length - 1) : ham;
  }

  /// WebSocket adresi. Verilmezse REST adresinden turetilir.
  static String get wsUrl {
    final ozel = dotenv.env['WS_URL'];
    if (ozel != null && ozel.isNotEmpty) return ozel;

    // http -> ws, https -> wss
    final temel = apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$temel/ws';
  }

  /// Gelistirme modunda konsola ayrintili log basilsin mi
  static bool get enableLogging =>
      (dotenv.env['ENABLE_LOGGING'] ?? 'true').toLowerCase() == 'true';

  /// Ag isteklerinin zaman asimi (saniye)
  static int get requestTimeoutSeconds =>
      int.tryParse(dotenv.env['REQUEST_TIMEOUT_SECONDS'] ?? '') ?? 20;

  static String _read(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        '.env dosyasinda "$key" tanimli degil. '
        'Proje kokundeki .env.example dosyasini .env olarak kopyalayip doldurun.',
      );
    }
    return value;
  }
}
