import 'package:shared_models/shared_models.dart';

/// Bir kartın nasıl açılacağını belirleyen üç kademe.
///
/// -------------------------------------------------------------------
/// NEDEN KADEMELİ?
/// -------------------------------------------------------------------
/// Her karta aynı görkemli animasyonu oynatırsak, o animasyon 15 kart
/// sonra "beklenen bir şey" hâline gelir ve heyecan tamamen ölür.
/// Heyecan FARKTAN doğar: bronz kartlar hızlı geçtiği için, ekran
/// kararıp spot ışığı vurduğunda oyuncu daha kartı görmeden ne
/// olduğunu anlar.
///
/// Bu yüzden süreler bilinçli olarak çok farklı:
///   Basit  -> 0.35 sn   (göz kırpması kadar; akışı yavaşlatmaz)
///   Altın  -> 0.75 sn   (fark edilir ama bekletmez)
///   Walkout-> ~4.5 sn   (durup izlenecek bir olay)
enum RevealStyle {
  /// Bronz / Gümüş — hızlı kart dönme (flip)
  simple,

  /// Altın — hafif parlama + biraz daha uzun dönme
  golden,

  /// Diamond / Legend — ekran kararır, tam WALKOUT sahnesi
  walkout;

  /// Kartın seviyesine göre hangi kademe?
  static RevealStyle forTier(CardTier tier) {
    if (tier.rank >= CardTier.diamond.rank) return RevealStyle.walkout;
    if (tier == CardTier.gold) return RevealStyle.golden;
    return RevealStyle.simple;
  }

  bool get isWalkout => this == RevealStyle.walkout;

  /// Kart dönme (flip) animasyonunun süresi.
  /// Walkout'ta flip yoktur; kart sahnenin sonunda vurarak gelir.
  Duration get flipDuration => switch (this) {
        RevealStyle.simple => const Duration(milliseconds: 350),
        RevealStyle.golden => const Duration(milliseconds: 750),
        RevealStyle.walkout => Duration.zero,
      };

  /// Kart göründüğünde hangi şiddette titreşim?
  ///
  /// Bronz kartta titreşim YOK: 15 kartın 12'sinde titreyen bir telefon
  /// rahatsız edici olur ve titreşim "önemli bir şey oldu" anlamını
  /// tamamen kaybeder.
  HapticStrength get haptic => switch (this) {
        RevealStyle.simple => HapticStrength.none,
        RevealStyle.golden => HapticStrength.light,
        RevealStyle.walkout => HapticStrength.heavy,
      };
}

/// Titreşim şiddeti (Flutter'ın HapticFeedback çağrılarına eşlenir)
enum HapticStrength { none, light, heavy }
