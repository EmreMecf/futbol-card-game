import 'dart:io';

import 'package:shelf/shelf.dart';

import 'api_response.dart';

// =====================================================================
// GÜVENLİK ARA KATMANLARI (FAZ 7 kalite kontrolünde eklendi)
// =====================================================================

// ---------------------------------------------------------------------
// 1) İSTEK SINIRLAYICI (rate limit)
// ---------------------------------------------------------------------
/// Bir anahtar (ör. "IP + uç nokta") için belirli bir sürede en fazla
/// [maxRequests] isteğe izin verir. Kayan pencere.
///
/// NEDEN GEREKLİ?
///   * Şifre deneme saldırısı: sınırsız girişle bir hesabın şifresi
///     denenebilir.
///   * İşlemci saldırısı: her giriş bcrypt yüzünden ~250 ms işlemci
///     harcıyor. Saniyede birkaç yüz giriş isteği sunucuyu kilitler.
///
/// SINIR: Bellekte tutuluyor; TEK sunucu örneği için doğru çalışır.
/// Birden fazla sunucu arkasında yük dengeleyici olursa bu sayaç
/// paylaşılmaz ve sınır örnek sayısıyla çarpılır (teknik borç: o
/// noktada Redis gibi ortak bir depo gerekir).
class RateLimiter {
  final int maxRequests;
  final Duration window;

  /// Test için saat dışarıdan verilebilir
  final DateTime Function() _now;

  final Map<String, List<DateTime>> _kayitlar = {};
  int _cagri = 0;

  RateLimiter({
    required this.maxRequests,
    required this.window,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// İstek kabul edilirse null, reddedilirse kaç saniye beklenmesi
  /// gerektiğini döner.
  int? hit(String key) {
    final simdi = _now();
    final esik = simdi.subtract(window);

    // Bellek sızmasın: arada bir bütün eski kayıtları temizle
    if (++_cagri % 500 == 0) _temizle(esik);

    final liste = _kayitlar.putIfAbsent(key, () => []);
    liste.removeWhere((t) => !t.isAfter(esik));

    if (liste.length >= maxRequests) {
      final bekle = liste.first.add(window).difference(simdi).inSeconds + 1;
      return bekle < 1 ? 1 : bekle;
    }
    liste.add(simdi);
    return null;
  }

  void _temizle(DateTime esik) {
    _kayitlar.removeWhere((_, liste) {
      liste.removeWhere((t) => !t.isAfter(esik));
      return liste.isEmpty;
    });
  }

  /// Takip edilen anahtar sayısı (test ve izleme için)
  int get trackedKeys => _kayitlar.length;
}

/// İsteği yapan istemcinin IP adresi.
///
/// X-Forwarded-For'a SADECE [trustProxy] açıksa güvenilir: aksi halde
/// saldırgan başlığı her istekte değiştirip sınırı aşabilirdi.
String clientIp(Request request, {bool trustProxy = false}) {
  if (trustProxy) {
    final ileri = request.headers['x-forwarded-for'];
    if (ileri != null && ileri.isNotEmpty) return ileri.split(',').first.trim();
  }
  final bilgi = request.context['shelf.io.connection_info'];
  if (bilgi is HttpConnectionInfo) return bilgi.remoteAddress.address;
  return 'bilinmiyor';
}

/// Uç nokta başına IP sınırı uygular. Aşılırsa 429 döner.
Middleware rateLimit(RateLimiter limiter, {bool trustProxy = false}) {
  return (Handler inner) {
    return (Request request) async {
      final anahtar = '${clientIp(request, trustProxy: trustProxy)}'
          '|${request.method}|${request.url.path}';
      final bekle = limiter.hit(anahtar);
      if (bekle != null) {
        final cevap = jsonError(
          'Cok fazla deneme yaptiniz. Lutfen $bekle saniye sonra tekrar deneyin.',
          status: 429,
          code: 'rate_limited',
        );
        return cevap.change(headers: {'retry-after': '$bekle'});
      }
      return inner(request);
    };
  };
}

// ---------------------------------------------------------------------
// 2) GÜNLÜKTE JETON GİZLEME
// ---------------------------------------------------------------------
/// Günlüğe yazılacak adresteki gizli parametreleri maskeler.
///
/// WebSocket adresi `ws?token=eyJ...` biçiminde. Eskiden istek
/// günlükçüsü adresi olduğu gibi yazıyordu: her bağlantıda oyuncunun
/// jetonu sunucu günlüğüne düşüyordu. Günlüğü okuyabilen biri o oyuncu
/// adına 15 dakika işlem yapabilirdi.
String redactUrl(Uri url) {
  const gizli = {'token', 'access_token', 'refresh_token', 'password'};
  if (url.queryParameters.keys.every((k) => !gizli.contains(k))) {
    return url.toString();
  }
  final temiz = {
    for (final e in url.queryParameters.entries)
      e.key: gizli.contains(e.key) ? 'gizli' : e.value,
  };
  return url.replace(queryParameters: temiz).toString();
}

// ---------------------------------------------------------------------
// 3) CORS
// ---------------------------------------------------------------------
/// Tarayıcı isteklerine izin verilen köken.
///
/// Mobil uygulama CORS'a tabi değil; bu sadece Flutter Web için.
/// Geliştirmede '*'. Üretimde CORS_ORIGIN ile web sitesinin adresi
/// verilmeli (ör. https://oyun.ornek.com). Jetonlar çerezde değil
/// Authorization başlığında taşındığı için '*' doğrudan hesap ele
/// geçirmeye yol açmaz, ama kısıtlamak iyi uygulamadır.
Middleware corsHeaders({String allowOrigin = '*'}) {
  final headers = {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    if (allowOrigin != '*') 'Vary': 'Origin',
    // Basit güvenlik başlıkları
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
  };

  return (Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await inner(request);
      return response.change(headers: headers);
    };
  };
}

/// Serbest metindeki (hata mesajı, yığın izi) jetonları maskeler.
///
/// [redactUrl] sadece adresi temizler; ama bir istisna mesajı adresi
/// veya jetonu kendi içinde taşıyabilir. JWT'ler her zaman "eyJ" ile
/// başlayan üç parçalı base64url dizileridir.
String redactText(String metin) => metin
    .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'), 'gizli')
    .replaceAllMapped(RegExp(r'(token=)[^&\s:]+'), (m) => '${m[1]}gizli');
