import 'package:shared_models/shared_models.dart';

/// Bir turun çatışma sahnesinde nasıl biteceği.
enum ClashOutcome { win, loss, draw }

/// ÇATIŞMA OLAYI — sonuçlanmış bir turun sahnede oynatılacak hâli.
///
/// ===================================================================
/// SONUCU ANİMASYON BELİRLEMİYOR (MD bölüm 6, "Önemli kural")
/// ===================================================================
/// Bu sınıf HİÇBİR ŞEY HESAPLAMIYOR. Kimin kazandığını sunucu
/// `_resolve_round()` içinde belirleyip `match_rounds` tablosuna
/// yazıyor; buraya gelen [MatchRound.winnerId] o kayıt. İki kartın gücü
/// ve kimyası da sunucunun `match_moves` kaydından.
///
/// İstemci tarafında güç karşılaştırması YAPILMIYOR: yapılsaydı ve bir
/// gün kural değişseydi (ör. özellikler maça bağlansaydı), animasyon
/// sunucuyla çelişen bir sonuç gösterebilirdi. Sahne sadece sunucunun
/// söylediğini oynatıyor.
class ClashEvent {
  final int roundNumber;
  final ClashOutcome outcome;

  /// Benim oynadığım kart (pas geçtiysem `isPass: true`)
  final MatchMove? myMove;

  /// Rakibin oynadığı kart
  final MatchMove? opponentMove;

  /// Turun mevkisi (düello animasyonunun türünü belirler)
  final CardPosition? position;

  /// Bu turda masadan toplanan kart sayısı (beraberlik birikimi dahil)
  final int cardsCollected;

  const ClashEvent({
    required this.roundNumber,
    required this.outcome,
    this.myMove,
    this.opponentMove,
    this.position,
    this.cardsCollected = 0,
  });

  /// Sunucunun tur kaydından oluşturur.
  ///
  /// [moves] o turun hamleleri (iki taraf). Biri eksikse (bozuk veri)
  /// sahne yine oynar; eksik kart "PAS" olarak gösterilir.
  factory ClashEvent.fromServer({
    required MatchRound round,
    required List<MatchMove> moves,
    required String? myUserId,
  }) {
    MatchMove? benim;
    MatchMove? rakip;
    for (final m in moves) {
      if (m.isMine) {
        benim = m;
      } else {
        rakip = m;
      }
    }

    final sonuc = round.isDraw
        ? ClashOutcome.draw
        : (round.winnerId != null && round.winnerId == myUserId)
            ? ClashOutcome.win
            : ClashOutcome.loss;

    // Mevki: turu açanın kartı belirler (pas geçen tarafın kartı yok)
    MatchMove? acan;
    for (final m in moves) {
      if (m.isLead) acan = m;
    }

    return ClashEvent(
      roundNumber: round.roundNumber,
      outcome: sonuc,
      myMove: benim,
      opponentMove: rakip,
      position: acan?.position ?? benim?.position ?? rakip?.position,
      cardsCollected: round.cardsWonCount,
    );
  }

  bool get iPassed => myMove == null || myMove!.isPass;
  bool get opponentPassed => opponentMove == null || opponentMove!.isPass;

  /// Kazanan kart Legend olduğu için mi kazandı?
  ///
  /// Legend kuralı: Legend kart, gücü düşük olsa bile alttaki dört
  /// seviyeyi yener. Oyuncu "86 gücüm 84'e nasıl yenildi?" diye
  /// şaşırmasın diye sahnede ayrıca yazılıyor.
  ///
  /// Bu da hesaplama DEĞİL, açıklama: sonuç zaten sunucudan geldi;
  /// burada sadece "kazanan Legend'dı ve gücü daha düşüktü" durumu
  /// tespit edilip etiketleniyor.
  bool get wonByLegendRule {
    if (outcome == ClashOutcome.draw) return false;
    final kazanan = outcome == ClashOutcome.win ? myMove : opponentMove;
    final kaybeden = outcome == ClashOutcome.win ? opponentMove : myMove;
    if (kazanan == null || kaybeden == null) return false;
    if (kazanan.isPass || kaybeden.isPass) return false;
    if (kazanan.tier != CardTier.legend) return false;
    if (kaybeden.tier == CardTier.legend) return false;

    final kg = kazanan.effectivePower ?? 0;
    final yg = kaybeden.effectivePower ?? 0;
    return kg < yg;
  }

