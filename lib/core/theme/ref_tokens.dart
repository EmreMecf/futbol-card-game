import 'package:flutter/material.dart';

/// REFERANS TASARIM TOKEN'LARI
///
/// Kaynak: `design-reference/futbol-card-arena.html` (kullanıcının
/// onayladığı tasarım). Buradaki HER değer o dosyanın CSS'inden birebir
/// alınmıştır; tahmin yoktur. Değerin geldiği CSS seçicisi yorumda yazar.
///
/// Renk biçimi: CSS `#rrggbbaa` → Flutter `0xAARRGGBB`.
class Ref {
  const Ref._();

  // ------------------------------------------------------------------
  // :root değişkenleri
  // ------------------------------------------------------------------
  static const Color bg = Color(0xFF080E19); // --bg
  static const Color panel = Color(0xFF0E1728); // --panel
  static const Color panel2 = Color(0xFF142139); // --panel2
  static const Color field = Color(0xFF133B35); // --field
  static const Color accent = Color(0xFF21DFAA); // --accent
  static const Color gold = Color(0xFFF8C665); // --gold
  static const Color text = Color(0xFFEEF5FF); // --text
  static const Color muted = Color(0xFF93A4BD); // --muted
  static const Color red = Color(0xFFF26479); // --red
  static const Color blue = Color(0xFF3BAAFA); // --blue
  static const Color purple = Color(0xFFA56BFF); // --purple

  // ------------------------------------------------------------------
  // Telefon kabuğu
  // ------------------------------------------------------------------
  /// .phone arka planı
  static const Color phoneBg = Color(0xFF08111F);

