import 'dart:convert';

import 'package:futbol_card_server/auth/password_service.dart';
import 'package:futbol_card_server/utils/api_response.dart';
import 'package:futbol_card_server/utils/middlewares.dart';
import 'package:futbol_card_server/utils/security.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// FAZ 7 — Güvenlik ara katmanları.
void main() {
  group('İstek sınırlayıcı', () {
    test('sınıra kadar kabul, sonra bekleme süresiyle ret', () {
      var simdi = DateTime(2026, 11, 7, 12);
      final s = RateLimiter(
        maxRequests: 3,
        window: const Duration(minutes: 1),
        now: () => simdi,
      );

      expect(s.hit('ip1'), isNull);
      expect(s.hit('ip1'), isNull);
      expect(s.hit('ip1'), isNull);
      final bekle = s.hit('ip1');
      expect(bekle, isNotNull);
      expect(bekle, inInclusiveRange(1, 61));

      // Başka IP etkilenmez
      expect(s.hit('ip2'), isNull);

      // Pencere geçince yeniden açılır
      simdi = simdi.add(const Duration(minutes: 1, seconds: 1));
      expect(s.hit('ip1'), isNull);
    });

    test('eski kayıtlar bellekte birikmez', () {
      var simdi = DateTime(2026, 11, 7, 12);
      final s = RateLimiter(
        maxRequests: 5,
        window: const Duration(seconds: 10),
        now: () => simdi,
      );
      for (var i = 0; i < 499; i++) {
        s.hit('ip$i');
      }
      simdi = simdi.add(const Duration(minutes: 5));
      s.hit('yeni'); // 500. çağrı temizliği tetikler
      expect(s.trackedKeys, 1);
    });

    test('ara katman sınır aşılınca 429 ve Retry-After döner', () async {
      final s = RateLimiter(maxRequests: 2, window: const Duration(minutes: 1));
      final h = const Pipeline()
          .addMiddleware(rateLimit(s))
          .addHandler((_) => Response.ok('tamam'));

      Request istek() =>
          Request('POST', Uri.parse('http://localhost/api/auth/login'));

      expect((await h(istek())).statusCode, 200);
      expect((await h(istek())).statusCode, 200);
      final ret = await h(istek());
      expect(ret.statusCode, 429);
      expect(ret.headers['retry-after'], isNotNull);
      final govde = jsonDecode(await ret.readAsString()) as Map;
      expect(govde['code'], 'rate_limited');
    });

    test('X-Forwarded-For SADECE güvenilen vekilde okunur', () {
      final r = Request('GET', Uri.parse('http://localhost/x'),
          headers: {'x-forwarded-for': '1.2.3.4, 10.0.0.1'});
      expect(clientIp(r, trustProxy: true), '1.2.3.4');
      expect(clientIp(r), isNot('1.2.3.4'),
          reason: 'Aksi halde saldırgan başlığı değiştirip sınırı aşar');
    });
  });

  group('Günlükte jeton gizleme', () {
    test('WebSocket jetonu maskelenir', () {
      final u = Uri.parse('ws?token=eyJhbGciOiJIUzI1NiJ9.gizli.imza');
      final yazilan = redactUrl(u);
      expect(yazilan, isNot(contains('eyJ')));
      expect(yazilan, contains('token=gizli'));
    });

    test('hata metnindeki JWT ve token parametresi maskelenir', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc-DEF_123';
      final m = redactText('Hata: GET http://x/ws?token=$jwt: oops; ayrica $jwt');
      expect(m, isNot(contains('eyJ')));
      expect(m, contains('token=gizli'));
    });

    test('WebSocket devralma istisnası 500e ÇEVRİLMEZ', () async {
      final h = const Pipeline()
          .addMiddleware(errorHandler())
          .addHandler((_) => throw const HijackException());
      await expectLater(
        () async => h(Request('GET', Uri.parse('http://localhost/ws'))),
        throwsA(isA<HijackException>()),
      );
    });

    test('gizli parametre yoksa adres aynen kalır', () {
      final u = Uri.parse('api/match/history?limit=20&offset=0');
      expect(redactUrl(u), u.toString());
    });
  });

  group('İstek gövdesi', () {
    test('64 KB üstü gövde 413 ile reddedilir', () async {
      final buyuk = jsonEncode({'x': 'a' * (maxBodyBytes + 10)});
      final r = Request('POST', Uri.parse('http://localhost/api/x'),
          body: buyuk);
      await expectLater(
        readJsonBody(r),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 413)),
      );
    });

    test('boyutu bildirilmeyen (parçalı) büyük gövde de reddedilir',
        () async {
      final parcalar = Stream<List<int>>.fromIterable(
          List.generate(20, (_) => List<int>.filled(4096, 97)));
      final r = Request('POST', Uri.parse('http://localhost/api/x'),
          body: parcalar);
      await expectLater(
        readJsonBody(r),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 413)),
      );
    });

    test('normal gövde okunur', () async {
      final r = Request('POST', Uri.parse('http://localhost/api/x'),
          body: jsonEncode({'user_card_id': 'abc', 'tactic': 'high_press'}));
      expect(await readJsonBody(r), {'user_card_id': 'abc', 'tactic': 'high_press'});
    });

    test('bozuk JSON 400 ile anlaşılır mesaj verir', () async {
      final r = Request('POST', Uri.parse('http://localhost/api/x'),
          body: '{bozuk');
      await expectLater(readJsonBody(r), throwsA(isA<ApiException>()));
    });
  });

  group('CORS ve güvenlik başlıkları', () {
    test('köken ayarlanabilir, güvenlik başlıkları eklenir', () async {
      final h = const Pipeline()
          .addMiddleware(corsHeaders(allowOrigin: 'https://oyun.ornek.com'))
          .addHandler((_) => Response.ok('x'));
      final c = await h(Request('GET', Uri.parse('http://localhost/api/x')));
      expect(c.headers['access-control-allow-origin'], 'https://oyun.ornek.com');
      expect(c.headers['x-content-type-options'], 'nosniff');
      expect(c.headers['x-frame-options'], 'DENY');
    });
  });

  group('Hata cevapları iç ayrıntı sızdırmaz', () {
    test('beklenmeyen hata genel mesajla döner', () async {
      final h = const Pipeline()
          .addMiddleware(errorHandler())
          .addHandler((_) => throw StateError('gizli tablo adi: users'));
      final c = await h(Request('GET', Uri.parse('http://localhost/api/x')));
      expect(c.statusCode, 500);
      expect(await c.readAsString(), isNot(contains('users')));
    });
  });

  group('Şifre', () {
    test('sahte özet hiçbir şifreyle eşleşmez', () {
      expect(PasswordService.verify('', PasswordService.dummyHash), isFalse);
      expect(PasswordService.verify('sifre123', PasswordService.dummyHash),
          isFalse);
    });
  });
}
