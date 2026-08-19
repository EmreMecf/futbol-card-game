import 'package:freezed_annotation/freezed_annotation.dart';

import 'card_model.dart';
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
