import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/social_token_verifier.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';
import '../utils/rule_errors.dart';
import 'purchase_verifier.dart';

/// Platforma göre bağlı doğrulayıcılar. Anahtarı olmayan platform yoktur
/// (fail-closed).
class PurchaseVerifiers {
  final Map<String, PurchaseVerifier> _byPlatform;
  PurchaseVerifiers(Iterable<PurchaseVerifier> list) : _byPlatform = {for (final v in list) v.platform: v};
  PurchaseVerifier? operator [](String platform) => _byPlatform[platform];
  Set<String> get platforms => _byPlatform.keys.toSet();
}

String _hash(String v) => sha256.convert(utf8.encode(v)).toString();

/// 061 — Satın alma uçları (oyuncu oturumu gerekli).
///
///   GET  `/api/purchases/catalog?platform=&app_version=`  bu oyuncuya açık ürünler (fiyat mağazadan)
///   POST `/api/purchases/verify`   `{platform, product_id, purchase_token? | transaction_id?}`
///   POST `/api/purchases/restore`  `{platform, purchases: [ ...verify gövdesi... ]}`
///   GET  `/api/purchases/history`
///
/// Ödül YALNIZ mağaza API'siyle doğrulanan işleme verilir. İstemcinin
/// gönderdiği fiyat/miktar kullanılmaz. Hata kodları:
/// purchase_verification_unavailable (503), invalid_receipt, account_mismatch,
/// purchase_cancelled, wrong_product, wrong_app, store_unavailable (503),
/// purchase_belongs_to_another_account, product_not_found
Router purchaseRoutes(Database db, PurchaseVerifiers verifiers) {
  final router = Router();

  router.get('/catalog', (Request request) async {
    final userId = requireUserId(request);
    final q = request.url.queryParameters;
    final c = RowMappers.asMap(await db.scalar('select product_catalog_for(@u::uuid, @p, @v)',
        params: {'u': userId, 'p': (q['platform'] ?? '').toLowerCase(), 'v': q['app_version'] ?? ''}));
    // Doğrulayıcısı olmayan platformda satış yok
    if (!verifiers.platforms.contains((q['platform'] ?? '').toLowerCase())) {
      return jsonOk({...c, 'enabled': false, 'products': const []});
    }
    return jsonOk(c);
  });

  Future<Map<String, dynamic>> dogrula(String userId, Map<String, dynamic> g) async {
    final platform = (g['platform'] ?? '').toString().toLowerCase();
    final v = verifiers[platform];
    if (v == null) {
      throw const ApiException('Satin alma dogrulamasi su an yapilamiyor.', status: 503,
          code: 'purchase_verification_unavailable');
    }
    final urun = (g['product_id'] ?? '').toString();
    if (!RegExp(r'^[A-Za-z0-9._]{1,100}$').hasMatch(urun)) {
      throw const ApiException('Gecersiz urun.', status: 400, code: 'product_not_found');
    }
    final claim = PurchaseClaim(
      platform: platform,
      storeProductId: urun,
      userId: userId,
      purchaseToken: g['purchase_token']?.toString(),
      transactionId: g['transaction_id']?.toString(),
    );
    final VerifiedPurchase dogru;
    try {
      dogru = await v.verify(claim);
    } on PurchaseVerificationException catch (e) {
      await db.scalar('select purchase_record_failure(@u::uuid, @p, @t, @r)', params: {
        'u': userId,
        'p': platform,
        't': claim.transactionId ?? _hash(claim.tokenOrTxForHash).substring(0, 16),
        'r': e.code,
      });
      throw ApiException('Satin alma dogrulanamadi.', status: e.retryable ? 503 : 409, code: e.code);
    }
    final sonuc = RowMappers.asMap(await db.scalar(
      'select purchase_grant_verified(@u::uuid, @p, @urun, @tx, @h, @env, @st, @fiyat, @kur)',
      params: {
        'u': userId,
        'p': platform,
        'urun': dogru.storeProductId,
        'tx': dogru.storeTransactionId,
        'h': platform == 'ios' ? null : _hash(claim.tokenOrTxForHash),
        'env': dogru.environment,
        'st': dogru.state,
        'fiyat': dogru.priceMicros,
        'kur': dogru.currency,
      },
    ));
    // Ödül verildiyse mağazaya teslimi bildir. Başarısızsa ödül geri
    // alınmaz; istemci yeniden doğrulayınca (aynı işlem) tekrar denenir.
    if (sonuc['status'] == 'granted') {
      try {
        await v.acknowledge(claim, dogru);
        await db.scalar('select purchase_mark_acknowledged(@id::uuid)', params: {'id': sonuc['purchase_id']});
        sonuc['status'] = 'acknowledged';
      } catch (_) {}
    }
    return sonuc;
  }

  router.post('/verify', (Request request) async {
    final userId = requireUserId(request);
    final g = await readJsonBody(request);
    return withRuleCodes(() async => jsonOk(await dogrula(userId, g)));
  });

  router.post('/restore', (Request request) async {
    final userId = requireUserId(request);
    final g = await readJsonBody(request);
    final liste = (g['purchases'] as List? ?? const []).take(50);
    final sonuclar = <Map<String, dynamic>>[];
    for (final p in liste) {
      if (p is! Map) continue;
      try {
        sonuclar.add(await dogrula(userId, {'platform': g['platform'], ...Map<String, dynamic>.from(p)}));
      } on ApiException catch (e) {
        sonuclar.add({'status': 'failed', 'code': e.code});
      } catch (e) {
        // Veritabanı kural hatası "kod: mesaj"
        final kod = RegExp(r'([a-z_]+): ').firstMatch('$e')?.group(1) ?? 'unknown';
        sonuclar.add({'status': 'failed', 'code': kod});
      }
    }
    return jsonOk({'results': sonuclar});
  });

  router.get('/history', (Request request) async {
    final userId = requireUserId(request);
    return jsonOk({'purchases': await db.scalar('select purchase_history(@u::uuid)', params: {'u': userId})});
  });

  return router;
}

