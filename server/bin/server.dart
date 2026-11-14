import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:futbol_card_server/auth/auth_middleware.dart';
import 'package:futbol_card_server/auth/jwt_service.dart';
import 'package:futbol_card_server/config/env.dart';
import 'package:futbol_card_server/db/database.dart';
import 'package:futbol_card_server/realtime/notification_listener.dart';
import 'package:futbol_card_server/realtime/ws_hub.dart';
import 'package:futbol_card_server/routes/auth_routes.dart';
import 'package:futbol_card_server/routes/character_routes.dart';
import 'package:futbol_card_server/routes/chest_routes.dart';
import 'package:futbol_card_server/routes/economy_routes.dart';
import 'package:futbol_card_server/routes/game_routes.dart';
import 'package:futbol_card_server/routes/item_routes.dart';
import 'package:futbol_card_server/routes/season_routes.dart';
import 'package:futbol_card_server/routes/match_routes.dart';
import 'package:futbol_card_server/routes/friend_routes.dart';
import 'package:futbol_card_server/routes/progress_routes.dart';
import 'package:futbol_card_server/routes/sbc_routes.dart';
import 'package:futbol_card_server/scheduler/timeout_sweeper.dart';
import 'package:futbol_card_server/utils/api_response.dart';
import 'package:futbol_card_server/utils/idempotency.dart';
import 'package:futbol_card_server/utils/middlewares.dart';
import 'package:futbol_card_server/utils/security.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:futbol_card_server/routes/leaderboard_routes.dart';

