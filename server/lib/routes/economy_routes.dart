import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';

/// EKONOMİ V2 uç noktaları (FAZ 0: salt okunur).
///
/// Tasarım: docs/EKONOMI_V2_TASARIM.md §9. Değiştirici uçlar (sandık
/// aç, ödül al...) FAZ 1'de eklenir ve `idempotency` ara katmanının
/// arkasında çalışır.
Router economyRoutes(Database db) {
  final router = Router();

  // ------------------------------------------------------------------
  // GET /api/economy/config
  // ------------------------------------------------------------------
  // Aktif özellik anahtarları ve ayar sürümleri + sunucu saati.
  router.get('/config', (Request request) async {
    requireUserId(request);
    final anahtarlar = await db.queryOne("select coalesce(economy_config('feature_flags'), '{}'::jsonb) as f");
    final surumler = await db.query('''
      select distinct on (kind) kind, version
      from economy_config_versions
      where active_from <= now()
      order by kind, version desc
    ''');
    final saat = await db.scalar('select now()');

    final ham = (anahtarlar?['f'] as Map?) ?? const {};
    final config = EconomyConfig(
      flags: {for (final e in ham.entries) e.key.toString(): e.value == true},
      versions: {for (final s in surumler) s['kind'] as String: s['version'] as int},
      serverTime: (saat as DateTime).toUtc(),
    );
    return jsonOk(config.toJson());
  });

  // ------------------------------------------------------------------
  // GET /api/economy/ledger?limit=50
  // ------------------------------------------------------------------
  // Oyuncunun kendi ekonomi geçmişi (en yeni önce). Destek ve
  // "ödülüm nereye gitti?" soruları için.
  router.get('/ledger', (Request request) async {
    final userId = requireUserId(request);
    final limit = (int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 50).clamp(1, 200);
    final satirlar = await db.query(
      '''
      select id, entry_type, coins_delta, coins_after, items, source_type, source_id, created_at
      from economy_ledger
      where user_id = @u::uuid
      order by created_at desc, id desc
      limit @limit
      ''',
      params: {'u': userId, 'limit': limit},
    );
    return jsonOk({
      'entries': [
        for (final s in satirlar)
          LedgerEntry(
            id: s['id'] as int,
            entryType: s['entry_type'] as String,
            coinsDelta: s['coins_delta'] as int,
            coinsAfter: s['coins_after'] as int?,
            items: Map<String, dynamic>.from((s['items'] as Map?) ?? const {}),
            sourceType: s['source_type'] as String,
            sourceId: s['source_id'] as String,
            createdAt: (s['created_at'] as DateTime).toUtc(),
          ).toJson(),
      ],
    });
  });

  // ------------------------------------------------------------------
  // ACIL KADRO (032): kadrosu formasyonu karsilamayan oyuncuya eksik
  // sayida Bronz kart, 24 saatte bir
  // ------------------------------------------------------------------
  router.get('/emergency-squad', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select emergency_squad_status(@u::uuid)', params: {'u': userId});
    return jsonOk(EmergencySquadStatus.fromJson(RowMappers.asMap(ham)).toJson());
  });

  router.post('/emergency-squad/claim', (Request request) async {
    final userId = requireUserId(request);
    return withRuleCodes(() async {
      final ham = await db.scalar('select claim_emergency_squad(@u::uuid)', params: {'u': userId});
      return jsonOk(EmergencySquadClaim.fromJson(RowMappers.asMap(ham)).toJson());
    });
  });

  // ------------------------------------------------------------------
  // GUNLUK DONGU (044): gunluk sandik (seri) + gunun ilk galibiyeti
  // ------------------------------------------------------------------
  router.get('/daily', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select daily_status(@u::uuid)', params: {'u': userId});
    return jsonOk(DailyStatus.fromJson(RowMappers.asMap(ham)).toJson());
  });

  router.post('/daily/claim', (Request request) async {
    final userId = requireUserId(request);
    return withRuleCodes(() async {
      final ham = await db.scalar('select claim_daily_chest(@u::uuid)', params: {'u': userId});
      return jsonOk(RowMappers.asMap(ham));
    });
  });

  // ------------------------------------------------------------------
  // GUNUN TEKLIFI (044): indirimli paket, gunde 1
  // ------------------------------------------------------------------
  router.get('/daily-shop', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select daily_shop_status(@u::uuid)', params: {'u': userId});
    return jsonOk(DailyShopStatus.fromJson(RowMappers.asMap(ham)).toJson());
  });

  router.post('/daily-shop/buy', (Request request) async {
    final userId = requireUserId(request);
    return withRuleCodes(() async {
      final ham = RowMappers.asMap(await db.scalar('select buy_daily_offer(@u::uuid)', params: {'u': userId}));
      return jsonOk({
        'offer': ham['offer'],
        'pack': RowMappers.packResult(ham['pack']).toJson(),
      });
    });
  });

  return router;
}
