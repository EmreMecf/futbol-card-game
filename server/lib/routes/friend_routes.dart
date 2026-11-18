import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Arkadaş odası uçları. Oyuncu kimliği her zaman doğrulanmış JWT'den alınır.
Router friendRoutes(Database db) {
  final router = Router();
  final codePattern = RegExp(r'^[0-9a-f]{30}$');

  String validatedCode(String code) {
    if (!codePattern.hasMatch(code)) {
      throw const ApiException('Geçersiz davet bağlantısı.', status: 400);
    }
    return code;
  }

  router.post('/create', (Request request) async {
    final actor = requireUserId(request);
    final result = await db.scalar(
      'select friend_room_create(@actor::uuid)',
      params: {'actor': actor},
    );
    return jsonOk(RowMappers.asMap(result));
  });

  router.post('/join', (Request request) async {
    final actor = requireUserId(request);
    final body = await readJsonBody(request);
    final code = validatedCode(requireString(body, 'code', label: 'Davet kodu'));
    final result = await db.scalar(
      'select friend_room_join(@actor::uuid,@code)',
      params: {'actor': actor, 'code': code},
    );
    return jsonOk(RowMappers.asMap(result));
  });

  router.get('/<code>', (Request request, String code) async {
    final actor = requireUserId(request);
    final result = await db.scalar(
      'select friend_room_info(@actor::uuid,@code)',
      params: {'actor': actor, 'code': validatedCode(code)},
    );
    final data = RowMappers.asMap(result);
    if (data['status'] == 'not_found' || data['status'] == 'not_member') {
      throw const ApiException.notFound('Davet bulunamadı veya odaya katılmadın.');
    }
    return jsonOk(data);
  });

  router.post('/<code>/ready', (Request request, String code) async {
    final actor = requireUserId(request);
    final body = await readJsonBody(request);
    // null: hazır değil. Kadro verilirse oyuncuya ait olduğu veritabanında denetlenir.
    final deckId = body['deck_id'];
    if (deckId != null && (deckId is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(deckId))) {
      throw const ApiException('Geçersiz kadro kimliği.');
    }
    final result = await db.scalar(
      'select friend_room_ready(@actor::uuid,@code,@deck::uuid)',
      params: {'actor': actor, 'code': validatedCode(code), 'deck': deckId},
    );
    return jsonOk(RowMappers.asMap(result));
  });

  router.post('/<code>/leave', (Request request, String code) async {
    final actor = requireUserId(request);
    final result = await db.scalar(
      'select friend_room_leave(@actor::uuid,@code)',
      params: {'actor': actor, 'code': validatedCode(code)},
    );
    return jsonOk(RowMappers.asMap(result));
  });

  return router;
}

/// Paylaşılan HTTPS davet bağlantısının açtığı sayfa: oyunu açmayı dener,
/// olmazsa düğme ve elle girilecek kodu gösterir. [code] çağıran tarafından
/// 30 karakterlik küçük harf onaltılık olarak doğrulanmış olmalıdır.
String inviteLandingPage(String code) {
  final deepLink = 'futbolcard:///davet/$code';
  return '<!doctype html><html lang="tr"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<title>Futbol Card Arena</title></head><body>'
      '<h1>Futbol Card Arena</h1><p>Arkadaşın seni özel maça davet ediyor.</p>'
      '<p><a href="$deepLink">Oyunda aç</a></p>'
      '<p>Oyun açılmazsa bu kodu oyunda "Arkadaşınla Oyna" ekranına gir: $code</p>'
      '<script>window.location.href="$deepLink";</script></body></html>';
}
