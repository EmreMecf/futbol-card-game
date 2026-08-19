import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import 'api_response.dart';

/// Tum hatalari yakalayip TURKCE JSON cevabina cevirir.
///
/// EN ONEMLI KISIM: PostgreSQL fonksiyonlarimiz `raise exception` ile
/// Turkce mesaj firlatiyor (ornek: "Sira sizde degil."). Bu mesajlar
/// SQLSTATE P0001 kodu ile gelir ve dogrudan kullaniciya gosterilir.
/// Boylece oyun kurallarina dair aciklamalar tek yerde - veritabaninda -
/// yonetiliyor.
Middleware errorHandler() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on ApiException catch (e) {
        return jsonError(e.message, status: e.status, code: e.code);
      } on ServerException catch (e) {
        // P0001 = bizim yazdigimiz oyun kurali mesajlari
        if (e.code == 'P0001') {
          return jsonError(e.message, status: 400, code: 'game_rule');
        }
        // 23505 = benzersizlik ihlali (ornek: ayni e-posta)
        if (e.code == '23505') {
          return jsonError(
            'Bu kayit zaten mevcut.',
            status: 409,
            code: 'duplicate',
          );
        }
        // ignore: avoid_print
        print('[HATA] Veritabani hatasi ${e.code}: ${e.message}');
        return jsonError(
          'Sunucuda bir sorun olustu. Lutfen tekrar deneyin.',
          status: 500,
          code: 'db_error',
        );
      } catch (e, s) {
        // ignore: avoid_print
        print('[HATA] Beklenmeyen: $e\n$s');
        return jsonError(
          'Beklenmeyen bir hata olustu.',
          status: 500,
          code: 'internal',
        );
      }
    };
  };
}

/// Gelen istekleri konsola yazar (gelistirme kolayligi).
Middleware requestLogger() {
  return (Handler innerHandler) {
    return (Request request) async {
      final basladi = DateTime.now();
      final response = await innerHandler(request);
      final sure = DateTime.now().difference(basladi).inMilliseconds;
      // ignore: avoid_print
      print('[${response.statusCode}] ${request.method} /${request.url} (${sure}ms)');
      return response;
    };
  };
}

/// Flutter Web'den gelistirme yaparken tarayici engellemesin diye CORS.
Middleware corsHeaders() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: headers);
    };
  };
}
