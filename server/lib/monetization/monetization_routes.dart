import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../config/env.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';
import 'ad_ssv_verifier.dart';

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
const _yerlesimler = {'daily_reward', 'chest_speedup', 'post_match'};

/// İstemci platformu ve sürümü (kapı kontrolü için). Sunucu bunlara
/// güvenlik için değil, uyumluluk için bakar: eski sürüme reklam açılmaz.
(String, String) _istemci(Request r, [Map<String, dynamic>? govde]) {
  final p = (govde?['platform'] ?? r.url.queryParameters['platform'] ?? r.headers['x-app-platform'] ?? '').toString();
  final v = (govde?['app_version'] ?? r.url.queryParameters['app_version'] ?? r.headers['x-app-version'] ?? '')
      .toString();
  return (p.toLowerCase().trim(), v.trim());
}

String _id(String v, String kod) {
  if (!_uuid.hasMatch(v)) throw ApiException('Kayit bulunamadi.', status: 404, code: kod);
  return v.toLowerCase();
}

/// 060 — Monetizasyon uçları (oturum gerekli).
///
///   GET  `/api/monetization/config`                bu oyuncu için açık özellikler
///   GET  `/api/monetization/ads/status`            yerleşimler, kalan hak, krediler
///   POST `/api/monetization/ads/sessions`          `{placement, target_id?}` süreli rezervasyon
///   GET  `/api/monetization/ads/sessions/<id>`     durum (istemci doğrulamayı yoklar)
///   POST `/api/monetization/ads/sessions/<id>/event` `{event: shown|earned|closed|failed}` (ödül VERMEZ)
///   POST `/api/monetization/ads/sessions/<id>/apply` `{chest_id}` sandık kredisini kullan
///
/// Ödülü yalnız imzalı AdMob geri çağrısı (`/api/ads/ssv`) verir.
/// Hata kodları: ad_not_eligible, ad_session_not_found, ad_credit_not_found,
/// ad_credit_expired, chest_not_eligible, invalid_event
Router monetizationRoutes(Database db) {
  final router = Router();

  router.get('/config', (Request request) async {
    final userId = requireUserId(request);
    final (p, v) = _istemci(request);
    return jsonOk(RowMappers.asMap(await db.scalar('select monetization_client_config(@u::uuid, @p, @v)',
        params: {'u': userId, 'p': p, 'v': v})));
  });

  router.get('/ads/status', (Request request) async {
    final userId = requireUserId(request);
    final (p, v) = _istemci(request);
    return jsonOk(RowMappers.asMap(
        await db.scalar('select ad_status(@u::uuid, @p, @v)', params: {'u': userId, 'p': p, 'v': v})));
  });

  router.post('/ads/sessions', (Request request) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    final yer = govde['placement']?.toString() ?? '';
    if (!_yerlesimler.contains(yer)) {
      throw const ApiException('Bilinmeyen reklam yeri.', status: 400, code: 'unknown_placement');
    }
    final hedef = govde['target_id']?.toString();
    if (hedef != null && !_uuid.hasMatch(hedef)) {
      throw const ApiException('Gecersiz hedef.', status: 400, code: 'invalid_target');
    }
    final (p, v) = _istemci(request, govde);
    return withRuleCodes(() async => jsonOk(RowMappers.asMap(await db.scalar(
          'select ad_session_create(@u::uuid, @y, @p, @v, @h)',
          params: {'u': userId, 'y': yer, 'p': p, 'v': v, 'h': hedef?.toLowerCase()},
        ))));
  });

  router.get('/ads/sessions/<id>', (Request request, String id) async {
    final userId = requireUserId(request);
    final ham = await db.scalar('select ad_session_status(@u::uuid, @s::uuid)',
        params: {'u': userId, 's': _id(id, 'ad_session_not_found')});
    if (ham == null) throw const ApiException('Reklam oturumu bulunamadi.', status: 404, code: 'ad_session_not_found');
    return jsonOk(RowMappers.asMap(ham));
  });

  router.post('/ads/sessions/<id>/event', (Request request, String id) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    return withRuleCodes(() async => jsonOk(RowMappers.asMap(await db.scalar(
          'select ad_session_client_event(@u::uuid, @s::uuid, @e)',
          params: {'u': userId, 's': _id(id, 'ad_session_not_found'), 'e': govde['event']?.toString() ?? ''},
        ))));
  });

  router.post('/ads/sessions/<id>/apply', (Request request, String id) async {
    final userId = requireUserId(request);
    final govde = await readJsonBody(request);
    return withRuleCodes(() async => jsonOk(RowMappers.asMap(await db.scalar(
          'select ad_session_apply_credit(@u::uuid, @s::uuid, @c::uuid)',
          params: {
            'u': userId,
            's': _id(id, 'ad_session_not_found'),
            'c': _id(govde['chest_id']?.toString() ?? '', 'chest_not_found'),
          },
        ))));
  });

  // ---- YALNIZ TEST ORTAMI: SSV benzetimi ----
  // Gerçek AdMob geri çağrısı yerine imzasız ödül. DEPLOY_STAGE=production
  // iken (ya da MONETIZATION_TEST_PROVIDERS kapalıyken) uç YOKTUR.
  if (Env.monetizationTestProviders) {
    router.post('/dev/ssv-simulate/<id>', (Request request, String id) async {
      final userId = requireUserId(request);
      final s = _id(id, 'ad_session_not_found');
      return withRuleCodes(() async => jsonOk(RowMappers.asMap(await db.scalar(
            'select ad_ssv_grant(@t, @s, @u, 1, @a, 0)',
            params: {'t': 'sim-${DateTime.now().microsecondsSinceEpoch}-$s', 's': s, 'u': userId, 'a': 'simulated'},
          ))));
    });
  }

  return router;
}

/// 060 — AdMob SSV geri çağrısı (OYUNCU OTURUMU GEREKTİRMEZ; imza ile korunur).
///
///   GET `/api/ads/ssv?...&signature=..&key_id=..`
///
/// Cevaplar: imza geçerli ve kayıt işlendiyse (ödül, tekrar, ret) **200**
/// (Google yeniden denemeyi bırakır). İmza geçersiz **403**. Veritabanı
/// geçici hatası **500** (Google en fazla 5 kez yeniden dener; ödül
/// kaybolmaz, tekrar anahtarı çift ödülü önler).
Router adSsvRoutes(Database db, AdSsvVerifier verifier) {
  final router = Router();

  router.get('/ssv', (Request request) async {
    final ham = request.url.query;
    final sonuc = await verifier.verify(ham);
    final params = Uri.splitQueryString(ham);
    if (!sonuc.valid) {
      try {
        await db.scalar('select ad_ssv_record_invalid(@t, @k, @s, @r)', params: {
          't': params['transaction_id'] ?? '',
          'k': sonuc.keyId,
          's': params['custom_data'] ?? '',
          'r': sonuc.reason ?? 'invalid',
        });
      } catch (_) {}
      return Response(403, body: jsonEncode({'error': true, 'code': 'invalid_signature'}),
          headers: {'content-type': 'application/json'});
    }
    return withRuleCodes(() async {
      final r = await db.scalar('select ad_ssv_grant(@t, @s, @u, @a, @unit, @k)', params: {
        't': sonuc.transactionId,
        's': sonuc.customData,
        'u': sonuc.userId,
        'a': sonuc.rewardAmount,
        'unit': sonuc.adUnit,
        'k': sonuc.keyId,
      });
      return jsonOk(RowMappers.asMap(r));
    });
  });

  return router;
}
