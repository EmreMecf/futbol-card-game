import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';

final _teklif = RegExp(r'^[a-z0-9_]{3,60}$');
final _anahtar = RegExp(r'^[A-Za-z0-9_\-:]{8,100}$');

(String, String) _istemci(Request r, [Map<String, dynamic>? govde]) {
  final p = (govde?['platform'] ?? r.url.queryParameters['platform'] ?? r.headers['x-app-platform'] ?? '').toString();
  final v = (govde?['app_version'] ?? r.url.queryParameters['app_version'] ?? r.headers['x-app-version'] ?? '')
      .toString();
  return (p.toLowerCase().trim(), v.trim());
}

/// 062 — KOZMETİK MAĞAZA (oturum gerekli).
///
///   GET  `/api/shop/cosmetics`        bakiyeler + teklifler (sahip olunanlar işaretli)
///   POST `/api/shop/cosmetics/buy`    `{offer_id, request_key, platform, app_version}`
///
/// Fiyat ve içerik yalnız sunucuda; istemci yalnız teklif kimliği gönderir.
/// Önce ücretsiz, sonra ücretli elmas harcanır. Aynı `request_key` tekrar
/// gelirse ikinci kez harcanmaz.
/// Hata kodları: shop_disabled, offer_not_available, already_owned,
/// not_enough_gems, invalid_request
Router cosmeticShopRoutes(Database db) {
  final router = Router();

  router.get('/cosmetics', (Request request) async {
    final userId = requireUserId(request);
    final (p, v) = _istemci(request);
    return jsonOk(RowMappers.asMap(await db.scalar('select cosmetic_shop(@u::uuid, @p, @v)',
        params: {'u': userId, 'p': p, 'v': v})));
  });

  router.post('/cosmetics/buy', (Request request) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final teklif = govde['offer_id']?.toString() ?? '';
    final anahtar = govde['request_key']?.toString() ?? '';
    if (!_teklif.hasMatch(teklif)) {
      throw const ApiException('Teklif bulunamadi.', status: 404, code: 'offer_not_found');
    }
    if (!_anahtar.hasMatch(anahtar)) {
      throw const ApiException('Istek anahtari gecersiz.', status: 400, code: 'invalid_request');
    }
    final (p, v) = _istemci(request, govde);
    return withRuleCodes(() async => jsonOk(RowMappers.asMap(await db.scalar(
          'select buy_cosmetic(@u::uuid, @o, @p, @v, @k)',
          params: {'u': userId, 'o': teklif, 'p': p, 'v': v, 'k': anahtar},
        ))));
  });

  return router;
}
