import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/network/websocket_service.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:shared_models/shared_models.dart';

/// Bellekte duran jeton deposu (cihaz güvenli deposu testte yok)
class _Depo extends TokenStorage {
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

/// exp alanı verilen sahte JWT (imza sunucuda kontrol edilmiyor)
String jeton(String ad, DateTime bitis) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'sub': ad, 'exp': bitis.millisecondsSinceEpoch ~/ 1000})}.imza';
}

/// Yalnız [gecerli] jetonları kabul eden gerçek WebSocket sunucusu
class _Sunucu {
  late HttpServer _http;
  final gecerli = <String>{};
  final denenen = <String>[];
  final acik = <WebSocket>[];

  /// true iken el sıkışma hiç cevaplanmaz (askıda kalan ağ)
  bool askida = false;

  Future<void> baslat() async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _http.listen((istek) async {
      final token = istek.uri.queryParameters['token'] ?? '';
      denenen.add(token);
      if (askida) return;
      if (!gecerli.contains(token)) {
        istek.response.statusCode = 401;
        await istek.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(istek);
      acik.add(ws);
      ws.add(jsonEncode({'type': 'connected'}));
      ws.listen((m) {
        if (m == 'ping') ws.add(jsonEncode({'type': 'pong'}));
      }, onDone: () => acik.remove(ws));
    });
  }

  String get adres => 'ws://127.0.0.1:${_http.port}/ws';

  Future<void> durdur() async {
    for (final ws in [...acik]) {
      await ws.close();
    }
    await _http.close(force: true);
  }
}

Future<void> bekle(bool Function() kosul, {Duration sure = const Duration(seconds: 8)}) async {
  final son = DateTime.now().add(sure);
  while (!kosul()) {
    if (DateTime.now().isAfter(son)) fail('Koşul zamanında sağlanmadı');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late _Sunucu sunucu;
  late SessionManager oturum;
  final yenileme = <int>[];

  setUp(() async {
    sunucu = _Sunucu();
    await sunucu.baslat();
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false\nWS_URL=${sunucu.adres}');
    oturum = SessionManager(_Depo());
    yenileme.clear();
  });

  tearDown(() => sunucu.durdur());

  Future<void> jetonVer(String t) => oturum.save(tokens: AuthTokens(accessToken: t, refreshToken: 'r'));

  test('bekleme süresi artar ama 10 saniyeyi geçmez', () {
    expect([for (var i = 1; i <= 7; i++) WebSocketService.retryDelay(i).inSeconds], [1, 2, 4, 8, 10, 10, 10]);
  });

  test('süresi dolmuş jetonla denemez, önce yeniler', () async {
    final eski = jeton('eski', DateTime.now().subtract(const Duration(minutes: 1)));
    final yeni = jeton('yeni', DateTime.now().add(const Duration(minutes: 15)));
    sunucu.gecerli.add(yeni);
    await jetonVer(eski);

    final ws = WebSocketService(
      oturum,
      refreshToken: () async {
        yenileme.add(1);
        await jetonVer(yeni);
        return true;
      },
    );
    await ws.connect();

    expect(ws.isConnected, isTrue);
    expect(sunucu.denenen, [yeni]);
    expect(yenileme, hasLength(1));
    await ws.dispose();
  });

  test('sunucu jetonu reddederse sonraki deneme yeni jetonla bağlanır', () async {
    // exp'i okunamayan jeton: süresi bilinmiyor, sunucu reddediyor
    await jetonVer('bozuk');
    const yeni = 'yeni-gecerli';
    sunucu.gecerli.add(yeni);

    final ws = WebSocketService(
      oturum,
      refreshToken: () async {
        yenileme.add(1);
        await jetonVer(yeni);
        return true;
      },
    );
    final durumlar = <bool>[];
    ws.connectionState.listen(durumlar.add);
    await ws.connect();
    expect(ws.isConnected, isFalse);

    await bekle(() => ws.isConnected);
    expect(sunucu.denenen, ['bozuk', yeni]);
    expect(durumlar.last, isTrue);
    await ws.dispose();
  });

  test('üst üste bağlanma çağrıları bağlantıyı kopuk göstermez', () async {
    const t = 'gecerli';
    sunucu.gecerli.add(t);
    await jetonVer(t);
    final ws = WebSocketService(oturum);
    final durumlar = <bool>[];
    ws.connectionState.listen(durumlar.add);

    await Future.wait([ws.connect(), ws.reconnect(), ws.connect()]);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(ws.isConnected, isTrue);
    expect(durumlar.last, isTrue);
    expect(sunucu.acik, hasLength(1), reason: 'fazla bağlantılar kapatılmalı');
    await ws.dispose();
  });

  test('askıda kalan el sıkışma zaman aşımına uğrar ve tekrar denenir', () async {
    const t = 'gecerli';
    sunucu
      ..gecerli.add(t)
      ..askida = true;
    await jetonVer(t);
    final ws = WebSocketService(oturum, handshakeTimeout: const Duration(milliseconds: 300));

    unawaited(ws.connect());
    await bekle(() => sunucu.denenen.isNotEmpty);
    sunucu.askida = false;

    await bekle(() => ws.isConnected);
    expect(sunucu.denenen.length, greaterThanOrEqualTo(2));
    await ws.dispose();
  });

  test('sunucu bağlantıyı kapatırsa kendiliğinden yeniden bağlanır', () async {
    const t = 'gecerli';
    sunucu.gecerli.add(t);
    await jetonVer(t);
    final ws = WebSocketService(oturum);
    await ws.connect();
    expect(ws.isConnected, isTrue);

    await bekle(() => sunucu.acik.isNotEmpty);
    await sunucu.acik.single.close();
    await bekle(() => !ws.isConnected);
    await bekle(() => ws.isConnected);
    await ws.dispose();
  });

  test('TEKRAR DENE beklemeyi atlar', () async {
    await jetonVer('reddedilen');
    final ws = WebSocketService(oturum);
    await ws.connect();
    await ws.connect(); // ikinci hata: bekleme 2 sn
    expect(ws.isConnected, isFalse);

    sunucu.gecerli.add('reddedilen');
    final once = DateTime.now();
    await ws.retryNow();
    expect(ws.isConnected, isTrue);
    expect(DateTime.now().difference(once), lessThan(const Duration(seconds: 1)));
    await ws.dispose();
  });
}
