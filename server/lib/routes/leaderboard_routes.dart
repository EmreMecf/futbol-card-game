import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shared_models/shared_models.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Lig ve liderlik tablosu uc noktalari.
///
/// ===================================================================
/// SIRALAMA SUNUCUDA VERILIYOR
/// ===================================================================
/// Istemci kendi sirasini hesaplamaya calismiyor. Bunun iki sebebi var:
///
/// 1. Dogruluk: istemci sadece kendi cektigi sayfayi gorur; 200.
///    siradaki oyuncu ilk 50'yi cekip icinde kendini bulamaz.
/// 2. Guven: siralama bir odul olcusu. Istemcinin hesapladigi bir
///    siraya guvenilemez.
Router leaderboardRoutes(Database db) {
  final router = Router();

  // ------------------------------------------------------------------
  // LIDERLIK TABLOSU
  // ------------------------------------------------------------------
  // GET /api/leaderboard?limit=50&offset=0
  //
  // Oyuncunun kendi sirasi da doniyor; listede olmasa bile arayuz
  // altta ayri bir satir olarak gosterebiliyor.
  router.get('/', (Request request) async {
    final userId = requireUserId(request);

    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 50;
    final offset =
        int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;

    final satirlar = await db.query(
      'select * from get_leaderboard(@limit, @offset)',
      params: {'limit': limit, 'offset': offset},
    );

    final sira = await db.scalar(
      'select get_my_leaderboard_position(@userId::uuid)',
      params: {'userId': userId},
    );

    final kayitlar =
        satirlar.map(RowMappers.leaderboardEntry).toList();

    return jsonOk({
      'entries': kayitlar.map((e) => e.toJson()).toList(),
      'my_position': sira is int ? sira : int.tryParse('$sira'),
      // Arayuz "sen listede misin" diye tek tek karsilastirma yapmasin
      'am_i_in_list': kayitlar.any((e) => e.userId == userId),
    });
  });

  // ------------------------------------------------------------------
  // OYUNCUNUN LIG DURUMU
  // ------------------------------------------------------------------
  // GET /api/leaderboard/rank
  //
  // Hangi basamak, bir sonrakine ne kadar kaldi.
  router.get('/rank', (Request request) async {
    final userId = requireUserId(request);

    final durum = await db.scalar(
      'select get_player_rank(@userId::uuid)',
      params: {'userId': userId},
    );

    // Modelden gecirerek dogruluyoruz: eksik ya da yanlis adlandirilmis
    // bir alan olsaydi burada hemen fark ederdik.
    return jsonOk(PlayerRank.fromJson(RowMappers.asMap(durum)).toJson());
  });

  // ------------------------------------------------------------------
  // BASAMAK TANIMLARI
  // ------------------------------------------------------------------
  // GET /api/leaderboard/tiers
  //
  // Butun lig basamaklari. Arayuzde "ligler" tanitim ekrani icin.
  router.get('/tiers', (Request request) async {
    final satirlar = await db.query(
      'select * from league_tiers order by id asc',
    );

    return jsonOk({
      'tiers': satirlar
          .map((r) => {
                'tier_id': r['id'],
                'league_code': r['league_code'],
                'league_name': r['league_name'],
                'division': r['division'],
                'min_mmr': r['min_mmr'],
                'color': r['color'],
              })
          .toList(),
    });
  });

  return router;
}