  /// .phone-header: linear-gradient(#101f31,#0b1728)
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF101F31), Color(0xFF0B1728)],
  );

  /// .currency
  static const Color currencyBg = Color(0xFF060E19);
  static const Color currencyBorder = Color(0xFF31415B);
  static const Color gemText = Color(0xFF66F3D7);

  /// .bottom-nav
  static const Color navBg = Color(0xFF091523);
  static const Color navBorder = Color(0xFF334258);
  static const Color navText = Color(0xFF8194AD);
  static const Color navCurrentBg = Color(0xFF164539);
  static const Color navCurrentText = Color(0xFF5FF5C3);

  // ------------------------------------------------------------------
  // Bileşenler
  // ------------------------------------------------------------------
  /// .pill
  static const Color pillBg = Color(0xFF1D3144);
  static const Color pillBorder = Color(0xFF365062);
  static const Color pillText = Color(0xFFBFD3E7);

  /// .hero
  static const Color heroBorder = Color(0xFF3B6F65);

  /// .tile
  static const Color tileBorder = Color(0xFF2B4662);
  static const LinearGradient tileGradient = LinearGradient(
    // 165deg
    begin: Alignment(-0.26, -0.97),
    end: Alignment(0.26, 0.97),
    colors: [Color(0xFF1A304A), Color(0xFF101B30)],
  );
  static const Color tileSmall = Color(0xFF9EB0C8);
  static const Color tileText = Color(0xFFEFF7FF);

  /// .card-panel: linear-gradient(160deg,#15253c,#101a2d)
  static const LinearGradient cardPanelGradient = LinearGradient(
    begin: Alignment(-0.34, -0.94),
    end: Alignment(0.34, 0.94),
    colors: [Color(0xFF15253C), Color(0xFF101A2D)],
  );
  static const Color cardPanelBorder = Color(0xFF344960);

  /// .bar
  static const Color barTrack = Color(0xFF273A50);
  static const LinearGradient barFill = LinearGradient(colors: [Color(0xFF0BBF88), Color(0xFF62FFD2)]);

  /// .cta: linear-gradient(180deg,#ffe9a8,#f9c76b 45%,#ac6e20)
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE9A8), Color(0xFFF9C76B), Color(0xFFAC6E20)],
    stops: [0, 0.45, 1],
  );
  static const Color ctaShadow = Color(0xFF70400E);
  static const Color ctaGlow = Color(0x44FFBF4C);
  static const Color ctaText = Color(0xFF261705);

  /// .secondary-button
  static const Color secondaryBorder = Color(0xFF248C75);
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF135541), Color(0xFF08352D)],
  );
  static const Color secondaryText = Color(0xFFD1FFEB);

  /// .neutral-button
  static const Color neutralBorder = Color(0xFF435B76);
  static const Color neutralBg = Color(0xFF14243A);
  static const Color neutralText = Color(0xFFF1F5FF);

  /// .filter-row button
  static const Color filterBorder = Color(0xFF304763);
  static const Color filterBg = Color(0xFF142237);
  static const Color filterText = Color(0xFFADBDCE);
  static const Color filterActiveBg = Color(0xFF185C48);
  static const Color filterActiveBorder = Color(0xFF29D99C);
  static const Color filterActiveText = Color(0xFFD5FFF0);

  /// .searchfield
  static const Color searchBorder = Color(0xFF344A65);
  static const Color searchBg = Color(0xFF111E31);

  /// .stat
  static const Color statBg = Color(0xFF14263B);
  static const Color statBorder = Color(0xFF314B62);
  static const Color statValue = Color(0xFF6AFFC8);
  static const Color statLabel = Color(0xFFADBFD3);

  /// .modalback / .modal
  static const Color modalBack = Color(0xCA020810);
  static const Color modalBorder = Color(0xFF786C8B);
  static const Color modalBg = Color(0xFF0F1A2E);
  static const Color modalGlow = Color(0x7B3F3157);

  /// .collectible: linear-gradient(150deg,#182a42,#0d1326 84%)
  static const LinearGradient collectibleGradient = LinearGradient(
    begin: Alignment(-0.5, -0.87),
    end: Alignment(0.5, 0.87),
    colors: [Color(0xFF182A42), Color(0xFF0D1326)],
    stops: [0, 0.84],
  );

  /// .tabstrip
  static const Color tabBorder = Color(0xFF334962);
  static const Color tabBg = Color(0xFF101C2C);
  static const Color tabText = Color(0xFFB8C6D9);
  static const Color tabSelectedBg = Color(0xFF12563F);
  static const Color tabSelectedBorder = Color(0xFF19D999);
  static const Color tabSelectedText = Color(0xFFBAFFDF);

  // ------------------------------------------------------------------
  // Masaüstü kenar çubuğu (.sidebar / .navbtn)
  // ------------------------------------------------------------------
  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0E192B), Color(0xFF080E19)],
  );
  static const Color sidebarBorder = Color(0xFF28364C);
  static const Color sideNavText = Color(0xFFADC0D7);
  static const Color sideNavHover = Color(0xFF1E3046);
  static const Color sideNavActiveText = Color(0xFF9AF7D7);
  static const Color sideNavActiveBorder = Color(0x7725E4AD);
  static const LinearGradient sideNavActive = LinearGradient(
    colors: [Color(0x88116047), Color(0xFF12392F)],
  );
  static const Color sectionLabel = Color(0xFF6C829B);

  /// .workspace zemini (masaüstü içerik alanı)
  static const Color workspaceBg = Color(0xFF0A101C);

  // ------------------------------------------------------------------
  // Ölçüler
  // ------------------------------------------------------------------
  /// .page { padding:14px 14px 18px; gap:13px }
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(14, 14, 14, 18);
  static const double pageGap = 13;

  // ------------------------------------------------------------------
  // Hareket dili (kullanıcının 11. maddesi)
  // ------------------------------------------------------------------
  /// .page animation: fadeSlide .28s
  static const Duration pageTransition = Duration(milliseconds: 280);

  /// .cta transition: transform .15s
  static const Duration press = Duration(milliseconds: 150);

  /// .collectible transition .18s
  static const Duration cardHover = Duration(milliseconds: 180);

  /// .anim-pop: .55s cubic-bezier(.18,1.4,.3,1)
  static const Duration pop = Duration(milliseconds: 550);
  static const Curve popCurve = Cubic(0.18, 1.4, 0.3, 1);

  // ------------------------------------------------------------------
  // Yazı tipleri
  // ------------------------------------------------------------------
  static const String display = 'BarlowCondensed';
  static const String body = 'Nunito';

  /// Emoji için yedek aileler. Android: Noto Color Emoji (sistem),
  /// web: CanvasKit Noto'yu kendisi indirir, Windows: Segoe UI Emoji.
  static const List<String> emojiFallback = [
    'Segoe UI Emoji',
    'Noto Color Emoji',
    'Apple Color Emoji',
  ];

  /// h1,h2,h3,.display { font-family:Barlow Condensed; font-weight:800;
  /// letter-spacing:.015em }
  static TextStyle heading(double size, {Color color = text, FontWeight weight = FontWeight.w800, double? height}) =>
      TextStyle(
        fontFamily: display,
        fontFamilyFallback: emojiFallback,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: size * 0.015,
        color: color,
        height: height,
      );

  static TextStyle h1([Color c = text]) => heading(34, color: c);
  static TextStyle h2([Color c = text]) => heading(27, color: c);
  static TextStyle h3([Color c = text]) => heading(20, color: c);

  /// Gövde: font 14px Nunito
  static TextStyle bodyText(double size, {Color color = text, FontWeight weight = FontWeight.w400, double? height}) =>
      TextStyle(
        fontFamily: body,
        fontFamilyFallback: emojiFallback,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color,
        height: height,
      );

  /// .caps { text-transform:uppercase; letter-spacing:.09em;
  /// font-size:10px; font-weight:900 }
  static TextStyle caps([Color c = text]) =>
      bodyText(10, color: c, weight: FontWeight.w900).copyWith(letterSpacing: 0.9);

  /// small, .tiny { font-size:10px }
  static TextStyle tiny([Color c = text]) => bodyText(10, color: c);
}
