import 'package:flutter/painting.dart';

/// V2.1 renk paleti.
///
/// Değerler `design/reference/FutbolCard_V21_Telefon_HTML_Prototip.html`
/// içindeki 390×844 Figma ekranlarından PİKSEL ÖRNEKLENEREK alındı
/// (`assets/v21/screens/home.png`). Koordinatlar yorumlarda.
///
/// Ref UI (`Ref`) paletinden bağımsızdır: eski ekranlar değişmeden kalır.
abstract final class V21Colors {
  // ---- Zemin --------------------------------------------------------
  /// Ekran üstü gece göğü (5,5) #100B50
  static const Color skyTop = Color(0xFF100B50);

  /// Orta mor (stadyum ışık halkası)
  static const Color skyMid = Color(0xFF2A0F6B);

  /// Alt bölge, sandık şeridi zemini (195,700) #1B0F4B
  static const Color floor = Color(0xFF1B0F4B);

  /// En koyu lacivert: çerçeve kenarı, süre hapı (55,738) #1B0E3A
  static const Color ink = Color(0xFF1B0E3A);

  /// Metin gölgesi / derin kontur
  static const Color inkDeep = Color(0xFF120933);

  // ---- Panel --------------------------------------------------------
  /// Sandık yuvası iç zemini (30,680) #29145F
  static const Color panel = Color(0xFF29145F);

  /// Panel üst ton (gradyan)
  static const Color panelHigh = Color(0xFF3A1F86);

  /// Boş yuva zemini (240,700) #2A1D54
  static const Color panelEmpty = Color(0xFF2A1D54);

  /// Boş yuva kesikli çizgi (200,700) #5A4A90
  static const Color dash = Color(0xFF5A4A90);

  /// Kaynak hapı zemini (320,36) #180D41
  static const Color pill = Color(0xFF180D41);

  /// Kaynak hapı ince kenarı
  static const Color pillBorder = Color(0xFF4B3C6F);

  // ---- Alt menü -----------------------------------------------------
  /// Üst çizgi (100,765) #6B4BD8
  static const Color navLine = Color(0xFF6B4BD8);

  /// Zemin üst (60,800) #20104B
  static const Color navTop = Color(0xFF20104B);

  /// Zemin alt (60,835) #160B38
  static const Color navBottom = Color(0xFF160B38);

  /// Etiket (pasif)
  static const Color navLabel = Color(0xFFB5A6E0);

  /// Etkin sekme karosu: üst / alt / kenar (157,800) #3E80F2
  static const Color navActiveTop = Color(0xFF66B4FF);
  static const Color navActiveBottom = Color(0xFF2F6FEA);
  static const Color navActiveBorder = Color(0xFF3E80F2);

  // ---- Metin --------------------------------------------------------
  static const Color text = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFC9BCEB);
  static const Color textDim = Color(0xFF8E7FBE);

  // ---- Vurgu --------------------------------------------------------
  /// Altın düğme üst (195,568) #FFD94E
  static const Color goldTop = Color(0xFFFFD94E);

  /// Altın düğme alt (195,632) #FF9307
  static const Color goldBottom = Color(0xFFFF9307);

  /// Altın düğme 3B dudağı (195,640) #DC7301
  static const Color goldLip = Color(0xFFD06A00);

  /// Altın düğme ince kenar (40,600) #FFB01B
  static const Color goldEdge = Color(0xFFFFE27A);

  /// Altın metin gölgesi
  static const Color goldShadow = Color(0xFFA24E00);

  /// Lig rozeti altın panel üst/alt (200,88) #FADA71 → (200,135) #DD9620
  static const Color badgeGoldTop = Color(0xFFFADA71);
  static const Color badgeGoldBottom = Color(0xFFDD9620);

  /// Lig kalkanı mor (70,130) #833DCF
  static const Color shieldTop = Color(0xFFE3A9FA);
  static const Color shieldBottom = Color(0xFF8A3FD0);

  /// İlerleme dolgusu yeşil (90,45) #7CE96F
  static const Color progressGreen = Color(0xFF7CE96F);
  static const Color progressGreenDark = Color(0xFF3CC24E);

  /// İlerleme yolu: koyu (160,45) #180D45 ve altın panel üzerinde
  /// kahverengi (270,123) #6C4B38
  static const Color trackDark = Color(0xFF180D45);
  static const Color trackBrown = Color(0xFF6C4B38);

  /// Seviye dairesi mavi (34,36) #4F99F7
  static const Color levelBlue = Color(0xFF4F99F7);
  static const Color levelBlueDark = Color(0xFF2A62D6);

  /// Altın para
  static const Color coin = Color(0xFFFFC933);
  static const Color coinLight = Color(0xFFFFEE9F);
  static const Color coinDark = Color(0xFFE08A00);

  // ---- Durum --------------------------------------------------------
  /// Sayacı çalışan sandık kenarı (13,700) #3DD15A
  static const Color success = Color(0xFF3DD15A);

  /// Sayaç metni
  static const Color successText = Color(0xFF85E27C);
  static const Color danger = Color(0xFFFF4D6A);
  static const Color dangerDark = Color(0xFFB0193A);
  static const Color info = Color(0xFF3D9FFF);

  // ---- Nadirlik / sandık türü kenarları ------------------------------
  /// Altın (106,700) #FFC832
  static const Color rarityGold = Color(0xFFFFC832);

  /// Efsane (292,700) #C77DFF
  static const Color rarityLegend = Color(0xFFC77DFF);
  static const Color rarityDiamond = Color(0xFF5FD8FF);
  static const Color raritySilver = Color(0xFFC6D3E0);
  static const Color rarityBronze = Color(0xFFD9925E);
}
