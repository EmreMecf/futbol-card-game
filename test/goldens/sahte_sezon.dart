import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/season/domain/season_repository.dart';
import 'package:shared_models/shared_models.dart';

import 'sahte_veri.dart';

/// EKONOMİ V2 (FAZ 4) — Battle Pass sahte verisi (yalnız test).
/// Ödüller sunucudaki 035 tablosuyla aynı biçimde; kademe 7'de, 1-4
/// ücretsiz ödüller alınmış, 5-7 alınabilir, premium kilitli.
SeasonReward _altin(int n) => SeasonReward(type: 'coins', amount: n);
SeasonReward _sandik(String t) => SeasonReward(type: 'chest', chestType: t);
SeasonReward _item(String slug, String ad, String kat, [int qty = 1]) =>
    SeasonReward(type: 'item', slug: slug, name: ad, category: kat, qty: qty);

SeasonReward _ucretsiz(int t) => switch (t) {
      3 || 9 || 15 || 21 || 33 || 45 => _sandik('silver'),
      12 || 24 || 36 || 42 => _sandik('gold'),
      50 => _sandik('legend'),
      6 || 18 || 27 || 39 || 48 => _item('joker_gold', 'Joker parça (Altın)', 'joker', 2),
      25 => _item('badge_s1_bronze', 'Sezon 1 rozeti (bronz)', 'season_badge'),
      30 => _item('energy_drink', 'Enerji içeceği', 'energy_drink', 2),
      _ => _altin(93),
    };

SeasonReward _premium(int t) => switch (t) {
      1 => _item('kit_season1', 'Forma: Sezon 1', 'kit'),
      2 || 8 || 17 || 26 => _item('joker_gold', 'Joker parça (Altın)', 'joker', 3),
      5 || 13 || 22 || 28 || 44 || 47 => _sandik('gold'),
      15 || 35 || 50 => _sandik('legend'),
      10 => _item('card_skin_night', 'Kart görünümü: Gece Işığı', 'card_skin'),
      20 => _item('frame_season1', 'Profil çerçevesi: Sezon 1', 'profile_frame'),
      _ => _altin(195),
    };

SeasonOverview goldenSeason({bool premium = false, int xp = 7340, int alinan = 4}) => SeasonOverview(
      enabled: true,
      seasonId: 's1',
      number: 1,
      name: 'Sezon 1',
      startsAt: kGoldenServerTime.subtract(const Duration(days: 7)),
      endsAt: kGoldenServerTime.add(const Duration(days: 22, hours: 14)),
      xp: xp,
      tier: xp ~/ 1000,
      premium: premium,
      tiers: [
        for (var t = 1; t <= 50; t++)
          SeasonTier(tier: t, free: _ucretsiz(t), premium: _premium(t), freeClaimed: t <= alinan),
      ],
      serverTime: kGoldenServerTime,
    );

Mission _g(String slug, String donem, String ad, int hedef, int ilerleme, int xp) => Mission(
    slug: slug, period: donem, title: ad, target: hedef, progress: ilerleme, xp: xp, completed: ilerleme >= hedef);

final kGoldenMissions = MissionsOverview(enabled: true, serverTime: kGoldenServerTime, missions: [
  _g('daily_play_1', 'daily', '1 maç oyna', 1, 1, 150),
  _g('daily_play_2', 'daily', '2 maç oyna', 2, 1, 200),
  _g('daily_play_3', 'daily', '3 maç oyna', 3, 1, 250),
  _g('weekly_play_25', 'weekly', '25 maç oyna', 25, 12, 2500),
  _g('weekly_win_10', 'weekly', '10 galibiyet', 10, 5, 2000),
  _g('weekly_chests_3', 'weekly', '3 sandık aç', 3, 1, 1500),
  _g('season_play_120', 'season', '120 maç oyna', 120, 34, 6000),
  _g('season_level_5', 'season', 'Bir futbolcuyu 5. seviyeye çıkar', 5, 4, 2000),
  _g('season_sbc_3', 'season', '3 kart görevi tamamla', 3, 1, 2000),
]);

class GoldenSeasonRepo implements SeasonRepository {
  SeasonOverview sezon = goldenSeason();
  final alinan = <String>[];
  final anahtarlar = <String>[];

  /// Sıradaki ödül alma çağrısının hatası (ör. ağ)
  final hatalar = <AppException>[];

  @override
  Future<Result<SeasonOverview>> fetchOverview() async => Success(sezon);

  @override
  Future<Result<MissionsOverview>> fetchMissions() async => Success(kGoldenMissions);

  @override
  Future<Result<MatchSeasonXp>> fetchMatchXp(String matchId) async => const Success(MatchSeasonXp(xp: 100));

  @override
  Future<Result<Map<String, dynamic>>> claim(int tier, String track, {required String idempotencyKey}) async {
    anahtarlar.add(idempotencyKey);
    if (hatalar.isNotEmpty) return Failure(hatalar.removeAt(0));
    alinan.add('$track:$tier');
    sezon = goldenSeason(alinan: tier);
    return Success({'tier': tier, 'track': track});
  }

  @override
  Future<Result<Map<String, dynamic>>> claimAll({required String idempotencyKey}) async {
    anahtarlar.add(idempotencyKey);
    alinan.add('all');
    sezon = goldenSeason(alinan: sezon.tier);
    return const Success({'count': 3});
  }
}