  /// Taktik bonusu eli çevirdi mi?
  ///
  /// Legend kuralı gibi bu da HESAPLAMA DEĞİL, AÇIKLAMA: kazananı sunucu
  /// belirledi. Burada sadece "kazananın taktiksiz gücü (güç + kimya)
  /// kaybedeninkinden yüksek DEĞİLDİ ama bonusla kazandı" durumu tespit
  /// edilip etiketleniyor; oyuncu "83 nasıl 86'yı yendi?" diye şaşırmasın.
  bool get wonByTactic {
    if (outcome == ClashOutcome.draw || wonByLegendRule) return false;
    final kazanan = outcome == ClashOutcome.win ? myMove : opponentMove;
    final kaybeden = outcome == ClashOutcome.win ? opponentMove : myMove;
    if (kazanan == null || kaybeden == null) return false;
    if (kazanan.isPass || kaybeden.isPass) return false;
    if (kazanan.tacticBonus <= 0) return false;

    int taktiksiz(MatchMove m) => (m.power ?? 0) + m.chemistry;
    return taktiksiz(kazanan) <= taktiksiz(kaybeden);
  }

  /// Taktiğim kırıldı mı? (seçtim ama karşı taktik bonusu sıfırladı)
  bool get myTacticCountered {
    final benim = myMove;
    final rakip = opponentMove;
    if (benim == null || rakip == null || benim.isPass) return false;
    if (!benim.hasTactic || benim.tacticBonus > 0) return false;
    return rakip.tactic != null && rakip.tactic == benim.tactic!.beatenBy;
  }

  /// Sonuç bandındaki başlık
  String get headline => switch (outcome) {
        ClashOutcome.win => 'ELİ KAZANDIN!',
        ClashOutcome.loss => 'ELİ KAYBETTİN',
        ClashOutcome.draw => 'BERABERE',
      };

  /// Sonuç bandındaki açıklama
  String get detail {
    if (outcome == ClashOutcome.draw) {
      return 'Kartlar masada kalıyor; sonraki eli kazanan hepsini alır.';
    }
    if (opponentPassed && outcome == ClashOutcome.win) {
      return 'Rakibin bu mevkide kartı yoktu.';
    }
    if (iPassed && outcome == ClashOutcome.loss) {
      return 'Bu mevkide kartın yoktu.';
    }
    if (wonByLegendRule) {
      return 'Legend kuralı: Legend kart alttaki seviyeleri yener.';
    }
    if (wonByTactic) {
      final kazanan = outcome == ClashOutcome.win ? myMove! : opponentMove!;
      final ad = kazanan.tactic!.label;
      return outcome == ClashOutcome.win
          ? '$ad eli çevirdi! (+${kazanan.tacticBonus})'
          : 'Rakibin $ad taktiği eli çevirdi (+${kazanan.tacticBonus}).';
    }
    if (myTacticCountered) {
      return '${myMove!.tactic!.label} boşa gitti: rakip '
          '${opponentMove!.tactic!.label} oynadı.';
    }
    if (outcome == ClashOutcome.win && cardsCollected > 0) {
      return 'Masadan $cardsCollected kart topladın.';
    }
    return '';
  }
}

/// Sunucudan gelen geçmişte HENÜZ GÖSTERİLMEMİŞ turları bulur.
///
/// [alreadyShown] gösterilmiş tur numaraları. İlk yüklemede (maça
/// geri dönüş, uygulama yeniden açıldı) tüm eski turlar "gösterilmiş"
/// sayılmalı; aksi halde oyuncu maça döndüğünde 7 turun animasyonunu
/// art arda izlemek zorunda kalırdı.
List<ClashEvent> findNewClashes({
  required MatchHistory history,
  required Set<int> alreadyShown,
  required String? myUserId,
}) {
  final yeni = history.rounds
      .where((r) => !alreadyShown.contains(r.roundNumber))
      .toList()
    ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));

  return [
    for (final r in yeni)
      ClashEvent.fromServer(
        round: r,
        moves: history.movesForRound(r.roundNumber),
        myUserId: myUserId,
      ),
  ];
}
