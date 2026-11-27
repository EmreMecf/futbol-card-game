import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// 061 — MAĞAZA SATIN ALMA DOĞRULAMA.
///
/// İstemcinin "satın aldım" demesi, gönderdiği fiyat ya da miktar ödül
/// sebebi DEĞİLDİR. Sunucu işlemi mağazanın kendi API'sinden sorgular;
/// ürün, uygulama kimliği, durum ve HESAP EŞLEŞMESİ burada denetlenir.
/// Gerekli anahtar yoksa doğrulayıcı oluşturulmaz ve satın alma
/// "purchase_verification_unavailable" ile reddedilir (fail-closed).
/// Üretimde doğrulamayı atlayan bir yol yoktur; test sağlayıcı yalnız
/// `Env.monetizationTestProviders` iken bağlanır.

/// HTTP: (durum kodu, gövde). Testte sahte verilir.
typedef HttpCall = Future<(int, String)> Function(
    String method, Uri url, Map<String, String> headers, String? body);

Future<(int, String)> defaultHttpCall(String method, Uri url, Map<String, String> headers, String? body) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final r = await c.openUrl(method, url);
    headers.forEach(r.headers.set);
    if (body != null) r.write(body);
    final res = await r.close().timeout(const Duration(seconds: 15));
    return (res.statusCode, await res.transform(utf8.decoder).join());
  } finally {
    c.close(force: true);
  }
}

/// İstemciden gelen iddia (henüz güvenilmez)
class PurchaseClaim {
  final String platform; // android | ios | test
  final String storeProductId;
  final String? purchaseToken; // Google
  final String? transactionId; // Apple
  final String userId;
  const PurchaseClaim({
    required this.platform,
    required this.storeProductId,
    required this.userId,
    this.purchaseToken,
    this.transactionId,
  });

  /// Tekillik için saklanan özet (ham jeton saklanmaz)
  String get tokenOrTxForHash => purchaseToken ?? transactionId ?? '';
}

/// Mağazanın onayladığı bilgiler
class VerifiedPurchase {
  final String storeTransactionId;
  final String storeProductId;
  final String state; // purchased | pending
  final String environment; // production | sandbox | test
  final int? priceMicros;
  final String? currency;
  const VerifiedPurchase({
    required this.storeTransactionId,
    required this.storeProductId,
    required this.state,
    required this.environment,
    this.priceMicros,
    this.currency,
  });
}

class PurchaseVerificationException implements Exception {
  final String code;
  final bool retryable;
  const PurchaseVerificationException(this.code, {this.retryable = false});
  @override
  String toString() => 'PurchaseVerificationException($code)';
}

abstract class PurchaseVerifier {
  String get platform;
  Future<VerifiedPurchase> verify(PurchaseClaim c);

  /// Ödül verildikten sonra mağazaya teslimi bildir (gerekiyorsa)
  Future<void> acknowledge(PurchaseClaim c, VerifiedPurchase v) async {}

  /// İade bildirimi gelince işlemi mağazadan yeniden sorgula: iade/geri
  /// alma gerçekten var mı? null: bilinmiyor
  Future<String?> refundStatus(String storeTransactionId) async => null;
}

// =====================================================================
// GOOGLE PLAY
// =====================================================================
class GooglePlayPurchaseVerifier extends PurchaseVerifier {
  final String packageName;
  final String clientEmail;
  final String privateKeyPem;
  final HttpCall http;
  final DateTime Function() now;

  /// Testte erişim jetonu doğrudan verilir (anahtar imzası atlanır)
  final Future<String> Function()? tokenProvider;

  GooglePlayPurchaseVerifier({
    required this.packageName,
    required this.clientEmail,
    required this.privateKeyPem,
    HttpCall? http,
    DateTime Function()? now,
    this.tokenProvider,
  }) : http = http ?? defaultHttpCall,
       now = now ?? DateTime.now;

  /// Hizmet hesabı JSON'undan (ortam değişkeni). Eksikse null.
  static GooglePlayPurchaseVerifier? fromServiceAccountJson(String? json, String packageName, {HttpCall? http}) {
    if (json == null || json.trim().isEmpty) return null;
    final m = jsonDecode(json) as Map<String, dynamic>;
    final email = m['client_email'] as String?;
    final key = m['private_key'] as String?;
    if (email == null || key == null) return null;
    return GooglePlayPurchaseVerifier(packageName: packageName, clientEmail: email, privateKeyPem: key, http: http);
  }

  @override
  String get platform => 'android';

  String? _token;
  DateTime? _tokenUntil;

