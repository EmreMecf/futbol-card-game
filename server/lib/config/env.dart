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

  // ---- GELISTIRME VARSAYILANLARI ----
  // Depo herkese acik oldugu icin bu iki deger HERKESIN bildigi
  // degerlerdir. Uretimde kullanilmalari, JWT icin "herkes istedigi
  // kullanici adina jeton uretebilir", DB icin "herkes veritabanina
  // baglanabilir" demektir. Bkz. [productionProblems].
  static const String devJwtSecret =
      'gelistirme-icin-gecici-anahtar-uretimde-degistir';
  static const String devDbPassword = 'futbol_dev_sifre_2026';

  /// JWT anahtari icin kabul edilen en kisa uzunluk.
  /// HMAC-SHA256 icin 32 bayt (256 bit) onerilen alt sinir.
  static const int minJwtSecretLength = 32;

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
  static String get dbPassword => str('DB_PASSWORD', devDbPassword);

  // ---- GUVENLIK ----
  /// JWT imzalama anahtari. URETIMDE DEGISTIR!
  static String get jwtSecret => str('JWT_SECRET', devJwtSecret);

  /// Access token omru (dakika). Kisa tutuluyor ki calinirsa zarar sinirli olsun.
  static int get accessTokenMinutes => intVal('ACCESS_TOKEN_MINUTES', 15);

  /// Refresh token omru (gun). Kullanici bu sure boyunca tekrar giris yapmaz.
  static int get refreshTokenDays => intVal('REFRESH_TOKEN_DAYS', 30);

  // ---- ZAMANLAYICI ----
  /// Suresi dolmus maclarin taranma araligi (saniye)
  static int get sweepIntervalSeconds => intVal('SWEEP_INTERVAL_SECONDS', 15);

  static bool get isProduction =>
      str('ENVIRONMENT', 'development') == 'production';

  /// Uretim ortaminda sunucunun ACILMASINI ENGELLEYEN sorunlar.
  ///
  /// Bos liste = guvenli. Doluysa sunucu baslamaz.
  ///
  /// NEDEN UYARI DEGIL DE ENGEL?
  /// Uyari konsola yazilir ve kimse okumaz. Sunucu varsayilan anahtarla
  /// sessizce acilirsa ilk fark edilisi bir saldiri sonrasi olur.
  /// Acilmayan bir sunucuyu ise herkes ilk dakikada fark eder.
  ///
  /// Saf fonksiyon: ortam degiskenlerini parametre olarak aliyor, boylece
  /// gercek ortami degistirmeden test edilebiliyor.
  static List<String> productionProblems(Map<String, String> ortam) {
    String? oku(String anahtar) {
      final v = ortam[anahtar];
      return (v == null || v.isEmpty) ? null : v;
    }

    final sorunlar = <String>[];

    final jwt = oku('JWT_SECRET');
    if (jwt == null) {
      sorunlar.add('JWT_SECRET ayarlanmamis.');
    } else if (jwt == devJwtSecret) {
      sorunlar.add('JWT_SECRET gelistirme varsayilani; depoda herkese acik.');
    } else if (jwt.length < minJwtSecretLength) {
      sorunlar.add(
        'JWT_SECRET cok kisa (${jwt.length} karakter, '
        'en az $minJwtSecretLength olmali).',
      );
    }

    final sifre = oku('DB_PASSWORD');
    if (sifre == null) {
      sorunlar.add('DB_PASSWORD ayarlanmamis.');
    } else if (sifre == devDbPassword) {
      sorunlar.add('DB_PASSWORD gelistirme varsayilani; depoda herkese acik.');
    }

    return sorunlar;
  }
}
