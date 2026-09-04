import 'package:freezed_annotation/freezed_annotation.dart';

part 'league_models.freezed.dart';
part 'league_models.g.dart';

/// Oyuncunun lig basamagi ve bir sonraki basamaga ilerlemesi.
///
/// ===================================================================
/// TAMAMEN SUNUCUDAN GELIR
/// ===================================================================
/// Basamak esikleri veritabanindaki `league_tiers` tablosunda duruyor.
/// Istemci bu esikleri BILMIYOR; sadece sunucunun hesapladigi sonucu
/// gosteriyor.
///
/// Boyle olmasinin sebebi: esikler bir denge ayari. Yayindan sonra
/// "Master Class'a cok kolay cikiliyor" denip esik degistirildiginde,
/// uygulamayi guncellememis oyuncular yanlis basamak gormemeli.
@freezed
abstract class PlayerRank with _$PlayerRank {
  const PlayerRank._();

  const factory PlayerRank({
    required int mmr,

    /// 1'den 12'ye basamak numarasi. Buyuk olan daha yuksek.
    required int tierId,

    /// 'amateur' | 'usta' | 'master' | 'master_class'
    required String leagueCode,

    /// Ekranda gorunen ad: "Amatör", "Master Class"
    required String leagueName,

    /// Lig icindeki seviye: 1 en alt, 3 en ust
    required int division,

    /// Arayuz rengi (#RRGGBB). Kart seviyelerinden AYRI bir palet.
    required String color,

    /// Bu basamagin alt siniri
    @Default(0) int tierMinMmr,

    /// Bir sonraki basamaga gecis puani. En ust basamakta null.
    int? nextTierMmr,

    String? nextLeagueName,
    int? nextDivision,

    /// Bu basamak icindeki ilerleme (0.0 - 1.0)
    @Default(0) double progress,

    /// En ust basamakta mi? Ustunde gidilecek yer yok.
    @Default(false) bool isTopTier,
  }) = _PlayerRank;

  factory PlayerRank.fromJson(Map<String, dynamic> json) =>
      _$PlayerRankFromJson(json);

  /// "Usta 2"
  String get label => '$leagueName $division';

  /// Bir sonraki basamagin adi: "Usta 3". En usttekiyse null.
  String? get nextLabel {
    if (isTopTier) return null;
    final ad = nextLeagueName;
    final seviye = nextDivision;
    if (ad == null || seviye == null) return null;
    return '$ad $seviye';
  }

  /// Yukselmek icin kac puan lazim? En usttekiyse null.
  int? get pointsToNext {
    final hedef = nextTierMmr;
    if (hedef == null) return null;
    final fark = hedef - mmr;
    return fark > 0 ? fark : 0;
  }

  /// Yukselmek icin kac NET galibiyet lazim?
  ///
  /// Bir mac +25 / -25 puan. Oyuncuya "175 puan" demek yerine
  /// "7 galibiyet" demek somut bir hedef veriyor.
  int? get winsToNext {
    final puan = pointsToNext;
    if (puan == null) return null;
    return (puan / 25).ceil();
  }
}

/// Liderlik tablosundaki tek bir satir.
@freezed
abstract class LeaderboardEntry with _$LeaderboardEntry {
  const LeaderboardEntry._();

  const factory LeaderboardEntry({
    /// Siradaki yeri. SUNUCU veriyor; istemci saymiyor.
    ///
    /// Alan adi `position` degil cunku PostgreSQL'de `position`
    /// ayrilmis bir kelime; sunucu tarafi da `rank_position` kullaniyor.
    required int rankPosition,

    required String userId,
    required String username,
    required int mmr,

    @Default(0) int wins,
    @Default(0) int losses,
    @Default(0) int draws,

    required String leagueName,
    required int division,
    required String color,
  }) = _LeaderboardEntry;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);

  /// "Usta 2"
  String get rankLabel => '$leagueName $division';

  int get totalMatches => wins + losses + draws;

  /// Kazanma orani (0.0 - 1.0). Hic mac yoksa 0.
  double get winRate {
    final toplam = totalMatches;
    if (toplam == 0) return 0;
    return wins / toplam;
  }

  /// Ilk uc icin madalya sirasi (1, 2, 3); digerleri icin null.
  int? get medal => rankPosition <= 3 ? rankPosition : null;
}

/// Liderlik tablosunun tamami: liste + oyuncunun kendi sirasi.
///
/// Oyuncu ilk 50'de olmasa bile kendi sirasini gormeli. Sunucu iki
/// bilgiyi birlikte donuyor ki istemci listeyi tarayip aramasin.
@freezed
abstract class Leaderboard with _$Leaderboard {
  const Leaderboard._();

  const factory Leaderboard({
    @Default([]) List<LeaderboardEntry> entries,

    /// Istegi yapan oyuncunun sirasi
    int? myPosition,

    /// Oyuncu gosterilen listenin icinde mi?
    /// Degilse arayuz altta ayri bir satir olarak gosteriyor.
    @Default(false) bool amIInList,
  }) = _Leaderboard;

  factory Leaderboard.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardFromJson(json);

  bool get isEmpty => entries.isEmpty;
}

/// Tek bir lig basamaginin TANIMI.
///
/// `league_tiers` tablosunun bir satiri. "Ligler" tanitim ekrani
/// butun basamaklari bu tiple listeliyor.
///
/// [PlayerRank] ile karistirilmamali: o OYUNCUNUN su anki durumu,
/// bu ise basamagin kendi tanimi (oyuncudan bagimsiz).
@freezed
abstract class LeagueTier with _$LeagueTier {
  const LeagueTier._();

  const factory LeagueTier({
    required int tierId,
    required String leagueCode,
    required String leagueName,
    required int division,

    /// Bu basamaga girmek icin gereken en dusuk puan
    required int minMmr,

    required String color,
  }) = _LeagueTier;

  factory LeagueTier.fromJson(Map<String, dynamic> json) =>
      _$LeagueTierFromJson(json);

  /// "Usta 2"
  String get label => '$leagueName $division';
}

/// Basamaklarin lige gore gruplanmis hali.
///
/// Arayuz "Amatör" basligi altinda uc kart gostermek istiyor; bu
/// gruplamayi her ekranda tekrar yazmak yerine burada yapiyoruz.
class LeagueGroup {
  final String code;
  final String name;
  final String color;
  final List<LeagueTier> tiers;

  const LeagueGroup({
    required this.code,
    required this.name,
    required this.color,
    required this.tiers,
  });

  /// Bu ligin en dusuk giris puani
  int get minMmr => tiers.isEmpty
      ? 0
      : tiers.map((t) => t.minMmr).reduce((a, b) => a < b ? a : b);

  /// Duz listeyi lige gore gruplar. Siralama KORUNUR: sunucu
  /// basamaklari zaten id sirasinda gonderiyor.
  static List<LeagueGroup> fromTiers(List<LeagueTier> tiers) {
    final gruplar = <String, List<LeagueTier>>{};
    final sira = <String>[];

    for (final t in tiers) {
      if (!gruplar.containsKey(t.leagueCode)) {
        gruplar[t.leagueCode] = [];
        sira.add(t.leagueCode);
      }
      gruplar[t.leagueCode]!.add(t);
    }

    return [
      for (final kod in sira)
        LeagueGroup(
          code: kod,
          name: gruplar[kod]!.first.leagueName,
          color: gruplar[kod]!.first.color,
          tiers: List.unmodifiable(
            gruplar[kod]!..sort((a, b) => a.division.compareTo(b.division)),
          ),
        ),
    ];
  }
}
