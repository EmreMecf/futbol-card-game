import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../config/env.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';

/// EKONOMİ V2 (FAZ 4, 035) — Battle Pass (sezon yolu) ve görevler.
///
/// Sezon XP'si ve ödüller maçta güç vermez (K1). Premium satın alma YOK
/// (K4): premium yol görünür ama kilitli. Ödül alma veritabanında tek
/// sefer (kullanıcı + sezon + kademe + yol birincil anahtarı).
///
/// Hata kodları: economy_disabled, tier_not_found, tier_locked,
/// premium_required
Router seasonRoutes(Database db) {
  final router = Router();

  // GET /api/season — sezon, XP, kademe, 50 kademenin iki yolu
  router.get('/', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select season_overview(@u::uuid)', params: {'u': userId});
    return jsonOk(RowMappers.asMap(ham));
  });

  // GET /api/season/missions — günlük / haftalık / sezon görevleri
  router.get('/missions', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select missions_overview(@u::uuid)', params: {'u': userId});
    return jsonOk(RowMappers.asMap(ham));
  });

  // GET /api/season/match/<id> — maç sonu ekranı: bu maçta kazanılan XP
  router.get('/match/<id>', (Request request, String id) async {
    final userId = requireUserId(request);
    return withRuleCodes(() async {
      final ham = await db.scalar('select season_match_xp(@u::uuid, @m::uuid)', params: {'u': userId, 'm': id});
      return jsonOk(RowMappers.asMap(ham));
    });
  });

  // POST /api/season/claim {"tier": 3, "track": "free"|"premium"}
  router.post('/claim', (Request request) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    return withRuleCodes(() async {
      final ham = await db.scalar('select claim_season_reward(@u::uuid, @t, @y)', params: {
        'u': userId,
        't': (govde['tier'] as num?)?.toInt() ?? 0,
        'y': govde['track']?.toString() ?? 'free',
      });
      return jsonOk(RowMappers.asMap(ham));
    });
  });

  // POST /api/season/claim-all — ulaşılmış, alınmamış bütün ödüller
  router.post('/claim-all', (Request request) async {
    final userId = requireUserId(request);
    return withRuleCodes(() async {
      final ham = await db.scalar('select claim_all_season_rewards(@u::uuid)', params: {'u': userId});
      return jsonOk(RowMappers.asMap(ham));
    });
  });

  // ---- YALNIZ geliştirme (üretimde yok) ----
  router.post('/dev/xp', (Request request) async {
    if (Env.isProduction) return jsonError('Boyle bir uc nokta yok.', status: 404);
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final xp = await db.scalar('select dev_season_add_xp(@u::uuid, @x)',
        params: {'u': userId, 'x': (govde['xp'] as num?)?.toInt() ?? 0});
    return jsonOk({'xp_added': xp});
  });

  router.post('/dev/premium', (Request request) async {
    if (Env.isProduction) return jsonError('Boyle bir uc nokta yok.', status: 404);
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final p = await db.scalar('select dev_set_season_premium(@u::uuid, @p)',
        params: {'u': userId, 'p': govde['premium'] == true});
    return jsonOk({'premium': p});
  });

  return router;
}
