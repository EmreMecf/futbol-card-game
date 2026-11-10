import 'dart:convert';

import 'package:futbol_card_server/auth/auth_middleware.dart';
import 'package:futbol_card_server/utils/api_response.dart';
import 'package:futbol_card_server/utils/idempotency.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Ekonomi V2 FAZ 0: Idempotency-Key ara katmanı.
/// Ödül veren bir istek tekrar gelirse işlem İKİNCİ KEZ YAPILMAMALI.
void main() {
  late MemoryIdempotencyStore depo;
  late int calisma;
  late Handler handler;

  Request istek(String method, {String? key, Object? govde, String user = 'u1', String yol = 'odul'}) => Request(
        method,
        Uri.parse('http://localhost/api/economy/$yol'),
        headers: {if (key != null) kIdempotencyHeader: key, 'content-type': 'application/json'},
        body: govde == null ? null : jsonEncode(govde),
        context: {kUserIdKey: user},
      );

  setUp(() {
    depo = MemoryIdempotencyStore();
    calisma = 0;
    handler = const Pipeline().addMiddleware(idempotency(depo)).addHandler((r) async {
      if (r.method == 'GET') return jsonOk({'okuma': true});
      final g = await readJsonBody(r);
      if (g['hata'] == 'kural') throw const ApiException('Yetersiz altin', status: 409, code: 'no_coins');
      if (g['hata'] == 'sunucu') return Response.internalServerError(body: 'x');
      calisma++;
      return jsonOk({'odul': g['miktar'], 'calisma': calisma});
    });
  });

  test('ayni anahtar + ayni govde: islem BIR kez, ikinci cevap ayni', () async {
    final a = await handler(istek('POST', key: 'anahtar-0001', govde: {'miktar': 100}));
    final b = await handler(istek('POST', key: 'anahtar-0001', govde: {'miktar': 100}));
    expect(calisma, 1);
    expect(await a.readAsString(), await b.readAsString());
    expect(b.headers['idempotent-replay'], 'true');
  });

  test('ayni anahtar + farkli govde: 409, islem yok', () async {
    await handler(istek('POST', key: 'anahtar-0002', govde: {'miktar': 100}));
    final b = await handler(istek('POST', key: 'anahtar-0002', govde: {'miktar': 999}));
    expect(b.statusCode, 409);
    expect(jsonDecode(await b.readAsString())['code'], 'idempotency_mismatch');
    expect(calisma, 1);
  });

  test('anahtar oyuncuya ozel: baska oyuncu ayni anahtari kullanabilir', () async {
    await handler(istek('POST', key: 'anahtar-0003', govde: {'miktar': 1}, user: 'u1'));
    await handler(istek('POST', key: 'anahtar-0003', govde: {'miktar': 1}, user: 'u2'));
    expect(calisma, 2);
  });

  test('anahtarsiz degistirici istek reddedilir; GET serbest', () async {
    final post = await handler(istek('POST', govde: {'miktar': 1}));
    expect(post.statusCode, 400);
    expect(jsonDecode(await post.readAsString())['code'], 'idempotency_key_required');
    final get = await handler(istek('GET'));
    expect(get.statusCode, 200);
    expect(calisma, 0);
  });

  test('cok kisa anahtar reddedilir', () async {
    final r = await handler(istek('POST', key: 'kisa', govde: {}));
    expect(r.statusCode, 400);
  });

  test('is kurali reddi (4xx) saklanir: tekrar ayni red', () async {
    final a = await handler(istek('POST', key: 'anahtar-0004', govde: {'hata': 'kural'}));
    final b = await handler(istek('POST', key: 'anahtar-0004', govde: {'hata': 'kural'}));
    expect(a.statusCode, 409);
    expect(b.statusCode, 409);
    expect(b.headers['idempotent-replay'], 'true');
  });

  test('5xx saklanmaz: ayni anahtarla tekrar denenebilir', () async {
    final a = await handler(istek('POST', key: 'anahtar-0005', govde: {'hata': 'sunucu'}));
    expect(a.statusCode, 500);
    final b = await handler(istek('POST', key: 'anahtar-0005', govde: {'hata': 'sunucu'}));
    expect(b.statusCode, 500);
    expect(b.headers['idempotent-replay'], isNull, reason: '5xx tekrar edilmedi, yeniden islendi');
  });

  test('ayni anahtar farkli uc noktada kullanilamaz', () async {
    await handler(istek('POST', key: 'anahtar-0006', govde: {'miktar': 1}, yol: 'odul'));
    final b = await handler(istek('POST', key: 'anahtar-0006', govde: {'miktar': 1}, yol: 'baska'));
    expect(b.statusCode, 409);
  });
}
