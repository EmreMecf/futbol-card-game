import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_history.freezed.dart';
part 'match_history.g.dart';

/// Bir macin sonucu (kullanicinin gozunden).
enum MatchOutcome {
  @JsonValue('win')
  win,
  @JsonValue('loss')
  loss,
  @JsonValue('draw')
  draw;

  bool get isWin => this == MatchOutcome.win;
  bool get isLoss => this == MatchOutcome.loss;
  bool get isDraw => this == MatchOutcome.draw;

  String get label => switch (this) {
        MatchOutcome.win => 'Galibiyet',
        MatchOutcome.loss => 'Mağlubiyet',
        MatchOutcome.draw => 'Beraberlik',
      };

  /// Kisa hali: mac listesinde skorun yaninda duran tek kelime
  String get shortLabel => switch (this) {
        MatchOutcome.win => 'Kazandın',
        MatchOutcome.loss => 'Kaybettin',
        MatchOutcome.draw => 'Berabere',
      };
}

/// Profil ekranindaki "son maclarim" satiri.
///
/// SUNUCUDAN GELIR: `get_match_history()` fonksiyonu uretir. Skorlar
/// ve el degistiren kart sayilari veritabaninda tutulan gercek
/// degerlerdir; istemci hesaplamaz.
@freezed
abstract class MatchHistoryEntry with _$MatchHistoryEntry {
  const MatchHistoryEntry._();

  const factory MatchHistoryEntry({
    required String matchId,
    required String opponentId,
    required String opponentUsername,

    @Default(0) int myScore,
    @Default(0) int opponentScore,

    @Default(MatchOutcome.draw) MatchOutcome outcome,

    /// Bu macta rakipten alinan kart sayisi
    @Default(0) int cardsWon,

    /// Bu macta kaptirilan kart sayisi
    @Default(0) int cardsLost,

    DateTime? finishedAt,
  }) = _MatchHistoryEntry;

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$MatchHistoryEntryFromJson(json);

  /// "7 - 4"
  String get scoreText => '$myScore - $opponentScore';

  /// Bu macta kart el degistirdi mi?
  bool get hadTransfers => cardsWon > 0 || cardsLost > 0;

  /// Kart hareketini tek satirda anlatir.
  ///
  /// Beraberlikte ve korumanin tuttugu maclarda kart degismedigi icin
  /// bos donuyor; arayuz o zaman satiri hic cizmiyor.
  String? get transferText {
    if (cardsWon > 0) return '$cardsWon kart aldın';
    if (cardsLost > 0) return '$cardsLost kart kaptırdın';
    return null;
  }
}
