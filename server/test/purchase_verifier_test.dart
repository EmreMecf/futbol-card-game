import 'dart:convert';

import 'package:futbol_card_server/monetization/purchase_verifier.dart';
import 'package:test/test.dart';

/// 061: mağaza doğrulayıcıları — mağaza API'si sahte HTTP ile.
void main() {
  const oyuncu = '6f1c2e8a-1111-4000-8000-000000000001';

  group('Google Play', () {
    late List<(String, Uri)> istekler;
    late Map<String, (int, String)> cevap;

    GooglePlayPurchaseVerifier v() => GooglePlayPurchaseVerifier(
      packageName: 'com.futbolcard.futbol_card',
      clientEmail: 'x@y.iam.gserviceaccount.com',
      privateKeyPem: 'kullanilmaz',
      tokenProvider: () async => 'erisim',
      http: (method, url, headers, body) async {
        istekler.add((method, url));
        expect(headers['authorization'], 'Bearer erisim');
        return cevap[url.path.endsWith(':acknowledge') ? 'ack' : 'get'] ?? (500, '');
      },
    );

    setUp(() {
      istekler = [];
      cevap = {};
    });

    PurchaseClaim claim([String user = oyuncu]) =>
        PurchaseClaim(platform: 'android', storeProductId: 'gems_popular_300', userId: user, purchaseToken: 'tok-1');

    test('geçerli satın alma: sipariş kimliği, ortam, doğru uç', () async {
      cevap['get'] = (200, jsonEncode({'purchaseState': 0, 'orderId': 'GPA.1', 'obfuscatedExternalAccountId': oyuncu, 'purchaseType': 0}));
      final r = await v().verify(claim());
      expect(r.storeTransactionId, 'GPA.1');
      expect(r.state, 'purchased');
      expect(r.environment, 'sandbox', reason: 'purchaseType 0 = lisans testi');
      expect(istekler.single.$2.path,
          '/androidpublisher/v3/applications/com.futbolcard.futbol_card/purchases/products/gems_popular_300/tokens/tok-1');
    });

    test('başka hesabın jetonu reddedilir', () async {
      cevap['get'] = (200, jsonEncode({'purchaseState': 0, 'orderId': 'GPA.1', 'obfuscatedExternalAccountId': 'baska'}));
      expect(() => v().verify(claim()), throwsA(isA<PurchaseVerificationException>().having((e) => e.code, 'code', 'account_mismatch')));
    });

    test('iptal, geçersiz, mağaza kesintisi', () async {
      cevap['get'] = (200, jsonEncode({'purchaseState': 1, 'orderId': 'GPA.1', 'obfuscatedExternalAccountId': oyuncu}));
      await expectLater(v().verify(claim()), throwsA(isA<PurchaseVerificationException>().having((e) => e.code, 'code', 'purchase_cancelled')));
      cevap['get'] = (404, '{}');
      await expectLater(v().verify(claim()), throwsA(isA<PurchaseVerificationException>().having((e) => e.code, 'code', 'invalid_receipt')));
      cevap['get'] = (503, '{}');
      await expectLater(v().verify(claim()),
          throwsA(isA<PurchaseVerificationException>().having((e) => e.retryable, 'retryable', isTrue)));
    });

    test('bekleyen ödeme: sipariş kimliği yoksa jeton özetiyle izlenir (her seferinde aynı)', () async {
      cevap['get'] = (200, jsonEncode({'purchaseState': 2, 'obfuscatedExternalAccountId': oyuncu}));
      final a = await v().verify(claim());
      final b = await v().verify(claim());
      expect(a.state, 'pending');
      expect(a.storeTransactionId, startsWith('pending:'));
      expect(a.storeTransactionId, b.storeTransactionId);
    });

    test('jetonsuz istek mağazaya gitmeden reddedilir', () async {
      final c = const PurchaseClaim(platform: 'android', storeProductId: 'gems_popular_300', userId: oyuncu);
      await expectLater(v().verify(c), throwsA(isA<PurchaseVerificationException>()));
      expect(istekler, isEmpty);
    });

    test('teslim bildirimi (acknowledge) doğru uca gider', () async {
      cevap['ack'] = (204, '');
      final g = v();
      await g.acknowledge(claim(), const VerifiedPurchase(
          storeTransactionId: 'GPA.1', storeProductId: 'gems_popular_300', state: 'purchased', environment: 'production'));
      expect(istekler.single.$1, 'POST');
      expect(istekler.single.$2.path, endsWith('/tokens/tok-1:acknowledge'));
    });

    test('hizmet hesabı yoksa doğrulayıcı da yok (fail-closed)', () {
      expect(GooglePlayPurchaseVerifier.fromServiceAccountJson('', 'p'), isNull);
      expect(GooglePlayPurchaseVerifier.fromServiceAccountJson('{"client_email": "x"}', 'p'), isNull);
    });
  });

  group('App Store', () {
    String jws(Map<String, dynamic> p) => 'h.${base64Url.encode(utf8.encode(jsonEncode(p))).replaceAll('=', '')}.s';
    late Map<String, (int, String)> host;

    AppStorePurchaseVerifier v() => AppStorePurchaseVerifier(
      bundleId: 'com.futbolcard.futbolCard',
      keyId: 'K',
      issuerId: 'I',
      privateKeyPem: 'kullanilmaz',
      jwtProvider: () => 'jwt',
      http: (method, url, headers, body) async {
        expect(headers['authorization'], 'Bearer jwt');
        return host[url.host] ?? (404, '{}');
      },
    );

    Map<String, dynamic> islem([Map<String, dynamic> ek = const {}]) => {
      'transactionId': '2000001',
      'productId': 'gems_starter_100',
      'bundleId': 'com.futbolcard.futbolCard',
      'appAccountToken': oyuncu,
      'price': 29990,
      'currency': 'TRY',
      ...ek,
    };

    PurchaseClaim claim() =>
        const PurchaseClaim(platform: 'ios', storeProductId: 'gems_starter_100', userId: oyuncu, transactionId: '2000001');

    setUp(() => host = {});

    test('üretimde yoksa sandbox: ortam, fiyat mikro birim', () async {
      host['api.storekit-sandbox.itunes.apple.com'] = (200, jsonEncode({'signedTransactionInfo': jws(islem())}));
      final r = await v().verify(claim());
      expect(r.environment, 'sandbox');
      expect(r.storeTransactionId, '2000001');
      expect(r.priceMicros, 29990000);
      expect(r.currency, 'TRY');
    });

    test('yanlış uygulama / ürün / hesap / geri alınmış reddedilir', () async {
      Future<String> kod(Map<String, dynamic> ek) async {
        host['api.storekit.itunes.apple.com'] = (200, jsonEncode({'signedTransactionInfo': jws(islem(ek))}));
        try {
          await v().verify(claim());
          return 'ok';
        } on PurchaseVerificationException catch (e) {
          return e.code;
        }
      }

      expect(await kod({'bundleId': 'baska.uygulama'}), 'wrong_app');
      expect(await kod({'productId': 'gems_large_700'}), 'wrong_product');
      expect(await kod({'appAccountToken': 'aaaaaaaa-0000-4000-8000-000000000000'}), 'account_mismatch');
      expect(await kod({'revocationDate': 1700000000000}), 'purchase_cancelled');
      expect(await kod({}), 'ok');
    });

    test('geçersiz işlem kimliği Apple\'a gitmeden reddedilir; iki ortamda da yoksa invalid_receipt', () async {
      await expectLater(
          v().verify(const PurchaseClaim(platform: 'ios', storeProductId: 'x', userId: oyuncu, transactionId: '1 OR 1=1')),
          throwsA(isA<PurchaseVerificationException>()));
      await expectLater(v().verify(claim()),
          throwsA(isA<PurchaseVerificationException>().having((e) => e.code, 'code', 'invalid_receipt')));
    });

    test('iade durumu Apple\'dan yeniden sorgulanır', () async {
      host['api.storekit.itunes.apple.com'] =
          (200, jsonEncode({'signedTransactionInfo': jws(islem({'revocationDate': 1, 'revocationReason': 1}))}));
      expect(await v().refundStatus('2000001'), 'refunded');
      host['api.storekit.itunes.apple.com'] = (200, jsonEncode({'signedTransactionInfo': jws(islem())}));
      expect(await v().refundStatus('2000001'), isNull);
    });

    test('anahtar eksikse doğrulayıcı yok', () {
      expect(AppStorePurchaseVerifier.fromEnv(bundleId: 'b', keyId: '', issuerId: 'i', privateKey: 'p'), isNull);
    });
  });

  group('Test sağlayıcı', () {
    test('yalnız test biçimi ve doğru ürün', () async {
      final t = TestPurchaseVerifier();
      final r = await t.verify(const PurchaseClaim(
          platform: 'test', storeProductId: 'gems_starter_100', userId: oyuncu, purchaseToken: 'test:gems_starter_100:abcd1'));
      expect(r.environment, 'test');
      expect(r.storeTransactionId, 'TEST.abcd1');
      expect(
          (await t.verify(const PurchaseClaim(
                  platform: 'test', storeProductId: 'gems_starter_100', userId: oyuncu, purchaseToken: 'test-pending:gems_starter_100:abcd2')))
              .state,
          'pending');
      await expectLater(
          t.verify(const PurchaseClaim(
              platform: 'test', storeProductId: 'gems_large_700', userId: oyuncu, purchaseToken: 'test:gems_starter_100:abcd1')),
          throwsA(isA<PurchaseVerificationException>()));
    });
  });
}
