import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/idempotency.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

String _id(String v) {
  if (!_uuid.hasMatch(v)) throw const ApiException('Oyuncu bulunamadi.', status: 404, code: 'player_not_found');
  return v;
}

/// 056 — SOSYAL: arkadaşlık, oyuncu arama, açık profil.
///
/// Bütün kurallar veritabanında (056); bu dosya yalnız taşır. Her istek
/// çağıranın "son görülme" zamanını tazeler (arkadaş listesinde çevrimiçi).
///
///   GET    `/api/social/friends`                  arkadaşlar + gelen/giden istekler
///   POST   `/api/social/friends/<id>`             istek gönder (karşılıklıysa kabul)
///   POST   `/api/social/friends/<id>/accept`      gelen isteği kabul et
///   POST   `/api/social/friends/<id>/decline`     gelen isteği reddet
///   DELETE `/api/social/friends/<id>`             arkadaşlıktan çıkar / isteği geri çek
///   GET    `/api/social/search?q=ad`              ada göre oyuncu ara (en az 2 harf)
///   GET    `/api/social/players/<id>`             açık profil
///
/// Hata kodları: friend_self, player_not_found, friend_limit,
/// friend_request_limit, friend_request_not_found
Router socialRoutes(Database db) {
  final router = Router();

  Future<String> kim(Request request) async {
    final userId = requireUserId(request);
    await db.query('update users set last_seen_at = now() where id = @u::uuid', params: {'u': userId});
    return userId;
  }

  router.get('/friends', (Request request) async {
    final userId = await kim(request);
    return jsonOk(RowMappers.asMap(await db.scalar('select friend_list(@u::uuid)', params: {'u': userId})));
  });

  router.post('/friends/<id>', (Request request, String id) async {
    final userId = await kim(request);
    return withRuleCodes(() async => jsonOk(RowMappers.asMap(await db.scalar(
          'select friend_request(@u::uuid, @t::uuid)',
          params: {'u': userId, 't': _id(id)},
        ))));
  });

  Future<Response> yanit(Request request, String id, bool kabul) async {
    final userId = await kim(request);
    return withRuleCodes(() async => jsonOk(RowMappers.asMap(await db.scalar(
          'select friend_respond(@u::uuid, @t::uuid, @a)',
          params: {'u': userId, 't': _id(id), 'a': kabul},
        ))));
  }

  router.post('/friends/<id>/accept', (Request request, String id) => yanit(request, id, true));
  router.post('/friends/<id>/decline', (Request request, String id) => yanit(request, id, false));

  router.delete('/friends/<id>', (Request request, String id) async {
    final userId = await kim(request);
    return jsonOk(RowMappers.asMap(
      await db.scalar('select friend_remove(@u::uuid, @t::uuid)', params: {'u': userId, 't': _id(id)}),
    ));
  });

  router.get('/search', (Request request) async {
    final userId = await kim(request);
    final q = (request.url.queryParameters['q'] ?? '').trim();
    if (q.length > 20) return jsonOk({'players': const []});
    final ham = await db.scalar('select search_players(@u::uuid, @q)', params: {'u': userId, 'q': q});
    return jsonOk({'players': ham is List ? ham : const []});
  });

  router.get('/players/<id>', (Request request, String id) async {
    final userId = await kim(request);
    final ham = await db.scalar('select public_profile(@u::uuid, @t::uuid)', params: {'u': userId, 't': _id(id)});
    if (ham == null) throw const ApiException('Oyuncu bulunamadi.', status: 404, code: 'player_not_found');
    return jsonOk(RowMappers.asMap(ham));
  });

  return router;
}

/// 056 — ELMAS
///
///   GET  `/api/gems`                     bakiye, altın teklifleri, yuvadaki sandıkların elmas bedeli
///   POST `/api/gems/exchange` {offer}    elmasla altın paketi (Idempotency-Key ZORUNLU)
///
/// Sandığı elmasla açma: `POST /api/chests/<id>/open-gems` (sandık uçlarında).
/// Hata kodları: not_enough_gems, offer_not_found
Router gemRoutes(Database db) {
  final router = Router();

  router.get('/', (Request request) async {
    final userId = requireUserId(request);
    return jsonOk(RowMappers.asMap(await db.scalar('select gem_status(@u::uuid)', params: {'u': userId})));
  });

  router.post('/exchange', (Request request) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final teklif = govde['offer']?.toString() ?? '';
    final anahtar = request.headers[kIdempotencyHeader] ?? '';
    return withRuleCodes(() async => jsonOk(RowMappers.asMap(await db.scalar(
          'select buy_coins_with_gems(@u::uuid, @o, @k)',
          params: {'u': userId, 'o': teklif, 'k': anahtar},
        ))));
  });

  return router;
}
