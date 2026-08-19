import 'package:freezed_annotation/freezed_annotation.dart';

import 'chemistry.dart';
import 'enums.dart';
import 'game_rules.dart';

part 'match_models.freezed.dart';
part 'match_models.g.dart';

/// Oyuncunun elindeki bir kart.
///
/// GIZLILIK: Bu veri sadece `/api/match/{id}/hand` uc noktasindan gelir
/// ve SADECE istegi yapan oyuncunun kartlarini icerir. Rakibin eli
/// hicbir sekilde istemciye gonderilmez.
@freezed
abstract class HandCard with _$HandCard implements ChemistrySource {
  const HandCard._();

  const factory HandCard({
    required String userCardId,
    required String cardId,
    required String fullName,
    required CardPosition position,
    required CardTier tier,
    required int power,

    /// Mac baslarken DONDURULAN kimya bonusu.
    /// Kart masaya `power + chemistry` gucuyle cikar.
    @Default(0) int chemistry,

    // ---- KIMYA OZELLIKLERI (neden bu bonusu aldigini gostermek icin) ----
    String? nationality,
    String? league,
    String? club,

    String? imageUrl,

    /// Bu kart bu macta oynandi mi?
    @Default(false) bool isPlayed,

    /// Maca girerken korumaya alindi mi?
    /// Korunan kartlar maci kaybetsen bile senden alinmaz.
    @Default(false) bool isProtected,
  }) = _HandCard;

  factory HandCard.fromJson(Map<String, dynamic> json) =>
      _$HandCardFromJson(json);

  bool get isLegend => tier.isLegend;

  /// Oynanabilir mi? (oynanmamis olmali)
  bool get isPlayable => !isPlayed;

  /// Kartin masaya cikacagi GERCEK guc.
  ///
  /// Turu bu deger belirler; ekranda "80 +3" seklinde gosterilir.
  int get effectivePower => power + chemistry;

  /// Kimya bonusu var mi?
  bool get hasChemistry => chemistry > 0;
}

/// Rakip oyuncunun herkese acik bilgileri
@freezed
abstract class OpponentInfo with _$OpponentInfo {
  const factory OpponentInfo({
    required String id,
    required String username,
    String? avatarUrl,
    @Default(1000) int mmr,
  }) = _OpponentInfo;

  factory OpponentInfo.fromJson(Map<String, dynamic> json) =>
      _$OpponentInfoFromJson(json);
}

/// Macin o anki durumu.
///
/// Ekrani cizmek icin gereken her sey burada. Gercek zamanli bir olay
/// geldiginde uygulama bu nesneyi yeniden ceker.
@freezed
abstract class MatchState with _$MatchState {
  const MatchState._();

  const factory MatchState({
    required String matchId,
    required MatchStatus status,
    required int roundNumber,

    /// Sira bende mi?
    @Default(false) bool isMyTurn,

    /// Turu ben mi aciyorum? Aciyorsam istedigim pozisyonu oynayabilirim.
    @JsonKey(name: 'am_i_lead') @Default(false) bool amILead,

    /// Turu rakip actiysa, benim oynamak ZORUNDA oldugum pozisyon.
    /// null ise tur henuz acilmamistir.
    CardPosition? requiredPosition,

    /// Sirasi gelen oyuncunun hamle icin son ani (SUNUCU saatiyle)
    DateTime? turnDeadline,

    /// Sunucunun o anki saati.
    /// Cihaz saati yanlis olabilecegi icin kalan sureyi bununla hesapliyoruz.
    DateTime? serverTime,

    /// Beraberliklerden masada biriken kart sayisi.
    /// Sonraki turu kazanan hepsini toplar.
    @Default(0) int potCount,

    @Default(0) int myScore,
    @Default(0) int opponentScore,
    @Default(0) int myCardsLeft,
    @Default(0) int opponentCardsLeft,

    OpponentInfo? opponent,

    String? winnerId,
    @Default(false) bool isDraw,
  }) = _MatchState;

  factory MatchState.fromJson(Map<String, dynamic> json) =>
      _$MatchStateFromJson(json);

  /// Mac bitti mi?
  bool get isOver => status.isOver;

  /// Turu acan tarafta miyim ve henuz kart atmadim mi?
  /// (Bu durumda istedigim pozisyonu secebilirim.)
  bool get canChoosePosition => isMyTurn && requiredPosition == null;

  /// Hamle icin kalan sure.
  ///
  /// NEDEN CIHAZ SAATI KULLANILMIYOR?
  /// Oyuncunun telefon saati yanlis olabilir (hatta kasitli degistirilmis
  /// olabilir). Sunucu hem son ani hem de kendi o anki saatini gonderiyor;
  /// aradaki farki alarak cihaz saatinden tamamen bagimsiz bir sayac
  /// elde ediyoruz.
  Duration get remainingTurnTime {
    final son = turnDeadline;
    final simdi = serverTime;
    if (son == null || simdi == null) return GameRules.turnDuration;

    final kalan = son.difference(simdi);
    return kalan.isNegative ? Duration.zero : kalan;
  }

