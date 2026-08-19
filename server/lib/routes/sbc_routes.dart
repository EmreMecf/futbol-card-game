import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// SBC (Kadro Kurma Gorevleri) uc noktalari. Hepsi jeton gerektirir.
///
///   GET  `/api/sbc`                  -> Aktif gorevler + tamamlanma durumu
///   POST `/api/sbc/<id>/evaluate`    -> Kadroyu dogrula (gondermeden)
///   POST `/api/sbc/<id>/submit`      -> Kartlari erit, odulu al
///   GET  `/api/sbc/history`          -> Tamamlama gecmisim
Router sbcRoutes(Database db) {
  final router = Router();

  // ------------------------------------------------------------------
  // GOREV LISTESI
  // ------------------------------------------------------------------
  router.get('/', (Request request) async {
    final userId = requireUserId(request);

    final ham = await db.scalar(
      'select list_sbc_challenges(@userId::uuid)',
      params: {'userId': userId},
    );

    final liste = ham is List ? ham : RowMappers.asList(ham);

    return jsonOk({
      'challenges': liste
          .map((g) => SbcChallenge.fromJson(RowMappers.asMap(g)).toJson())
          .toList(),
    });
  });

  // ------------------------------------------------------------------
  // GECMIS
  // ------------------------------------------------------------------
  // Oyuncu hangi kartlari ne icin erittigini gorebilmeli. Kalici silme
  // yapan bir sistemde seffaflik sart.
  router.get('/history', (Request request) async {
    final userId = requireUserId(request);

    final gecmis = await db.query(
      '''
      select sc.completed_at, sc.burned_summary, sc.granted_rewards,
             g.slug, g.name
      from sbc_completions sc
      join sbc_challenges g on g.id = sc.challenge_id
      where sc.user_id = @userId::uuid
      order by sc.completed_at desc
      limit 50
      ''',
      params: {'userId': userId},
    );

    return jsonOk({
      'completions': gecmis.map((k) => {
            'challenge_slug': k['slug'],
            'challenge_name': k['name'],
            'completed_at': k['completed_at'],
            'burned_cards': k['burned_summary'],
            'rewards': k['granted_rewards'],
          }).toList(),
    });
  });

  // ------------------------------------------------------------------
  // KADRO DOGRULAMA (gondermeden once)
  // ------------------------------------------------------------------
  // Uygulama sartlari YEREL olarak da hesapliyor (anlik geri bildirim
  // icin). Bu uc nokta sunucunun gorusunu verir; "Gonder" butonuna
  // basmadan once son kontrol olarak kullanilir.
  router.post('/<challengeId>/evaluate',
      (Request request, String challengeId) async {
    final userId = requireUserId(request);
    final kartlar = await _kartListesi(request);

    final sonuc = await db.scalar(
      '''
      select evaluate_sbc_squad(
        @userId::uuid, @challengeId::uuid,
        case when @ids = '' then '{}'::uuid[]
             else string_to_array(@ids, ',')::uuid[] end
      )
      ''',
      params: {
        'userId': userId,
        'challengeId': challengeId,
        'ids': kartlar.join(','),
      },
    );

    return jsonOk(
      SbcEvaluation.fromJson(RowMappers.asMap(sonuc)).toJson(),
    );
  });

  // ------------------------------------------------------------------
  // GOREVI GONDER (BURN + ODUL)
  // ------------------------------------------------------------------
  // ANTI-HILE: Istemci sadece kart kimliklerini ve gorev kimligini
  // gonderir. Kartlarin sahipligi, kilitli olup olmadigi, kadroda olup
  // olmadigi ve gorev sartlarini karsilayip karsilamadigi TAMAMEN
  // sunucuda dogrulanir.
  //
  // ISLEM BUTUNLUGU: submit_sbc() tek bir transaction icinde calisir.
  // Odul verilirken hata olusursa kartlarin silinmesi de geri alinir.
  router.post('/<challengeId>/submit',
      (Request request, String challengeId) async {
    final userId = requireUserId(request);
    final kartlar = await _kartListesi(request);

    if (kartlar.isEmpty) {
      throw const ApiException('Once kadroyu olusturmalisiniz.');
    }

    final sonuc = await db.scalar(
      '''
      select submit_sbc(
        @userId::uuid, @challengeId::uuid,
        string_to_array(@ids, ',')::uuid[]
      )
      ''',
      params: {
        'userId': userId,
        'challengeId': challengeId,
        'ids': kartlar.join(','),
      },
    );

    return jsonOk(RowMappers.sbcResult(sonuc).toJson());
  });

  return router;
}

/// Govdeden SIRALI kart listesini okur.
///
/// SIRA ONEMLI: Listenin sirasi formasyondaki slot numarasini belirler
/// (0 = kaleci, 1-4 = defans, 5-8 = orta saha, 9-10 = forvet).
/// Kimya hesabi buna bagli.
Future<List<String>> _kartListesi(Request request) async {
  final body = await readJsonBody(request);
  final ham = body['user_card_ids'];

  if (ham is! List) {
    throw const ApiException('user_card_ids alani bir liste olmali.');
  }

  return ham.map((e) => e.toString()).toList();
}
