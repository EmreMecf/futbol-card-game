import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'card_tier_theme.dart';

/// Kartin CERCEVESINI cizen ressam.
///
/// NEDEN CustomPainter, NEDEN Container DEGIL?
/// FIFA kartlarinin silueti basit bir dikdortgen degil: ust kose
/// pahlanmis, alt kenar hafif ic bukey, cerceve kalinligi kenarlara
/// gore degisiyor. Bunu ic ice gecmis Container'larla yapmak hem
/// okunmaz bir agac hem de gereksiz katman yaratir.
///
/// Tek bir Canvas uzerinde cizince:
///   * istedigimiz her sekli olusturabiliyoruz,
///   * degradeler seklin kendisine uyuyor (kutuya degil),
///   * katman sayisi dusuyor, performans artiyor.
class CardFramePainter extends CustomPainter {
  final CardTierTheme theme;

  /// Cerceve degradesinin donme acisi (Legend kartlarda animasyonlu)
  final double gradientRotation;

  /// Kartin kose yuvarlakligi
  final double cornerRadius;

  /// Ust koselerdeki pah (kesik kose) uzunlugu
  final double bevel;

  const CardFramePainter({
    required this.theme,
    this.gradientRotation = 0,
    this.cornerRadius = 18,
    this.bevel = 26,
  });

  /// Kartin dis siluetini uretir.
  /// Bu yol hem cizim hem de kirpma (clip) icin kullanilir.
  static Path buildCardPath(Size size, {double cornerRadius = 18, double bevel = 26}) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;

    return Path()
      // Sol ust: pahli kose
      ..moveTo(0, bevel)
      ..lineTo(bevel, 0)
      // Ust kenar
      ..lineTo(w - bevel, 0)
      // Sag ust: pahli kose
      ..lineTo(w, bevel)
      // Sag kenar
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      // Alt kenar: cok hafif ic bukey (kartin oturakli gorunmesi icin)
      ..quadraticBezierTo(w / 2, h - 6, r, h)
      // Sol alt kose
      ..quadraticBezierTo(0, h, 0, h - r)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final yol = buildCardPath(size, cornerRadius: cornerRadius, bevel: bevel);
    final alan = Offset.zero & size;

    // ---- 1) DIS CERCEVE: metalik degrade ----
    // Degradeyi dondurmek icin merkez etrafinda aci hesapliyoruz.
    // Legend kartlarda bu aci surekli degisir ve renkler akiyormus
    // gibi gorunur.
    final aci = gradientRotation;
    final baslangic = Alignment(math.cos(aci), math.sin(aci));
    final bitis = Alignment(-math.cos(aci), -math.sin(aci));

    final cerceveBoya = Paint()
      ..shader = LinearGradient(
        colors: theme.frameGradient,
        begin: baslangic,
        end: bitis,
      ).createShader(alan);

    canvas.drawPath(yol, cerceveBoya);

    // ---- 2) METALIK BANT ----
    // Gercek metallerde isik tek yonden gelmez; yuzeyde acik-koyu
    // seritler olusur. Ustten asagi giden yari saydam beyaz bir bant
    // kartin "duz renk" gorunmesini engelliyor.
    final bantBoya = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.02),
          Colors.black.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.14),
        ],
        stops: const [0.0, 0.35, 0.62, 1.0],
      ).createShader(alan)
      ..blendMode = BlendMode.overlay;

    canvas.drawPath(yol, bantBoya);

    // ---- 3) IC PANEL ----
    // Cerceveden bir miktar iceride, oyuncu gorselinin arkasinda
    // duracak koyu alan.
    final kalinlik = size.width * 0.055;
    final icAlan = Rect.fromLTWH(
      kalinlik,
      kalinlik,
      size.width - kalinlik * 2,
      size.height - kalinlik * 2,
    );

    final icYol = buildCardPath(
      icAlan.size,
      cornerRadius: cornerRadius * 0.7,
      bevel: bevel * 0.7,
    ).shift(Offset(kalinlik, kalinlik));

    canvas.drawPath(
      icYol,
      Paint()
        ..shader = LinearGradient(
          colors: theme.panelGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(icAlan),
    );

    // ---- 4) IC KENAR CIZGISI ----
    // Cerceve ile panel arasinda ince bir isik cizgisi, iki yuzeyin
    // ayri malzemeler oldugunu hissettirir.
    canvas.drawPath(
      icYol,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(CardFramePainter oldDelegate) {
    return oldDelegate.gradientRotation != gradientRotation ||
        oldDelegate.theme != theme ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.bevel != bevel;
  }
}

/// Kart siluetine gore kirpma yapan sekil.
/// Oyuncu gorselinin cerceve disina tasmamasini saglar.
class CardShapeBorder extends ShapeBorder {
  final double cornerRadius;
  final double bevel;

  const CardShapeBorder({this.cornerRadius = 18, this.bevel = 26});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return CardFramePainter.buildCardPath(
      rect.size,
      cornerRadius: cornerRadius,
      bevel: bevel,
    ).shift(rect.topLeft);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) =>
      CardShapeBorder(cornerRadius: cornerRadius * t, bevel: bevel * t);
}
