import 'dart:io';

/// Sunucu ayarlari. Hepsi ortam degiskeninden okunur, yoksa
/// gelistirme icin makul bir varsayilan kullanilir.
///
/// Uretimde JWT_SECRET'i MUTLAKA degistir. Varsayilan degerle
/// yayina cikarsan herkes kendine jeton uretebilir.
class Env {
  const Env._();

  static String str(String key, String fallback) {
    final v = Platform.environment[key];
    return (v == null || v.isEmpty) ? fallback : v;
  }

  static int intVal(String key, int fallback) {
    final v = Platform.environment[key];
    if (v == null || v.isEmpty) return fallback;
    return int.tryParse(v) ?? fallback;
  }

  // ---- SUNUCU ----
  static String get host => str('HOST', '0.0.0.0');
  static int get port => intVal('PORT', 8080);

  // ---- VERITABANI ----
  static String get dbHost => str('DB_HOST', 'localhost');
  static int get dbPort => intVal('DB_PORT', 5432);
  static String get dbName => str('DB_NAME', 'futbol_card');
  static String get dbUser => str('DB_USER', 'futbol');
  static String get dbPassword => str('DB_PASSWORD', 'futbol_dev_sifre_2026');

  // ---- GUVENLIK ----
  /// JWT imzalama anahtari. URETIMDE DEGISTIR!
  static String get jwtSecret =>
      str('JWT_SECRET', 'gelistirme-icin-gecici-anahtar-uretimde-degistir');

  /// Access token omru (dakika). Kisa tutuluyor ki calinirsa zarar sinirli olsun.
  static int get accessTokenMinutes => intVal('ACCESS_TOKEN_MINUTES', 15);

  /// Refresh token omru (gun). Kullanici bu sure boyunca tekrar giris yapmaz.
  static int get refreshTokenDays => intVal('REFRESH_TOKEN_DAYS', 30);

  // ---- ZAMANLAYICI ----
  /// Suresi dolmus maclarin taranma araligi (saniye)
  static int get sweepIntervalSeconds => intVal('SWEEP_INTERVAL_SECONDS', 15);

  static bool get isProduction =>
      str('ENVIRONMENT', 'development') == 'production';
}
