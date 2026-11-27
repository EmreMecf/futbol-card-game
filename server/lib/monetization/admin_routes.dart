import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';

final _kimlik = RegExp(r'^[a-z0-9_]{3,60}$');

/// Rol hatası 403, diğer kural hataları 409 / 404
Future<Response> _yetkili(Future<Response> Function() is_) async {
  try {
    return await withRuleCodes(is_);
  } on ApiException catch (e) {
    if (e.code == 'admin_forbidden') {
      throw const ApiException('Bu islem icin yetkin yok.', status: 403, code: 'admin_forbidden');
    }
    rethrow;
  }
}

String _gerekce(Map<String, dynamic> g) => (g['reason'] ?? '').toString();

String _kontrol(String v, String kod) {
  if (!_kimlik.hasMatch(v)) throw ApiException('Kayit bulunamadi.', status: 404, code: kod);
  return v;
}

/// 064 — MONETİZASYON YÖNETİMİ (oturum + veritabanında rol gerekli).
///
/// Roller (`admin_users`, yalnız veritabanından verilir):
///   viewer: okuma · operator: ayar, teklif, acil kapatma, deney ·
///   owner: ek olarak gerçek para (satın alma bayrakları, ürünü yayına alma).
///
///   GET  `/api/admin/monetization/overview`
///   GET  `/api/admin/monetization/metrics?days=7`
///   POST `/api/admin/monetization/config`            `{patch, reason}`
///   POST `/api/admin/monetization/kill-switch`       `{reason}`
///   POST `/api/admin/monetization/products/<id>`     `{status, reason}`
///   POST `/api/admin/monetization/offers/<id>`       `{patch, reason}`
///   POST `/api/admin/monetization/experiments`       `{key, description, variants, reason}`
///   POST `/api/admin/monetization/experiments/<key>` `{status, reason}`
///   GET  `/api/admin/monetization/experiments/<key>`  rapor
///
/// Her değişiklik değiştirilemez denetim kaydına (gerekçeyle) yazılır.
/// Rol denetimi SQL'de: sunucu yalnız taşır.
Router monetizationAdminRoutes(Database db) {
  final router = Router();

  Future<Response> cagir(String sql, Map<String, Object?> params) =>
      _yetkili(() async => jsonOk(RowMappers.asMap(await db.scalar(sql, params: params))));

  router.get('/overview', (Request r) {
    final u = requireUserId(r);
    return cagir('select admin_monetization_overview(@u::uuid)', {'u': u});
  });

  router.get('/metrics', (Request r) {
    final u = requireUserId(r);
    final gun = int.tryParse(r.url.queryParameters['days'] ?? '') ?? 7;
    return cagir('select admin_monetization_metrics(@u::uuid, @d)', {'u': u, 'd': gun});
  });

  router.post('/config', (Request r) async {
    final u = requireUserId(r);
    final g = await readJsonBody(r);
    if (g['patch'] is! Map) throw const ApiException('patch nesne olmali.', status: 400, code: 'invalid_config');
    return cagir('select admin_set_monetization_config(@u::uuid, @p::jsonb, @g)', {
      'u': u,
      'p': jsonEncode(g['patch']),
      'g': _gerekce(g),
    });
  });

  router.post('/kill-switch', (Request r) async {
    final u = requireUserId(r);
    final g = await readJsonBody(r);
    return cagir('select admin_kill_switch(@u::uuid, @g)', {'u': u, 'g': _gerekce(g)});
  });

  router.post('/products/<id>', (Request r, String id) async {
    final u = requireUserId(r);
    final g = await readJsonBody(r);
    return cagir('select admin_set_product_status(@u::uuid, @i, @s, @g)', {
      'u': u,
      'i': _kontrol(id, 'product_not_found'),
      's': (g['status'] ?? '').toString(),
      'g': _gerekce(g),
    });
  });

  router.post('/offers/<id>', (Request r, String id) async {
    final u = requireUserId(r);
    final g = await readJsonBody(r);
    if (g['patch'] is! Map) throw const ApiException('patch nesne olmali.', status: 400, code: 'invalid_offer');
    return cagir('select admin_update_cosmetic_offer(@u::uuid, @i, @p::jsonb, @g)', {
      'u': u,
      'i': _kontrol(id, 'offer_not_found'),
      'p': jsonEncode(g['patch']),
      'g': _gerekce(g),
    });
  });

  router.post('/experiments', (Request r) async {
    final u = requireUserId(r);
    final g = await readJsonBody(r);
    if (g['variants'] is! List) {
      throw const ApiException('variants dizi olmali.', status: 400, code: 'invalid_experiment');
    }
    return cagir('select admin_create_experiment(@u::uuid, @k, @d, @v::jsonb, @g)', {
      'u': u,
      'k': (g['key'] ?? '').toString(),
      'd': (g['description'] ?? '').toString(),
      'v': jsonEncode(g['variants']),
      'g': _gerekce(g),
    });
  });

  router.post('/experiments/<key>', (Request r, String key) async {
    final u = requireUserId(r);
    final g = await readJsonBody(r);
    return cagir('select admin_set_experiment_status(@u::uuid, @k, @s, @g)', {
      'u': u,
      'k': _kontrol(key, 'experiment_not_found'),
      's': (g['status'] ?? '').toString(),
      'g': _gerekce(g),
    });
  });

  router.get('/experiments/<key>', (Request r, String key) {
    final u = requireUserId(r);
    return cagir('select admin_experiment_report(@u::uuid, @k)', {'u': u, 'k': _kontrol(key, 'experiment_not_found')});
  });

  return router;
}