  /// Sure doldu mu? (AFK toleransi dahil)
  bool get isTurnExpired => remainingTurnTime == Duration.zero;

  /// Skor farki (pozitifse onde)
  int get scoreDifference => myScore - opponentScore;

  /// Kazandim mi? (mac bittiyse anlamli)
  bool didIWin(String myUserId) => winnerId == myUserId;
}

/// Oynanmis tek bir kart (hamle gecmisi)
@freezed
abstract class MatchMove with _$MatchMove {
  const MatchMove._();

  const factory MatchMove({
    required int roundNumber,
    required String userId,

    /// Bu hamleyi ben mi yaptim?
    @Default(false) bool isMine,

    /// Bu hamle turu mu acti?
    @Default(false) bool isLead,

    /// Oyuncu "bu pozisyonda kartim yok" deyip turu kaybetti mi?
    @Default(false) bool isPass,

    CardPosition? position,
    CardTier? tier,
    int? power,

    /// Bu hamlede uygulanan kimya bonusu
    @Default(0) int chemistry,

    String? userCardId,
    String? fullName,
    String? imageUrl,
  }) = _MatchMove;

  factory MatchMove.fromJson(Map<String, dynamic> json) =>
      _$MatchMoveFromJson(json);

  bool get isLegend => tier?.isLegend ?? false;

  /// Karsilastirmada kullanilan gercek guc
  int? get effectivePower => power == null ? null : power! + chemistry;

  bool get hasChemistry => chemistry > 0;
}

/// Bir turun sonucu (animasyon ve mac ozeti icin)
@freezed
abstract class MatchRound with _$MatchRound {
  const MatchRound._();

  const factory MatchRound({
    required int roundNumber,

    /// null ise beraberlik
    String? winnerId,
    @Default(false) bool isDraw,

    /// Bu turda masadan toplanan kartlar
    @Default([]) List<String> cardsWon,
  }) = _MatchRound;

  factory MatchRound.fromJson(Map<String, dynamic> json) =>
      _$MatchRoundFromJson(json);

  int get cardsWonCount => cardsWon.length;
}

/// `/api/match/{id}/moves` cevabi
@freezed
abstract class MatchHistory with _$MatchHistory {
  const MatchHistory._();

  const factory MatchHistory({
    @Default([]) List<MatchMove> moves,
    @Default([]) List<MatchRound> rounds,
  }) = _MatchHistory;

  factory MatchHistory.fromJson(Map<String, dynamic> json) =>
      _$MatchHistoryFromJson(json);

  /// Belirli bir turda oynanan kartlar
  List<MatchMove> movesForRound(int roundNumber) =>
      moves.where((h) => h.roundNumber == roundNumber).toList();

  /// Masadaki (henuz sonuclanmamis) turun hamleleri
  List<MatchMove> get currentTableMoves {
    if (moves.isEmpty) return const [];
    final sonTur = moves.map((m) => m.roundNumber).reduce((a, b) => a > b ? a : b);
    final sonuclandi = rounds.any((r) => r.roundNumber == sonTur);
    return sonuclandi ? const [] : movesForRound(sonTur);
  }
}

/// `/api/match/find` cevabi
@freezed
abstract class MatchFindResult with _$MatchFindResult {
  const MatchFindResult._();

  const factory MatchFindResult({
    required MatchmakingStatus status,
    String? matchId,
  }) = _MatchFindResult;

  factory MatchFindResult.fromJson(Map<String, dynamic> json) =>
      _$MatchFindResultFromJson(json);

  /// Oyun ekranina gecilmeli mi?
  bool get shouldEnterMatch =>
      matchId != null &&
      (status == MatchmakingStatus.matched ||
          status == MatchmakingStatus.inMatch);

  /// Rakip bekleniyor mu?
  bool get isWaiting => status == MatchmakingStatus.queued;
}

/// `/api/match/{id}/play` cevabi
@freezed
abstract class PlayCardResult with _$PlayCardResult {
  const PlayCardResult._();

  const factory PlayCardResult({
    @Default('ok') String status,

    /// waiting_opponent -> kartimi attim, rakip bekleniyor
    /// round_resolved   -> iki taraf da atti, tur sonuclandi
    @Default('') String phase,
  }) = _PlayCardResult;

  factory PlayCardResult.fromJson(Map<String, dynamic> json) =>
      _$PlayCardResultFromJson(json);

  bool get isWaitingOpponent => phase == 'waiting_opponent';
  bool get isRoundResolved => phase == 'round_resolved';
}
