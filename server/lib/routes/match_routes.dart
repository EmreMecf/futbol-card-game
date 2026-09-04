import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Eslestirme ve mac uc noktalari. Hepsi jeton gerektirir.
///
///   POST /api/match/find                 -> Mac ara / kuyruga gir
///   POST /api/match/cancel               -> Kuyruktan cik
///   GET  /api/match/active               -> Devam eden macim var mi?
///   GET  `/api/match/<id>/state`           -> Macin genel durumu
///   GET  `/api/match/<id>/hand`            -> SADECE kendi kartlarim
///   GET  `/api/match/<id>/moves`           -> Oynanan kartlarin gecmisi
///   GET  `/api/match/<id>/result`          -> Bitmis macin ozeti
///   POST `/api/match/<id>/play`            -> Kart oyna (veya pas)
///   POST `/api/match/<id>/timeout`         -> Rakip AFK, maci talep et
///   POST `/api/match/<id>/surrender`       -> Teslim ol
Router matchRoutes(Database db) {
  final router = Router();

  // ------------------------------------------------------------------
  // MAC ARA
  // ------------------------------------------------------------------
  router.post('/find', (Request request) async {
    final userId = requireUserId(request);
    final body = await readJsonBody(request);

    final deckId = requireString(body, 'deck_id', label: 'Deste');

    final ham = body['protected_card_ids'];
    final korunanlar = ham is List ? ham.map((e) => e.toString()).toList() : <String>[];

    // DIKKAT: p_user_id istemciden DEGIL, JWT'den geliyor.
    final sonuc = await db.scalar(
      '''
      select find_match(
        @userId::uuid,
        @deckId::uuid,
        case when @prot = '' then '{}'::uuid[]
             else string_to_array(@prot, ',')::uuid[] end
      )
      ''',
      params: {
        'userId': userId,
        'deckId': deckId,
        'prot': korunanlar.join(','),
      },
    );

    // Paylasilan model uzerinden gecirmek, sunucunun urettigi bicimin
    // uygulamanin bekledigi bicimle AYNI oldugunu garanti eder.
    return jsonOk(MatchFindResult.fromJson(RowMappers.asMap(sonuc)).toJson());
  });

  // ------------------------------------------------------------------
  // KUYRUKTAN CIK
  // ------------------------------------------------------------------
  router.post('/cancel', (Request request) async {
    final userId = requireUserId(request);
    final sonuc = await db.scalar(
      'select cancel_matchmaking(@userId::uuid)',
      params: {'userId': userId},
    );
    return jsonOk(sonuc);
  });

  // ------------------------------------------------------------------
  // AKTIF MAC
  // ------------------------------------------------------------------
  router.get('/active', (Request request) async {
    final userId = requireUserId(request);
    final macId = await db.scalar(
      'select get_active_match_id(@userId::uuid)',
      params: {'userId': userId},
    );
    return jsonOk({'match_id': macId?.toString()});
  });

  // ------------------------------------------------------------------
  // MAC GECMISI
  // ------------------------------------------------------------------
  // Profil ekranindaki "son maclarim" listesi.
  //
  // GIZLILIK: p_user_id JWT'den geliyor; bir oyuncu baskasinin
  // gecmisini isteyemez.
  router.get('/history', (Request request) async {
    final userId = requireUserId(request);

    final limit = int.tryParse(
          request.url.queryParameters['limit'] ?? '',
        ) ??
        20;
    final offset = int.tryParse(
          request.url.queryParameters['offset'] ?? '',
        ) ??
        0;

    final satirlar = await db.query(
      'select * from get_match_history(@userId::uuid, @limit, @offset)',
      params: {'userId': userId, 'limit': limit, 'offset': offset},
    );

    return jsonOk({
      'matches': satirlar
          .map((r) => RowMappers.matchHistoryEntry(r).toJson())
          .toList(),
    });
  });

  // ------------------------------------------------------------------
  // MACIN DURUMU
  // ------------------------------------------------------------------
  router.get('/<matchId>/state', (Request request, String matchId) async {
    final userId = requireUserId(request);
    final durum = await db.scalar(
      'select get_match_state(@userId::uuid, @matchId::uuid)',
      params: {'userId': userId, 'matchId': matchId},
    );

    // Modelden gecirerek dogruluyoruz: eksik ya da yanlis adlandirilmis
    // bir alan olsaydi burada hemen fark ederdik.
    return jsonOk(MatchState.fromJson(RowMappers.asMap(durum)).toJson());
  });

  // ------------------------------------------------------------------
  // KENDI ELIM
  // ------------------------------------------------------------------
  // GIZLILIK: Bu uc nokta SADECE istegi yapan oyuncunun kartlarini doner.
  // Fonksiyona gecirilen p_user_id JWT'den geldigi icin bir oyuncu
  // rakibinin elini isteyemez.
  router.get('/<matchId>/hand', (Request request, String matchId) async {
    final userId = requireUserId(request);

    final kartlar = await db.query(
      'select * from get_my_hand(@userId::uuid, @matchId::uuid)',
      params: {'userId': userId, 'matchId': matchId},
    );

    return jsonOk({
      'cards': kartlar.map((r) => RowMappers.handCard(r).toJson()).toList(),
    });
  });

  // ------------------------------------------------------------------
  // HAMLE GECMISI (acik bilgi, iki taraf da gorebilir)
  // ------------------------------------------------------------------
  router.get('/<matchId>/moves', (Request request, String matchId) async {
    final userId = requireUserId(request);

    // Oyuncu bu macin tarafi mi?
    final yetki = await db.queryOne(
      '''
      select 1 from matches
      where id = @matchId::uuid
        and (player1_id = @userId::uuid or player2_id = @userId::uuid)
      ''',
      params: {'matchId': matchId, 'userId': userId},
    );
    if (yetki == null) {
      throw const ApiException('Bu macin oyuncusu degilsiniz.', status: 403);
    }

    final hamleler = await db.query(
      '''
      select mm.round_number, mm.user_id, mm.is_lead, mm.is_pass,
             mm.position, mm.tier, mm.power, mm.chemistry, mm.created_at,
             mm.user_card_id, c.full_name, c.image_url
      from match_moves mm
      left join cards c on c.id = mm.card_id
      where mm.match_id = @matchId::uuid
      order by mm.round_number, mm.is_lead desc
      ''',
      params: {'matchId': matchId},
    );

    final turlar = await db.query(
      '''
      select round_number, winner_id, is_draw, cards_won, resolved_at
      from match_rounds
      where match_id = @matchId::uuid
      order by round_number
      ''',
      params: {'matchId': matchId},
    );

    return jsonOk(
      MatchHistory(
        moves: hamleler.map((m) => RowMappers.move(m, userId)).toList(),
        rounds: turlar.map(RowMappers.round).toList(),
      ).toJson(),
    );
  });

  // ------------------------------------------------------------------
  // MAC SONUCU
  // ------------------------------------------------------------------
  // Sadece BITMIS maclar icin. Kaybedilen/kazanilan kartlari ve
  // guncel profili doner.
  router.get('/<matchId>/result', (Request request, String matchId) async {
    final userId = requireUserId(request);

    final sonuc = await db.scalar(
      'select get_match_result(@userId::uuid, @matchId::uuid)',
      params: {'userId': userId, 'matchId': matchId},
    );

    return jsonOk(RowMappers.matchResult(sonuc).toJson());
  });

  // ------------------------------------------------------------------
  // KART OYNA
  // ------------------------------------------------------------------
  // Govde: { "user_card_id": "..." }  veya  {} / null  -> PAS
  router.post('/<matchId>/play', (Request request, String matchId) async {
    final userId = requireUserId(request);
    final body = await readJsonBody(request);

    final kartId = body['user_card_id'];
    final kart = (kartId is String && kartId.isNotEmpty) ? kartId : null;

    final sonuc = await db.scalar(
      kart == null
          ? 'select play_card(@userId::uuid, @matchId::uuid, null)'
          : 'select play_card(@userId::uuid, @matchId::uuid, @cardId::uuid)',
      params: {
        'userId': userId,
        'matchId': matchId,
        if (kart != null) 'cardId': kart,
      },
    );

    return jsonOk(PlayCardResult.fromJson(RowMappers.asMap(sonuc)).toJson());
  });

  // ------------------------------------------------------------------
  // SURE ASIMI TALEBI
  // ------------------------------------------------------------------
  router.post('/<matchId>/timeout', (Request request, String matchId) async {
    final userId = requireUserId(request);
    final sonuc = await db.scalar(
      'select claim_turn_timeout(@userId::uuid, @matchId::uuid)',
      params: {'userId': userId, 'matchId': matchId},
    );
    return jsonOk(sonuc);
  });

  // ------------------------------------------------------------------
  // TESLIM OL
  // ------------------------------------------------------------------
  router.post('/<matchId>/surrender', (Request request, String matchId) async {
    final userId = requireUserId(request);
    final sonuc = await db.scalar(
      'select surrender_match(@userId::uuid, @matchId::uuid)',
      params: {'userId': userId, 'matchId': matchId},
    );
    return jsonOk(sonuc);
  });

  return router;
}
