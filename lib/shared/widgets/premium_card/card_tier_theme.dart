import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

/// Bir kart seviyesinin GORSEL KIMLIGI.
///
/// TASARIM FELSEFESI:
/// FIFA kartlarinin ikna edici gorunmesinin sebebi renk secimi degil,
/// MALZEME hissi. Bronz mat ve sicak, Gumus soguk ve puruzsuz, Altin
/// derin ve yansitici, Diamond buzlu ve prizmatik, Legend ise renk
/// degistiren holografik bir yuzey.
///
/// Bu yuzden her seviye icin tek renk degil; bir degrade dizisi,
/// bir "isik vurma" rengi ve efekt anahtarlari tanimliyoruz.
class CardTierTheme {
  /// Cerceve degradesinin renkleri (ust-sol -> alt-sag)
  final List<Color> frameGradient;

  /// Ic panel (oyuncu gorselinin arkasi) degradesi
  final List<Color> panelGradient;

  /// Metin ve rakamlarin rengi
  final Color textColor;

  /// Ikincil metin (pozisyon, kulup)
  final Color mutedTextColor;

  /// Kartin etrafina vuran isik
  final Color glowColor;

  /// Egilme sirasinda yuzeyde gezinen parlama (specular) rengi
  final Color specularColor;

  /// Uzerinden gecen holografik parlama olsun mu?
  final bool hasHolographicSweep;

  /// Cerceve etrafinda donen renkli isik olsun mu? (sadece Legend)
  final bool hasAnimatedBorder;

  /// Parlama suprumunun tekrar araligi
  final Duration sweepInterval;

  /// Isik yayilma yaricapi
  final double glowRadius;

  const CardTierTheme({
    required this.frameGradient,
    required this.panelGradient,
    required this.textColor,
    required this.mutedTextColor,
    required this.glowColor,
    required this.specularColor,
    this.hasHolographicSweep = false,
    this.hasAnimatedBorder = false,
    this.sweepInterval = const Duration(seconds: 6),
    this.glowRadius = 12,
  });

  /// Seviyeye gore temayi doner.
  static CardTierTheme of(CardTier tier) => switch (tier) {
        CardTier.bronze => _bronze,
        CardTier.silver => _silver,
        CardTier.gold => _gold,
        CardTier.diamond => _diamond,
        CardTier.legend => _legend,
      };

  // ==================================================================
  // BRONZ - mat, sicak, dusuk kontrast
  // ==================================================================
  static const _bronze = CardTierTheme(
    frameGradient: [
      Color(0xFF6E4630),
      Color(0xFFB0764F),
      Color(0xFF8A5636),
      Color(0xFF5A3826),
    ],
    panelGradient: [Color(0xFF3B2418), Color(0xFF5C3A26)],
    textColor: Color(0xFFF6E3D2),
    mutedTextColor: Color(0xFFC9A98F),
    glowColor: Color(0x66B0764F),
    specularColor: Color(0x44FFD9B8),
    glowRadius: 8,
  );

  // ==================================================================
  // GUMUS - soguk, puruzsuz, yuksek yansima
  // ==================================================================
  static const _silver = CardTierTheme(
    frameGradient: [
      Color(0xFF8E97A3),
      Color(0xFFE3E8EF),
      Color(0xFFA8B2BE),
      Color(0xFF6F7884),
    ],
    panelGradient: [Color(0xFF2B3138), Color(0xFF454E58)],
    textColor: Color(0xFFFFFFFF),
    mutedTextColor: Color(0xFFCBD3DC),
    glowColor: Color(0x66C0C6CF),
    specularColor: Color(0x55FFFFFF),
    glowRadius: 10,
  );

  // ==================================================================
  // ALTIN - derin, zengin, hafif holografik
  // ==================================================================
  static const _gold = CardTierTheme(
    frameGradient: [
      Color(0xFF8A6410),
      Color(0xFFFFE07A),
      Color(0xFFE8B923),
      Color(0xFF9C7415),
    ],
    panelGradient: [Color(0xFF3D2E06), Color(0xFF6B5210)],
    textColor: Color(0xFFFFF8E1),
    mutedTextColor: Color(0xFFE6CF92),
    glowColor: Color(0x88E8B923),
    specularColor: Color(0x66FFF3C4),
    hasHolographicSweep: true,
    sweepInterval: Duration(seconds: 7),
    glowRadius: 16,
  );

  // ==================================================================
  // DIAMOND - buzlu, prizmatik, soguk parlaklik
  // ==================================================================
  static const _diamond = CardTierTheme(
    frameGradient: [
      Color(0xFF1E6B85),
      Color(0xFFAFF0FF),
      Color(0xFF57D4F0),
      Color(0xFF2A8FB0),
    ],
    panelGradient: [Color(0xFF0B2C38), Color(0xFF14495C)],
    textColor: Color(0xFFF2FDFF),
    mutedTextColor: Color(0xFFAADCEA),
    glowColor: Color(0x9957D4F0),
    specularColor: Color(0x77E6FBFF),
    hasHolographicSweep: true,
    sweepInterval: Duration(seconds: 5),
    glowRadius: 22,
  );

  // ==================================================================
  // LEGEND - renk degistiren holografik yuzey + donen cerceve
  // ==================================================================
  // Legend kartlar oyunun en degerli parcasi. Gucu ne olursa olsun
  // alttaki 4 seviyeyi yendikleri icin gorsel olarak da acikca
  // ayrilmalari gerekiyor: tek kartta uc renk gecisi, surekli
  // holografik akis ve donen bir cerceve isigi.
  static const _legend = CardTierTheme(
    frameGradient: [
      Color(0xFF7B2CBF),
      Color(0xFFFF6BD6),
      Color(0xFFFFC72C),
      Color(0xFF4CC9F0),
    ],
    panelGradient: [Color(0xFF1A0B2E), Color(0xFF3B1259)],
    textColor: Color(0xFFFFFFFF),
    mutedTextColor: Color(0xFFE3C8FF),
    glowColor: 	Color(0xAAB44BFF),
    specularColor: Color(0x88FFE3FB),
    hasHolographicSweep: true,
    hasAnimatedBorder: true,
    sweepInterval: Duration(seconds: 3),
    glowRadius: 30,
  );

  /// Cerceve icin kullanilacak degrade nesnesi
  LinearGradient get frame => LinearGradient(
        colors: frameGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Ic panel icin degrade
  LinearGradient get panel => LinearGradient(
        colors: panelGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}
