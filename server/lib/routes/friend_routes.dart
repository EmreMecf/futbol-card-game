import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Invitation endpoints. Player identity is always derived from validated JWT.
Router friendRoutes(Database db) {
  final router = Router();
  final codePattern = RegExp(r'^[0-9a-f]{30}$');

  String validatedCode(String code) {
    if (!codePattern.hasMatch(code)) {
      throw const ApiException('Gecersiz davet baglantisi.', status: 400);
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
      throw const ApiException.notFound('Davet bulunamadi veya odaya katilmadin.');
    }
    return jsonOk(data);
  });

  router.post('/<code>/ready', (Request request, String code) async {
    final actor = requireUserId(request);
    final body = await readJsonBody(request);
    // Null = unready. Non-null deck is always validated against actor.
    final deckId = body['deck_id'];
    if (deckId != null && (deckId is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(deckId))) {
      throw const ApiException('Gecersiz kadro kimligi.');
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
