import 'package:json_annotation/json_annotation.dart';

/// Saha pozisyonlari.
///
/// @JsonValue degerleri veritabanindaki `card_position` enum'u ile
/// birebir aynidir. Degistirirsen SQL tarafini da degistirmen gerekir.
@JsonEnum()
enum CardPosition {
  @JsonValue('GK')
  goalkeeper('GK', 'Kaleci', 'KL'),

  @JsonValue('DEF')
  defender('DEF', 'Defans', 'DF'),

  @JsonValue('MID')
  midfielder('MID', 'Orta Saha', 'OS'),

  @JsonValue('FWD')
  forward('FWD', 'Forvet', 'FV');

  /// Veritabanindaki deger
  final String code;

  /// Ekranda gosterilecek tam ad
  final String label;

  /// Kart uzerindeki kisa rozet
  final String shortLabel;

  const CardPosition(this.code, this.label, this.shortLabel);

  /// Zorunlu formasyonda bu pozisyondan kac kart olmali?
  /// (1 kaleci, 4 defans, 4 orta saha, 2 forvet = 11)
  int get requiredCount => switch (this) {
        CardPosition.goalkeeper => 1,
        CardPosition.defender => 4,
        CardPosition.midfielder => 4,
        CardPosition.forward => 2,
      };

  static CardPosition fromCode(String code) {
    return CardPosition.values.firstWhere(
      (p) => p.code == code,
      orElse: () => throw ArgumentError('Bilinmeyen pozisyon: $code'),
    );
  }
}

/// Kart seviyeleri. Sira onemlidir: bronze < silver < gold < diamond < legend
@JsonEnum()
enum CardTier {
  @JsonValue('bronze')
  bronze('bronze', 'Bronz', 1),

  @JsonValue('silver')
  silver('silver', 'Gumus', 2),

  @JsonValue('gold')
  gold('gold', 'Altin', 3),

  @JsonValue('diamond')
  diamond('diamond', 'Diamond', 4),

  @JsonValue('legend')
  legend('legend', 'Legend', 5);

  final String code;
  final String label;

  /// Sayisal siralama (karsilastirma icin)
  final int rank;

  const CardTier(this.code, this.label, this.rank);

  bool get isLegend => this == CardTier.legend;

  static CardTier fromCode(String code) {
    return CardTier.values.firstWhere(
      (t) => t.code == code,
      orElse: () => throw ArgumentError('Bilinmeyen seviye: $code'),
    );
  }
}

/// Mac durumlari
@JsonEnum()
enum MatchStatus {
  @JsonValue('active')
  active,

  @JsonValue('finished')
  finished,

  @JsonValue('cancelled')
  cancelled;

  bool get isActive => this == MatchStatus.active;
  bool get isOver => this != MatchStatus.active;
}

/// `find_match` sonucunun durumu
@JsonEnum()
enum MatchmakingStatus {
  /// Kuyruga alindi, rakip bekleniyor
  @JsonValue('queued')
  queued,

  /// Rakip bulundu, mac kuruldu
  @JsonValue('matched')
  matched,

  /// Zaten devam eden bir macin var
  @JsonValue('in_match')
  inMatch,

  @JsonValue('cancelled')
  cancelled,

  @JsonValue('not_in_queue')
  notInQueue;
}

// =====================================================================
// OYUNUN EN KRITIK KURALI: KART KARSILASTIRMA
// =====================================================================

/// Bir tur karsilasmasinin sonucu
enum CardDuelResult { win, lose, draw }

/// Iki karti karsilastirir.
///
/// ONEMLI UYARI:
/// Bu fonksiyon SADECE ARAYUZ icindir (kart secerken "bu kazanir mi?"
/// onizlemesi gostermek gibi). Macin gercek sonucunu HER ZAMAN sunucu
/// belirler; veritabanindaki `compare_cards()` fonksiyonu tek yetkilidir.
/// Burasi ile SQL tarafi ayni kurallari uygular ama biri digerine
/// guvenmez.
///
/// KURALLAR:
///   1) Legend kart, Legend olmayan HER karti gucune bakilmaksizin yener.
///   2) Iki Legend karsilasirsa, gucu yuksek olan kazanir.
///   3) Legend olmayan iki kartta seviye degil, sadece GUC belirleyicidir.
CardDuelResult compareCards({
  required CardTier aTier,
  required int aPower,
  required CardTier bTier,
  required int bPower,
}) {
  // Kural 1: Legend ustunlugu
  if (aTier.isLegend && !bTier.isLegend) return CardDuelResult.win;
  if (bTier.isLegend && !aTier.isLegend) return CardDuelResult.lose;

  // Kural 2 ve 3: Guc karsilastirmasi
  if (aPower > bPower) return CardDuelResult.win;
  if (aPower < bPower) return CardDuelResult.lose;
  return CardDuelResult.draw;
}