  Future<String> _accessToken() async {
    if (tokenProvider != null) return tokenProvider!();
    if (_token != null && _tokenUntil != null && now().isBefore(_tokenUntil!)) return _token!;
    final assertion = JWT({
      'iss': clientEmail,
      'scope': 'https://www.googleapis.com/auth/androidpublisher',
      'aud': 'https://oauth2.googleapis.com/token',
      'iat': now().millisecondsSinceEpoch ~/ 1000,
      'exp': now().add(const Duration(minutes: 55)).millisecondsSinceEpoch ~/ 1000,
    }).sign(RSAPrivateKey(privateKeyPem), algorithm: JWTAlgorithm.RS256, noIssueAt: true);
    final (code, body) = await http('POST', Uri.parse('https://oauth2.googleapis.com/token'),
        {'content-type': 'application/x-www-form-urlencoded'},
        'grant_type=${Uri.encodeQueryComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=$assertion');
    if (code != 200) throw const PurchaseVerificationException('store_auth_failed', retryable: true);
    final m = jsonDecode(body) as Map<String, dynamic>;
    _token = m['access_token'] as String;
    _tokenUntil = now().add(Duration(seconds: ((m['expires_in'] as num?)?.toInt() ?? 3600) - 120));
    return _token!;
  }

  Uri _productUri(String productId, String token, [String suffix = '']) => Uri.parse(
      'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${Uri.encodeComponent(packageName)}'
      '/purchases/products/${Uri.encodeComponent(productId)}/tokens/${Uri.encodeComponent(token)}$suffix');

  @override
  Future<VerifiedPurchase> verify(PurchaseClaim c) async {
    final token = c.purchaseToken;
    if (token == null || token.isEmpty || token.length > 4096) {
      throw const PurchaseVerificationException('invalid_receipt');
    }
    final (code, body) =
        await http('GET', _productUri(c.storeProductId, token), {'authorization': 'Bearer ${await _accessToken()}'}, null);
    if (code == 404 || code == 400 || code == 410) throw const PurchaseVerificationException('invalid_receipt');
    if (code != 200) throw const PurchaseVerificationException('store_unavailable', retryable: true);
    final m = jsonDecode(body) as Map<String, dynamic>;
    // 0 satın alındı, 1 iptal, 2 bekliyor
    final state = (m['purchaseState'] as num?)?.toInt();
    if (state == 1) throw const PurchaseVerificationException('purchase_cancelled');
    // Hesap eşleşmesi: istemci satın alırken oyuncu kimliğini verir
    // (obfuscatedAccountId). Başka hesabın jetonu kabul edilmez.
    if (m['obfuscatedExternalAccountId'] != c.userId) {
      throw const PurchaseVerificationException('account_mismatch');
    }
    final orderId = m['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) {
      // Bekleyen ödemede sipariş kimliği henüz olmayabilir: jeton özetiyle izlenir
      if (state == 2) {
        return VerifiedPurchase(
          storeTransactionId: 'pending:${sha256.convert(utf8.encode(token)).toString().substring(0, 40)}',
          storeProductId: c.storeProductId,
          state: 'pending',
          environment: 'production',
        );
      }
      throw const PurchaseVerificationException('invalid_receipt');
    }
    return VerifiedPurchase(
      storeTransactionId: orderId,
      storeProductId: c.storeProductId,
      state: state == 2 ? 'pending' : 'purchased',
      // purchaseType 0 = lisans testi (gerçek tahsilat yok)
      environment: (m['purchaseType'] as num?)?.toInt() == 0 ? 'sandbox' : 'production',
    );
  }

  @override
  Future<void> acknowledge(PurchaseClaim c, VerifiedPurchase v) async {
    final token = c.purchaseToken;
    if (token == null) return;
    // Onaylanmazsa Google 3 gün içinde ödemeyi iade eder
    final (code, _) = await http('POST', _productUri(c.storeProductId, token, ':acknowledge'),
        {'authorization': 'Bearer ${await _accessToken()}', 'content-type': 'application/json'}, '{}');
    if (code != 200 && code != 204 && code != 400) {
      throw const PurchaseVerificationException('acknowledge_failed', retryable: true);
    }
  }
}

// =====================================================================
// APPLE (App Store Server API)
// =====================================================================
class AppStorePurchaseVerifier extends PurchaseVerifier {
  final String bundleId;
  final String keyId;
  final String issuerId;
  final String privateKeyPem;
  final HttpCall http;
  final DateTime Function() now;

  /// Testte JWT doğrudan verilir
  final String Function()? jwtProvider;

  static const _prod = 'https://api.storekit.itunes.apple.com';
  static const _sandbox = 'https://api.storekit-sandbox.itunes.apple.com';

  AppStorePurchaseVerifier({
    required this.bundleId,
    required this.keyId,
    required this.issuerId,
    required this.privateKeyPem,
    HttpCall? http,
    DateTime Function()? now,
    this.jwtProvider,
  }) : http = http ?? defaultHttpCall,
       now = now ?? DateTime.now;

