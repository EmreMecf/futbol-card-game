import 'dart:convert';

import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../config/env.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/idempotency.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';

/// EKONOMİ V2 (FAZ 3, 034) — item kataloğu ve envanter.
///
/// Hiçbir item dereceli maçta güç vermez (K1). Kullanım veritabanında tek
/// işlem: miktar düşer + etki + defter; aynı istek kimliğiyle tekrar
/// ikinci kez kullanmaz.
///
/// Hata kodları: economy_disabled, item_not_found, item_not_usable,
/// item_not_applicable, not_enough_items, daily_limit, chest_not_found,
/// card_not_owned, max_level, invalid_count
Router itemRoutes(Database db) {
  final router = Router();

  // GET /api/items — katalog + sahip olunanlar + giyilenler
  router.get('/', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select item_inventory(@u::uuid)', params: {'u': userId});
    return jsonOk(ItemInventory.fromJson(RowMappers.asMap(ham)).toJson());
  });

  // POST /api/items/<slug>/use  {"target": {"chest_id": ...} | {"card_id": ...}}
  router.post('/<slug>/use', (Request request, String slug) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final hedef = govde['target'] is Map ? govde['target'] as Map : const {};
    final anahtar = request.headers[kIdempotencyHeader] ?? '';
    return withRuleCodes(() async {
      final ham = await db.scalar('select use_item(@u::uuid, @s, @t::jsonb, @k)',
          params: {'u': userId, 's': slug, 't': jsonEncode(hedef), 'k': anahtar});
      return jsonOk(RowMappers.asMap(ham));
    });
  });

  // POST /api/items/<slug>/equip — kozmetik giy
  router.post('/<slug>/equip', (Request request, String slug) async {
    final userId = requireUserId(request);
    return withRuleCodes(() async {
      final ham = await db.scalar('select equip_cosmetic(@u::uuid, @s)', params: {'u': userId, 's': slug});
      return jsonOk(RowMappers.asMap(ham));
    });
  });

  // POST /api/items/unequip/<slot> — kozmetik çıkar
  router.post('/unequip/<slot>', (Request request, String slot) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select unequip_cosmetic(@u::uuid, @s)', params: {'u': userId, 's': slot});
    return jsonOk(RowMappers.asMap(ham));
  });

  // POST /api/items/dev/grant {"slug": ..., "qty": 1} — YALNIZ geliştirme
  router.post('/dev/grant', (Request request) async {
    if (Env.isProduction) return jsonError('Boyle bir uc nokta yok.', status: 404);
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    return withRuleCodes(() async {
      final ham = await db.scalar('select dev_grant_item(@u::uuid, @s, @q)',
          params: {'u': userId, 's': govde['slug'], 'q': (govde['qty'] as num?)?.toInt() ?? 1});
      return jsonOk(RowMappers.asMap(ham));
    });
  });

  return router;
}
