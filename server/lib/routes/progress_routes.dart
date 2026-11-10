import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/idempotency.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';

/// EKONOMİ V2 (FAZ 2, 033) — futbolcu seviyesi.
///
/// K1 (onaylı): seviye dereceli maçta kart gücünü DEĞİŞTİRMEZ. Bu uçlar
/// yalnız gelişim, ustalık ödülü ve gönüllü kopya dönüşümü içindir.
/// Değiştirici uçlar Idempotency-Key ister; veritabanında da tek sefer
/// garantisi var (seviye atlama hedef seviyeye, dönüşüm istek kimliğine
/// bağlı defter anahtarı).
///
/// Hata kodları: economy_disabled, card_not_found, card_not_owned,
/// max_level, not_enough_copies, not_enough_jokers, not_enough_coins,
/// invalid_count, not_convertible
Router progressRoutes(Database db) {
  final router = Router();

  // GET /api/progress — bütün futbolcuların gelişimi + joker + altın
  router.get('/', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select player_progress_overview(@u::uuid)', params: {'u': userId});
    return jsonOk(ProgressOverview.fromJson(RowMappers.asMap(ham)).toJson());
  });

  // POST /api/progress/<cardId>/level-up  {"use_jokers": false, "use_discount": false}
  router.post('/<cardId>/level-up', (Request request, String cardId) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final joker = govde['use_jokers'] == true;
    // 034: %25 gelişim indirimi (item) kullanılsın mı?
    final indirim = govde['use_discount'] == true;
    return withRuleCodes(() async {
      final ham = await db.scalar('select level_up_player(@u::uuid, @c::uuid, @j, @d)',
          params: {'u': userId, 'c': cardId, 'j': joker, 'd': indirim});
      return jsonOk(LevelUpResult.fromJson(RowMappers.asMap(ham)).toJson());
    });
  });

  // POST /api/progress/<cardId>/convert  {"count": 2}  — GERİ ALINAMAZ
  router.post('/<cardId>/convert', (Request request, String cardId) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final adet = govde['count'];
    if (adet is! int) throw const ApiException('Adet bir sayi olmali.', code: 'invalid_count');
    final anahtar = request.headers[kIdempotencyHeader] ?? '';
    return withRuleCodes(() async {
      final ham = await db.scalar('select convert_extra_copies(@u::uuid, @c::uuid, @n, @k)',
          params: {'u': userId, 'c': cardId, 'n': adet, 'k': anahtar});
      return jsonOk(ConvertCopiesResult.fromJson(RowMappers.asMap(ham)).toJson());
    });
  });

  return router;
}
