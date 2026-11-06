import 'package:flutter/foundation.dart';
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
  ///
  /// YAYIN DERLEMESI: adres derleme aninda verilir ve .env'yi ezer:
  ///   flutter build appbundle --release \
  ///     --dart-define=API_BASE_URL=https://api.ornek.com
  ///
  /// NEDEN? .env dosyasi pakete gomuluyor; gelistiricinin .env'sinde
  /// `http://localhost:8080` yaziyorsa yayin paketi de oraya baglanmaya
  /// calisiyordu (telefonda "localhost" telefonun kendisidir). Ayrica
  /// Android/iOS yayin surumleri sifresiz http'yi engeller: uretimde
  /// https sart. (FAZ 7'de bulundu)
  static String get apiBaseUrl {
    const derleme = String.fromEnvironment('API_BASE_URL');
    final ham = derleme.isNotEmpty ? derleme : _read('API_BASE_URL');
    return ham.endsWith('/') ? ham.substring(0, ham.length - 1) : ham;
  }

  /// WebSocket adresi. Verilmezse REST adresinden turetilir.
  static String get wsUrl {
    const derleme = String.fromEnvironment('WS_URL');
    if (derleme.isNotEmpty) return derleme;
    final ozel = dotenv.env['WS_URL'];
    if (ozel != null && ozel.isNotEmpty) return ozel;

    // http -> ws, https -> wss
    final temel = apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$temel/ws';
  }

  /// Gelistirme modunda konsola ayrintili log basilsin mi.
  ///
  /// YAYIN derlemesinde HER ZAMAN kapali: Android'de konsol cikisi
  /// (logcat) baska uygulamalarca / USB ile okunabilir; ayrintili ag
  /// gunlugunun kullanicinin telefonunda durmasi gereksiz risk.
  static bool get enableLogging {
    if (kReleaseMode) return false;
    return (dotenv.env['ENABLE_LOGGING'] ?? 'true').toLowerCase() == 'true';
  }

  /// Yayin derlemesi guvensiz bir adrese mi bagli? (http veya localhost)
  ///
  /// Uygulama acilisinda yayin modunda kontrol edilir; boyle bir paket
  /// gercek telefonda hicbir yere baglanamaz.
  static String? releaseConfigProblem(String apiUrl) {
    final u = Uri.tryParse(apiUrl);
    if (u == null || !u.hasScheme) return 'API_BASE_URL gecersiz: $apiUrl';
    if (u.scheme != 'https') {
      return 'Yayin derlemesi https gerektirir (su an: $apiUrl). '
          '--dart-define=API_BASE_URL=https://... ile derleyin.';
    }
    const yerel = {'localhost', '127.0.0.1', '10.0.2.2', '0.0.0.0'};
    if (yerel.contains(u.host)) {
      return 'Yayin derlemesi yerel adrese bagli ($apiUrl).';
    }
    return null;
  }

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