/// Futbol Kart sunucusu.
///
/// ACILIS SIRASI:
///   1. Veritabanina baglan (hazir degilse tekrar dener)
///   2. NOTIFY dinleyicisini baslat (gercek zamanli bildirimler)
///   3. Zamanlayiciyi baslat (sure asimi taramasi)
///   4. HTTP + WebSocket sunucusunu ayaga kaldir
Future<void> main(List<String> args) async {
  _banner();

  // ---- 0. URETIM GUVENLIGI ----
  // Varsayilan (herkese acik) anahtarla yayina cikmayi ENGELLE.
  if (Env.isProduction) {
    final sorunlar = Env.productionProblems(Platform.environment);
    if (sorunlar.isNotEmpty) {
      stderr.writeln('SUNUCU BASLATILMADI - uretim ayarlari guvensiz:');
      for (final s in sorunlar) {
        stderr.writeln('  - $s');
      }
      exit(1);
    }
  }

  // ---- 1. VERITABANI ----
  final db = Database();
  await db.connect();

  // ---- 2. SERVISLER ----
  final jwt = JwtService();
  final hub = WsHub();
  final listener = NotificationListener(db, hub);
  await listener.start();

  // ---- 3. ZAMANLAYICI ----
  final sweeper = TimeoutSweeper(db)..start();

  // ---- 4. ROTALAR ----
  final api = Router();

  // Sunucu ayakta mi kontrolu (jeton gerektirmez)
  api.get('/health', (Request request) async {
    try {
      await db.scalar('select 1');
      return jsonOk({
        'status': 'ok',
        'database': 'connected',
        'websocket_users': hub.connectedUserCount,
        'time': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      return jsonError('Veritabanina ulasilamiyor.', status: 503);
    }
  });

  // Kimlik dogrulama (jeton GEREKTIRMEZ)
  //
  // ISTEK SINIRI: sifre deneme ve bcrypt islemci saldirisina karsi
  // IP + uc nokta basina dakikada AUTH_RATE_LIMIT istek (varsayilan 20).
  final authSiniri = RateLimiter(
    maxRequests: Env.authRateLimitPerMinute,
    window: const Duration(minutes: 1),
  );
  api.mount(
    '/auth',
    Pipeline()
        .addMiddleware(rateLimit(authSiniri, trustProxy: Env.trustProxy))
        .addHandler(authRoutes(db, jwt).call),
  );

  // Korumali uc noktalar (jeton GEREKLI)
  final korumali = Pipeline().addMiddleware(requireAuth(jwt));

  api.mount('/me', korumali.addHandler(meRoutes(db).call));
  api.mount('/game', korumali.addHandler(gameRoutes(db).call));
  api.mount('/match', korumali.addHandler(matchRoutes(db).call));
  api.mount('/friends', korumali.addHandler(friendRoutes(db).call));
  api.mount('/sbc', korumali.addHandler(sbcRoutes(db).call));
  api.mount('/leaderboard', korumali.addHandler(leaderboardRoutes(db).call));
  api.mount('/characters', korumali.addHandler(characterRoutes(db).call));

  // Ekonomi V2 (028+). Degistirici uclar Idempotency-Key ister; FAZ 0'da
  // yalniz okuma uclari var, ara katman simdiden bagli.
  final idempotent = korumali.addMiddleware(idempotency(DbIdempotencyStore(db)));
  api.mount('/economy', idempotent.addHandler(economyRoutes(db).call));
  // FAZ 1: sandiklar ve odul enerjisi (031)
  api.mount('/chests', idempotent.addHandler(chestRoutes(db).call));
  api.mount('/energy', idempotent.addHandler(energyRoutes(db).call));
  // FAZ 2: futbolcu seviyesi (033)
  api.mount('/progress', idempotent.addHandler(progressRoutes(db).call));
  // FAZ 3: item katalogu ve envanter (034)
  api.mount('/items', idempotent.addHandler(itemRoutes(db).call));
  // Ekonomi V2 (FAZ 4): Battle Pass + gorevler
  api.mount('/season', idempotent.addHandler(seasonRoutes(db).call));

  // ---- 5. WEBSOCKET ----
  // Baglanti adresi: ws://localhost:8080/ws?token=<access_token>
  //
  // NOT: WebSocket el sikismasinda tarayici ozel baslik gonderemedigi
  // icin jeton sorgu parametresiyle aliniyor. Jeton kisa omurlu (15 dk)
  // oldugu icin bu kabul edilebilir bir risk; yine de uretimde wss://
  // (TLS) kullanmak sart, aksi halde jeton ag uzerinde acikta gider.

  // ---- 6. ANA YONLENDIRICI ----
  final root = Router();
  root.mount('/api', api.call);
  root.get('/ws', (Request request) => _wsGuard(request, jwt, hub));

  root.get('/invite/<code>', (Request request, String code) {
    const allowed = '0123456789abcdef';
    if (code.length != 30 || code.split('').any((ch) => !allowed.contains(ch))) {
      return Response.notFound('Invalid invitation.');
    }
    final deepLink = 'futbolcard:///davet/' + code;
    final page = '<!doctype html><html lang="tr"><head><meta charset="utf-8">'
      + '<meta name="viewport" content="width=device-width,initial-scale=1">'
      + '<title>Futbol Card Arena</title></head><body>'
      + '<h1>Futbol Card Arena</h1><p>Arkadasin seni ozel maca davet ediyor.</p>'
      + '<p><a href="' + deepLink + '">Oyunda ac</a></p>'
      + '<p>Oyun yuklu degilse davet kodunu oyun icinde girin: ' + code + '</p>'
      + '<script>window.location.href="' + deepLink + '";</script></body></html>';
    return Response.ok(page, headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'no-store',
      'referrer-policy': 'no-referrer',
      'x-content-type-options': 'nosniff',
    });
  });


  root.all('/<ignored|.*>', (Request request) {
    return jsonError('Boyle bir uc nokta yok.', status: 404);
  });

  final handler = Pipeline()
      .addMiddleware(requestLogger())
      .addMiddleware(corsHeaders(allowOrigin: Env.corsOrigin))
      .addMiddleware(errorHandler())
      .addHandler(root.call);

  final server = await shelf_io.serve(handler, Env.host, Env.port);
  server.autoCompress = true;

  // ignore: avoid_print
  print('');
  // ignore: avoid_print
  print('  Sunucu hazir!');
  // ignore: avoid_print
  print('  HTTP      -> http://${Env.host}:${Env.port}/api');
  // ignore: avoid_print
  print('  WebSocket -> ws://${Env.host}:${Env.port}/ws?token=<access_token>');
  // ignore: avoid_print
  print('  Saglik    -> http://localhost:${Env.port}/api/health');
  // ignore: avoid_print
  print('');

  // ---- 7. DUZGUN KAPANIS ----
  // Ctrl+C'ye basildiginda baglantilari duzgunce kapat.
  ProcessSignal.sigint.watch().listen((_) async {
    // ignore: avoid_print
    print('\nKapaniyor...');
    sweeper.stop();
    await listener.stop();
    await hub.closeAll();
    await server.close(force: true);
    await db.close();
    exit(0);
  });
}

/// WebSocket baglantisini dogrular ve kurar.
///
/// ONEMLI TASARIM NOTU:
/// Baglanti geri cagrisi (onConnection), HTTP cevabi yazildiktan SONRA
/// calisir. Bu yuzden kullanici kimligini gecici bir degiskende tutmak
/// ISE YARAMAZ - geri cagri tetiklendiginde degisken coktan temizlenmis
/// olur. Cozum: her baglanti icin kimligi kapanis (closure) icinde
/// yakalayan yeni bir handler uretmek.
Future<Response> _wsGuard(Request request, JwtService jwt, WsHub hub) async {
  final token = request.url.queryParameters['token'];

  if (token == null || token.isEmpty) {
    return jsonError('WebSocket baglantisi icin jeton gerekli.', status: 401);
  }

  final userId = jwt.verifyAccessToken(token);
  if (userId == null) {
    return jsonError('Jeton gecersiz veya suresi dolmus.', status: 401);
  }

  // userId burada kapanis icinde yakalaniyor -> geri cagri calistiginda hazir.
  final handler = webSocketHandler(
    (WebSocketChannel socket, String? subprotocol) {
      hub.add(userId, socket);

      socket.sink.add(jsonEncode({
        'type': 'connected',
        'user_id': userId,
        'at': DateTime.now().toUtc().toIso8601String(),
      }));

      socket.stream.listen(
        (dynamic mesaj) {
          // Istemciden gelen tek mesaj tipi: baglantiyi canli tutan ping
          if (mesaj == 'ping') {
            socket.sink.add(jsonEncode({'type': 'pong'}));
          }
        },
        onDone: () => hub.remove(userId, socket),
        onError: (Object e) => hub.remove(userId, socket),
        cancelOnError: true,
      );
    },
    pingInterval: const Duration(seconds: 30),
  );

  return handler(request);
}

void _banner() {
  // ignore: avoid_print
  print('''
=====================================================
  FUTBOL KART - SUNUCU
  Ortam    : ${Env.isProduction ? 'URETIM' : 'GELISTIRME'}
  Veritabani: ${Env.dbHost}:${Env.dbPort}/${Env.dbName}
=====================================================''');

  if (!Env.isProduction && Env.jwtSecret == Env.devJwtSecret) {
    // ignore: avoid_print
    print('  UYARI: Varsayilan JWT anahtari kullaniliyor.');
    // ignore: avoid_print
    print('         Yayina cikmadan once JWT_SECRET ortam degiskenini ayarla.');
    // ignore: avoid_print
    print('');
  }
}
