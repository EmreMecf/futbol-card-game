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

  /// Tarayicidan (Flutter Web) erisime izin verilen koken.
  /// Uretimde web sitenin adresi verilmeli: https://oyun.ornek.com
  static String get corsOrigin => str('CORS_ORIGIN', '*');

  /// Sunucu bir ters vekil (nginx, yuk dengeleyici) arkasindaysa true.
  /// O zaman istemci IP'si X-Forwarded-For'dan okunur. Vekil YOKKEN
  /// acilirsa saldirgan basligi degistirip istek sinirini atlatabilir.
  static bool get trustProxy => str('TRUST_PROXY', 'false') == 'true';

  /// /auth uclarina IP basina dakikada izin verilen istek
  static int get authRateLimitPerMinute => intVal('AUTH_RATE_LIMIT', 20);

  // ---- GOOGLE / APPLE GIRISI ----
  /// Kabul edilen Google istemci kimlikleri (virgulle ayrilmis: web, iOS).
  /// Bos ise Google girisi kapalidir.
  static Set<String> get googleClientIds => _csv('GOOGLE_CLIENT_IDS');

  /// Kabul edilen Apple kimlikleri (virgulle ayrilmis: iOS paket kimligi, web Services ID).
  /// Bos ise Apple girisi kapalidir.
  static Set<String> get appleClientIds => _csv('APPLE_CLIENT_IDS');

  static Set<String> _csv(String key) =>
      str(key, '').split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();

  // ---- ZAMANLAYICI ----
  /// Suresi dolmus maclarin taranma araligi (saniye)
  static int get sweepIntervalSeconds => intVal('SWEEP_INTERVAL_SECONDS', 15);

  static bool get isProduction =>
      str('ENVIRONMENT', 'development') == 'production';

  // ---- MONETİZASYON (060) ----
  /// Dağıtım aşaması: local | staging | production. Staging de
  /// ENVIRONMENT=production ile çalıştığı için test sağlayıcılarını bu
  /// değer ayırır. Tanımsızsa "production" sayılır (fail-closed).
  static String get deployStage => str('DEPLOY_STAGE', isProduction ? 'production' : 'local');

  /// Test sağlayıcıları (SSV benzetimi, ileride sandbox satın alma).
  /// ÜRETİMDE HİÇBİR KOŞULDA AÇILMAZ: DEPLOY_STAGE=production iken false.
  static bool get monetizationTestProviders =>
      deployStage != 'production' && str('MONETIZATION_TEST_PROVIDERS', 'false') == 'true';

  // ---- SATIN ALMA (061). Değerler GİZLİ: depoya değil Render ortamına ----
  static String get googlePlayPackageName => str('GOOGLE_PLAY_PACKAGE_NAME', 'com.futbolcard.futbol_card');
  static String get googlePlayServiceAccountJson => str('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', '');
  /// RTDN (Pub/Sub itme) için: OIDC jetonunun hedef kitlesi ve gönderen hizmet hesabı
  static String get googleRtdnAudience => str('GOOGLE_RTDN_AUDIENCE', '');
  static String get googleRtdnServiceAccount => str('GOOGLE_RTDN_SERVICE_ACCOUNT', '');
  static String get appleBundleId => str('APPLE_BUNDLE_ID', 'com.futbolcard.futbolCard');
  static String get appleIapKeyId => str('APPLE_IAP_KEY_ID', '');
  static String get appleIapIssuerId => str('APPLE_IAP_ISSUER_ID', '');
  /// .p8 içeriği; ortamda "\n" ile tek satır verilebilir
  static String get appleIapPrivateKey => str('APPLE_IAP_PRIVATE_KEY', '').replaceAll(r'\n', '\n');

  /// AdMob SSV açık anahtar adresi (varsayılan Google'ın resmi adresi)
  static String get admobSsvKeysUrl =>
      str('ADMOB_SSV_KEYS_URL', 'https://www.gstatic.com/admob/reward/verifier-keys.json');

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
