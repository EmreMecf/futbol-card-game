import 'package:freezed_annotation/freezed_annotation.dart';

import 'card_model.dart';
import 'league_models.dart';
import 'match_models.dart';
import 'user_model.dart';

part 'match_result.freezed.dart';
part 'match_result.g.dart';

/// Bitmis bir macin ozeti.
///
/// Yuksek Risk Modu bu oyunun kalbi: maci kaybeden oyuncu korumaya
/// almadigi 3 kartini KALICI olarak kaptirir. Bu model o kartlarin
/// hangileri oldugunu tasir; oyuncu envanterine girip tek tek
/// aramak zorunda kalmaz.
@freezed
abstract class MatchResultSummary with _$MatchResultSummary {
  const MatchResultSummary._();

  const factory MatchResultSummary({
    required String matchId,
    @Default(false) bool isDraw,

    /// Bu maci ben mi kazandim?
    @JsonKey(name: 'did_i_win') @Default(false) bool didIWin,

    @Default(0) int myScore,
    @Default(0) int opponentScore,
    @Default(0) int totalRounds,
    DateTime? finishedAt,

    OpponentInfo? opponent,

    /// Bu macta KAYBETTIGIM kartlar (kalici olarak rakibe gecti)
    @Default([]) List<InventoryCard> cardsLost,

    /// Bu macta KAZANDIGIM kartlar (kalici olarak bana gecti)
    @Default([]) List<InventoryCard> cardsWon,

    /// Mac sonrasi guncel profilim (coin, MMR ve koruma hakki degisti)
    UserModel? myProfile,

    /// Bu macin lig etkisi (022_match_league_change.sql).
    /// null: kayit yok (eski mac) — ekran lig bolumunu hic gostermez.
    MatchLeagueChange? leagueChange,
  }) = _MatchResultSummary;

  factory MatchResultSummary.fromJson(Map<String, dynamic> json) =>
      _$MatchResultSummaryFromJson(json);

  /// Maci kaybettim mi? (beraberlik kayip sayilmaz)
  bool get didILose => !isDraw && !didIWin;

  /// Kart el degistirdi mi?
  bool get hasCardTransfers => cardsLost.isNotEmpty || cardsWon.isNotEmpty;

  /// Kaybedilen kartlarin en degerlisi (ekranda one cikarilir)
  InventoryCard? get mostValuableLoss => _enDegerli(cardsLost);

  /// Kazanilan kartlarin en degerlisi
  InventoryCard? get mostValuableWin => _enDegerli(cardsWon);

  /// Skor farki
  int get scoreDifference => myScore - opponentScore;

  /// Sonucu anlatan Turkce baslik
  String get headline {
    if (isDraw) return 'Berabere';
    return didIWin ? 'Kazandin!' : 'Kaybettin';
  }

  /// Sonucu anlatan alt metin
  String get subtitle {
    if (isDraw) {
      return 'Skor esit bitti. Kimse kart kaybetmedi.';
    }
    if (didIWin) {
      final adet = cardsWon.length;
      return adet > 0
          ? 'Rakibinden $adet kart aldin.'
          : 'Rakibinin korumasiz karti kalmamisti.';
    }
    final adet = cardsLost.length;
    return adet > 0
        ? '$adet kartini kalici olarak kaptirdin.'
        : 'Korumaya aldigin kartlar sayesinde kart kaybetmedin.';
  }

  static InventoryCard? _enDegerli(List<InventoryCard> liste) {
    if (liste.isEmpty) return null;
    return liste.reduce((a, b) {
      if (a.tier.rank != b.tier.rank) {
        return a.tier.rank > b.tier.rank ? a : b;
      }
      return a.power >= b.power ? a : b;
    });
  }
}

/// Bir macin lig etkisi.
///
/// Mac oncesi ve sonrasi puan SUNUCUDA kaydediliyor (mac kurulurken ve
/// bitince). Istemci bu ikisini oturumdan cikarmiyor: oturum bayat
/// olabilir ve yanlis bir "lig atladin" ekrani hic olmamasindan kotudur.
@freezed
abstract class MatchLeagueChange with _$MatchLeagueChange {
  const MatchLeagueChange._();

  const factory MatchLeagueChange({
    required int mmrBefore,
    required int mmrAfter,
    @Default(0) int mmrDelta,
    required PlayerRank rankBefore,
    required PlayerRank rankAfter,

    /// 'promoted' | 'demoted' | 'same'
    @Default('same') String direction,
  }) = _MatchLeagueChange;

  factory MatchLeagueChange.fromJson(Map<String, dynamic> json) =>
      _$MatchLeagueChangeFromJson(json);

  /// Bir ust basamaga cikti mi? (ayni ligin ust seviyesi dahil)
  bool get isPromoted => direction == 'promoted';

  /// Bir alt basamaga dustu mu?
  bool get isDemoted => direction == 'demoted';

  /// Baska bir LIGE gecti mi? (Amator -> Usta gibi; seviye atlamaktan buyuk)
  bool get changedLeague => rankBefore.leagueCode != rankAfter.leagueCode;
}
