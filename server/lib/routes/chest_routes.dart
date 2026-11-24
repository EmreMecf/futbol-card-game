import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';

/// EKONOMİ V2 (FAZ 1) — sandık ve ödül enerjisi uçları.
///
/// Tasarım: docs/EKONOMI_V2_TASARIM.md §9. Bütün kurallar, süreler ve
/// çekilişler veritabanı fonksiyonlarında (031); bu dosya yalnız taşır.
/// Değiştirici uçlar `idempotency` ara katmanının arkasında: aynı
/// Idempotency-Key ile gelen tekrar aynı cevabı alır.
///
/// Hata kodları (istemci bunlara göre Türkçe mesaj gösterir):
///   chest_not_found, chest_locked, chest_not_ready,
///   chest_already_unlocking, chest_not_lockable, chest_in_mailbox,
///   chest_not_in_mailbox, chest_compensated, slots_full,
///   economy_disabled
Router chestRoutes(Database db) {
  final router = Router();

  final kuralli = withRuleCodes;

  Future<void> acikMi() async {
    final acik = await db.scalar("select economy_flag('economy_v2_enabled')");
    if (acik != true) {
      throw const ApiException('Sandik sistemi henuz acik degil.', status: 409, code: 'economy_disabled');
    }
  }

  // ------------------------------------------------------------------
  // GET /api/chests  — yuvalar, anında açılabilenler, posta kutusu
  // ------------------------------------------------------------------
  router.get('/', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select list_chests(@u::uuid)', params: {'u': userId});
    return jsonOk(ChestInventory.fromJson(RowMappers.asMap(ham)).toJson());
  });

  // ------------------------------------------------------------------
  // GET /api/chests/odds?version=  — sürümlü olasılık tablosu
  // ------------------------------------------------------------------
  router.get('/odds', (Request request) async {
    requireUserId(request);
    final surum = int.tryParse(request.url.queryParameters['version'] ?? '');
    final ham = await db.scalar('select chest_odds_public(@v)', params: {'v': surum});
    if (ham == null) throw const ApiException.notFound('Olasilik surumu bulunamadi.');
    return jsonOk(ChestOdds.fromJson(RowMappers.asMap(ham)).toJson());
  });

  // ------------------------------------------------------------------
  // GET /api/chests/source?type=match&id=<maç>  — maç sonu ekranı
  // ------------------------------------------------------------------
  router.get('/source', (Request request) async {
    final userId = requireUserId(request);
    final tur = request.url.queryParameters['type'] ?? 'match';
    final id = request.url.queryParameters['id'];
    if (id == null || id.isEmpty) throw const ApiException('Kaynak kimligi eksik.');
    final ham = await db.scalar('select get_source_chest(@u::uuid, @t, @i)', params: {'u': userId, 't': tur, 'i': id});
    final harita = ham == null ? const <String, dynamic>{} : RowMappers.asMap(ham);
    // 037: enerjisiz Bronz (no_energy) ve galibiyet kopyası (win_copy)
    final kopya = harita['win_copy'] is Map ? Map<String, dynamic>.from(harita['win_copy'] as Map) : null;
    final sandikVar = harita.containsKey('id');
    final sonuc = SourceChest(
      chest: sandikVar ? Chest.fromJson(harita) : null,
      skipped: harita['skipped'] as String?,
      noEnergy: harita['no_energy'] == true,
      winCopy: kopya,
    );
    return jsonOk(sonuc.toJson());
  });

  // ------------------------------------------------------------------
  // POST /api/chests/<id>/unlock  — sayacı başlat (aynı anda tek sandık)
  // ------------------------------------------------------------------
  router.post('/<id>/unlock', (Request request, String id) async {
    final userId = requireUserId(request);
    await acikMi();
    return kuralli(() async {
      final ham = await db.scalar('select start_chest_unlock(@u::uuid, @c::uuid)', params: {'u': userId, 'c': id});
      return jsonOk(Chest.fromJson(RowMappers.asMap(ham)).toJson());
    });
  });

  // ------------------------------------------------------------------
  // POST /api/chests/<id>/open  — sonuç sunucuda çekilir, TEK SEFER
  // ------------------------------------------------------------------
  router.post('/<id>/open', (Request request, String id) async {
    final userId = requireUserId(request);
    return kuralli(() async {
      final ham = await db.scalar('select open_chest(@u::uuid, @c::uuid)', params: {'u': userId, 'c': id});
      return jsonOk(ChestOpenResult.fromJson(RowMappers.asMap(ham)).toJson());
    });
  });

  // ------------------------------------------------------------------
  // POST /api/chests/<id>/open-gems {expected_cost}  — 056: elmasla hemen aç.
  // expected_cost oyuncunun gördüğü bedel; gerçek bedel daha yüksekse
  // gem_cost_changed döner, elmas düşmez.
  // ------------------------------------------------------------------
  router.post('/<id>/open-gems', (Request request, String id) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final beklenen = (govde['expected_cost'] as num?)?.toInt();
    return kuralli(() async {
      final ham = await db.scalar('select open_chest_with_gems(@u::uuid, @c::uuid, @e)',
          params: {'u': userId, 'c': id, 'e': beklenen});
      return jsonOk(ChestOpenResult.fromJson(RowMappers.asMap(ham)).toJson());
    });
  });

  // ------------------------------------------------------------------
  // POST /api/chests/mailbox/<id>/claim  — posta kutusundan boş yuvaya
  // ------------------------------------------------------------------
  router.post('/mailbox/<id>/claim', (Request request, String id) async {
    final userId = requireUserId(request);
    return kuralli(() async {
      final ham = await db.scalar('select claim_mailbox_chest(@u::uuid, @c::uuid)', params: {'u': userId, 'c': id});
      return jsonOk(Chest.fromJson(RowMappers.asMap(ham)).toJson());
    });
  });

  return router;
}

/// GET /api/energy — ödül enerjisi (maç içi taktik enerjisinden ayrı)
Router energyRoutes(Database db) {
  final router = Router();
  router.get('/', (Request request) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select reward_energy_state(@u::uuid)', params: {'u': userId});
    return jsonOk(RewardEnergy.fromJson(RowMappers.asMap(ham)).toJson());
  });
  return router;
}