/// 061 — Mağaza iade/iptal bildirimleri (OYUNCU OTURUMU GEREKTİRMEZ).
///
///   POST `/api/webhooks/google-play`  Pub/Sub itme (RTDN). Google'ın imzalı
///        OIDC jetonu (hedef kitle + gönderen hizmet hesabı) doğrulanır.
///   POST `/api/webhooks/apple`  App Store Server Notifications V2. Gövdeye
///        güvenilmez: işlem kimliği alınır ve durum Apple API'sinden
///        yeniden sorgulanır; yalnız Apple "geri alındı" derse iade işlenir.
Router purchaseWebhookRoutes(
  Database db,
  PurchaseVerifiers verifiers, {
  SocialTokenVerifier? pubsubTokenVerifier,
  String? pubsubServiceAccount,
}) {
  final router = Router();

  router.post('/google-play', (Request request) async {
    final dogrulayici = pubsubTokenVerifier;
    if (dogrulayici == null || pubsubServiceAccount == null || pubsubServiceAccount.isEmpty) {
      return Response(503, body: 'rtdn not configured');
    }
    final auth = request.headers['authorization'] ?? '';
    if (!auth.startsWith('Bearer ')) return Response(401);
    try {
      final kim = await dogrulayici.verify(SocialProvider.google, auth.substring(7));
      if (kim.email != pubsubServiceAccount.toLowerCase() || !kim.emailVerified) return Response(403);
    } catch (_) {
      return Response(401);
    }
    final govde = await readJsonBody(request);
    final Map<String, dynamic> veri;
    try {
      final ham = (govde['message'] as Map?)?['data'] as String?;
      veri = jsonDecode(utf8.decode(base64.decode(ham ?? ''))) as Map<String, dynamic>;
    } catch (_) {
      return Response(204); // bozuk mesaj: yeniden denemeye gerek yok
    }
    final iade = veri['voidedPurchaseNotification'];
    if (iade is Map && iade['orderId'] is String) {
      // refundType 1: tam iade; ürün geri alınır
      await db.scalar("select purchase_refund('android', @tx, 'refunded', @r)",
          params: {'tx': iade['orderId'], 'r': 'rtdn voided (type ${iade['refundType']})'});
    }
    return Response(204);
  });

  router.post('/apple', (Request request) async {
    final v = verifiers['ios'];
    if (v == null) return Response(503, body: 'apple not configured');
    final govde = await readJsonBody(request);
    final String? txId;
    try {
      final bildirim = AppStorePurchaseVerifier.decodeJwsPayload(govde['signedPayload'] as String);
      final tur = bildirim['notificationType'];
      if (tur != 'REFUND' && tur != 'REVOKE') return Response(200);
      final data = bildirim['data'] as Map<String, dynamic>;
      txId = '${AppStorePurchaseVerifier.decodeJwsPayload(data['signedTransactionInfo'] as String)['transactionId']}';
    } catch (_) {
      return Response(200); // tanınmayan bildirim
    }
    // Bildirim gövdesine güvenme: Apple API'sinden doğrula
    final durum = await v.refundStatus(txId);
    if (durum != null) {
      await db.scalar("select purchase_refund('ios', @tx, @k, 'app store notification')",
          params: {'tx': txId, 'k': durum});
    }
    return Response(200);
  });

  return router;
}
