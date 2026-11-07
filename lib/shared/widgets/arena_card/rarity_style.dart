import 'package:flutter/painting.dart';
import 'package:shared_models/shared_models.dart';

/// Nadirliğe göre kart efekti (artan sırada)
enum RarityEffect {
  /// Bronz: efekt yok, mat
  none,

  /// Gümüş: sabit, hafif üst parlaklık
  sheen,

  /// Altın: arada bir geçen parlama şeridi
  shine,

  /// Elmas: kesik yüzey çizgileri + daha sık parlama
  prism,

  /// Efsane: dönen çok renkli çerçeve + renk kayan zemin
  holo,
}

/// 2D KART TASARIM SİSTEMİ — 5 nadirlik için TOKEN'lar.
///
/// KURAL: Zemin HER nadirlikte koyu. Nadirlik zeminden değil
/// ÇERÇEVE + VURGU RENGİ + EFEKT ile anlaşılır. Böylece karakter
/// portresi her kartta aynı kontrastla okunur ve 5 nadirlik yan yana
/// tek bir aile gibi durur.
class RarityStyle {
  final CardTier tier;
  final String label;

  /// Güç rakamı, mevki etiketi zemini, isim plakası çizgisi
  final Color accent;

  /// Vurgunun açık tonu (güç rakamı)
  final Color accentLight;

  /// Çerçeve degradesi
  final List<Color> frame;

  /// Koyu zeminin üst (renk tonlu) ve alt (ortak) rengi
  final Color backgroundTop;
  static const Color backgroundBottom = Color(0xFF0A0D13);

  /// Vurgu rengi üstündeki yazı (mevki etiketi)
  static const Color onAccent = Color(0xFF12151C);

  final RarityEffect effect;

  /// Kart etrafındaki ışık yarıçapı (kart genişliğine oran)
  final double glow;

  const RarityStyle({
    required this.tier,
    required this.label,
    required this.accent,
    required this.accentLight,
    required this.frame,
    required this.backgroundTop,
    required this.effect,
    required this.glow,
  });

  static RarityStyle of(CardTier t) => switch (t) {
        CardTier.bronze => bronze,
        CardTier.silver => silver,
        CardTier.gold => gold,
        CardTier.diamond => diamond,
        CardTier.legend => legend,
      };

  static const bronze = RarityStyle(
    tier: CardTier.bronze,
    label: 'BRONZ',
    accent: Color(0xFFD08A57),
    accentLight: Color(0xFFF6D3B4),
    frame: [Color(0xFF6E4127), Color(0xFFD6955F), Color(0xFF8C5634)],
    backgroundTop: Color(0xFF22170F),
    effect: RarityEffect.none,
    glow: 0.0,
  );

  static const silver = RarityStyle(
    tier: CardTier.silver,
    label: 'GÜMÜŞ',
    accent: Color(0xFFC9D3DF),
    accentLight: Color(0xFFF4F7FA),
    frame: [Color(0xFF6F7884), Color(0xFFF2F5F9), Color(0xFF8D97A4)],
    backgroundTop: Color(0xFF161B23),
    effect: RarityEffect.sheen,
    glow: 0.03,
  );

  static const gold = RarityStyle(
    tier: CardTier.gold,
    label: 'ALTIN',
    accent: Color(0xFFF2C94C),
    accentLight: Color(0xFFFFEDB0),
    frame: [Color(0xFF94690F), Color(0xFFFFE58A), Color(0xFFC9971C)],
    backgroundTop: Color(0xFF221A08),
    effect: RarityEffect.shine,
    glow: 0.06,
  );

  static const diamond = RarityStyle(
    tier: CardTier.diamond,
    label: 'ELMAS',
    accent: Color(0xFF5CE1F5),
    accentLight: Color(0xFFD4F8FF),
    frame: [Color(0xFF1F7A99), Color(0xFFC8F7FF), Color(0xFF3BB8D6)],
    backgroundTop: Color(0xFF0A1D26),
    effect: RarityEffect.prism,
    glow: 0.09,
  );

  static const legend = RarityStyle(
    tier: CardTier.legend,
    label: 'EFSANE',
    accent: Color(0xFFC77DFF),
    accentLight: Color(0xFFF1DEFF),
    frame: [
      Color(0xFF7B2CBF),
      Color(0xFFFF6BD6),
      Color(0xFFFFC72C),
      Color(0xFF4CC9F0),
      Color(0xFF7B2CBF),
    ],
    backgroundTop: Color(0xFF1A0D2A),
    effect: RarityEffect.holo,
    glow: 0.13,
  );

  static const List<RarityStyle> all = [bronze, silver, gold, diamond, legend];
}