  static AppStorePurchaseVerifier? fromEnv({
    required String bundleId,
    String? keyId,
    String? issuerId,
    String? privateKey,
    HttpCall? http,
  }) {
    if ([keyId, issuerId, privateKey].any((v) => v == null || v.trim().isEmpty)) return null;
    return AppStorePurchaseVerifier(
        bundleId: bundleId, keyId: keyId!, issuerId: issuerId!, privateKeyPem: privateKey!, http: http);
  }

  @override
  String get platform => 'ios';

  String _jwt() => jwtProvider?.call() ?? JWT(
        {
          'iss': issuerId,
          'iat': now().millisecondsSinceEpoch ~/ 1000,
          'exp': now().add(const Duration(minutes: 20)).millisecondsSinceEpoch ~/ 1000,
          'aud': 'appstoreconnect-v1',
          'bid': bundleId,
        },
        header: {'kid': keyId, 'typ': 'JWT'},
      ).sign(ECPrivateKey(privateKeyPem), algorithm: JWTAlgorithm.ES256, noIssueAt: true);

  /// İşlemi Apple'dan çek (önce üretim, bulunamazsa sandbox). Veri Apple'ın
  /// kendi API'sinden kimlik doğrulamalı TLS ile geldiği için güvenilir.
  Future<(Map<String, dynamic>, String)> _transaction(String id) async {
    for (final (host, env) in [(_prod, 'production'), (_sandbox, 'sandbox')]) {
      final (code, body) = await http(
          'GET', Uri.parse('$host/inApps/v1/transactions/${Uri.encodeComponent(id)}'), {'authorization': 'Bearer ${_jwt()}'}, null);
      if (code == 200) {
        final jws = (jsonDecode(body) as Map<String, dynamic>)['signedTransactionInfo'] as String;
        return (decodeJwsPayload(jws), env);
      }
      if (code != 404) throw const PurchaseVerificationException('store_unavailable', retryable: true);
    }
    throw const PurchaseVerificationException('invalid_receipt');
  }

  static Map<String, dynamic> decodeJwsPayload(String jws) {
    final parts = jws.split('.');
    if (parts.length != 3) throw const PurchaseVerificationException('invalid_receipt');
    return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
  }

  @override
  Future<VerifiedPurchase> verify(PurchaseClaim c) async {
    final id = c.transactionId;
    if (id == null || !RegExp(r'^[0-9]{1,30}$').hasMatch(id)) throw const PurchaseVerificationException('invalid_receipt');
    final (t, env) = await _transaction(id);
    if (t['bundleId'] != bundleId) throw const PurchaseVerificationException('wrong_app');
    if (t['productId'] != c.storeProductId) throw const PurchaseVerificationException('wrong_product');
    if (t['revocationDate'] != null) throw const PurchaseVerificationException('purchase_cancelled');
    // Hesap eşleşmesi: satın alırken appAccountToken = oyuncu UUID
    if ((t['appAccountToken'] as String?)?.toLowerCase() != c.userId.toLowerCase()) {
      throw const PurchaseVerificationException('account_mismatch');
    }
    final price = t['price'];
    return VerifiedPurchase(
      storeTransactionId: '${t['transactionId']}',
      storeProductId: c.storeProductId,
      state: 'purchased',
      environment: env,
      // Apple fiyatı binde bir birimde verir → mikro
      priceMicros: price is num ? price.toInt() * 1000 : null,
      currency: t['currency'] as String?,
    );
  }

  @override
  Future<String?> refundStatus(String storeTransactionId) async {
    final (t, _) = await _transaction(storeTransactionId);
    if (t['revocationDate'] == null) return null;
    // revocationReason 1 = Apple'a şikâyet (iade), 0 = diğer (aile paylaşımı vb.)
    return (t['revocationReason'] as num?)?.toInt() == 1 ? 'refunded' : 'revoked';
  }
}

// =====================================================================
// TEST SAĞLAYICI (yalnız staging/yerel; üretimde bağlanmaz)
// =====================================================================
/// Jeton biçimi: `test:<ürün>:<benzersiz>`; `test-pending:` bekleyen ödeme.
class TestPurchaseVerifier extends PurchaseVerifier {
  @override
  String get platform => 'test';

  @override
  Future<VerifiedPurchase> verify(PurchaseClaim c) async {
    final t = c.purchaseToken ?? '';
    final m = RegExp(r'^test(-pending)?:([a-z0-9_]+):([A-Za-z0-9-]{4,64})$').firstMatch(t);
    if (m == null || m.group(2) != c.storeProductId) throw const PurchaseVerificationException('invalid_receipt');
    return VerifiedPurchase(
      storeTransactionId: 'TEST.${m.group(3)}',
      storeProductId: c.storeProductId,
      state: m.group(1) == null ? 'purchased' : 'pending',
      environment: 'test',
    );
  }
}
