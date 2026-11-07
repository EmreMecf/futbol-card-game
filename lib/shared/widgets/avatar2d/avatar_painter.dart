import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'avatar_spec.dart';

// =====================================================================
// 2D KARAKTER ÇİZİMİ (vektör, kodla)
// =====================================================================
// STİL KURALLARI (docs/GORSEL_YON_2D.md bölüm 1):
//   * Düz renk + tek gölge tonu (cel shading). Degrade yok.
//   * Her ana şeklin etrafında aynı koyu kontur (çıkartma hissi).
//   * Büyük kafa, basit yüz: nokta göz, tek çizgi burun, kısa ağız.
//   * Işık sol üstten gelir; gölge her zaman sağ-alt tarafta.
//
// [AvatarDraw.head] kafayı (0,0) merkezli "kafa biriminde" çizer
// (kafa ~40 birim genişlik, ~46 birim yükseklik). Kart portresi ve
// arena figürü AYNI fonksiyonu kullanır; bu yüzden karakter karttan
// sahaya geçtiğinde yüzü birebir aynıdır.

const Color kAvatarOutline = Color(0xFF15121C);
const double _kontur = 1.6;

Color shade(Color c, [double miktar = 0.18]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - miktar).clamp(0.0, 1.0)).toColor();
}

Color tint(Color c, [double miktar = 0.12]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + miktar).clamp(0.0, 1.0)).toColor();
}

Paint _dolgu(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint _cizgi(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// Şekli doldurur ve konturunu çizer
void _sekil(Canvas c, Path p, Color renk, {double kontur = _kontur}) {
  c.drawPath(p, _dolgu(renk));
  if (kontur > 0) c.drawPath(p, _cizgi(kAvatarOutline, kontur));
}

class AvatarDraw {
  const AvatarDraw._();

  // -------------------------------------------------------------------
  // KAFA ŞEKLİ
  // -------------------------------------------------------------------
  static Path headPath(HeadShape s) => switch (s) {
        HeadShape.oval => Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 46)),
        HeadShape.round => Path()..addOval(Rect.fromCenter(center: const Offset(0, 1), width: 42, height: 43)),
        HeadShape.long => Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 35, height: 50)),
        HeadShape.square => Path()
          ..addRRect(RRect.fromLTRBAndCorners(-19.5, -22, 19.5, 23,
              topLeft: const Radius.circular(17),
              topRight: const Radius.circular(17),
              bottomLeft: const Radius.circular(12),
              bottomRight: const Radius.circular(12))),
      };

  static double _yariGenislik(HeadShape s) => switch (s) {
        HeadShape.oval => 19,
        HeadShape.round => 21,
        HeadShape.long => 17.5,
        HeadShape.square => 19.5,
      };

  /// Saç çizgisinin üstünde kalan bölge (kafa ile kesişince "takke")
  static Path _takke(double yanY, double ortaY) => Path()
    ..moveTo(-32, -42)
    ..lineTo(32, -42)
    ..lineTo(32, yanY)
    ..lineTo(21, yanY)
    ..quadraticBezierTo(0, 2 * ortaY - yanY, -21, yanY)
    ..lineTo(-32, yanY)
    ..close();

  static Path _birlesim(List<Path> parcalar) {
    var p = parcalar.first;
    for (final q in parcalar.skip(1)) {
      p = Path.combine(PathOperation.union, p, q);
    }
    return p;
  }

  // -------------------------------------------------------------------
  // KAFA (saç, yüz, aksesuar dahil)
  // -------------------------------------------------------------------
  static void head(Canvas c, AvatarSpec s, {MouthStyle? mouth, BrowStyle? brows}) {
    final kafa = headPath(s.head);
    final yg = _yariGenislik(s.head);
    final ten = s.skin.color;
    final tenGolge = shade(ten, 0.10);

    // ---- Arka saç (kafanın arkasında) ----
    switch (s.hair) {
      case HairStyle.afro:
        final afro = Path()..addOval(Rect.fromCircle(center: const Offset(0, -9), radius: 28));
        _sekil(c, afro, s.hairColor);
        final doku = _cizgi(tint(s.hairColor, 0.07), 1.1);
        for (var i = 0; i < 7; i++) {
          final a = math.pi * (1.0 + i * 0.17);
          c.drawArc(Rect.fromCircle(center: Offset(math.cos(a) * 23, -9 + math.sin(a) * 23), radius: 3),
              a - 1, 2, false, doku);
        }
      case HairStyle.longWavy:
        final arka = Path()
          ..moveTo(-yg - 2, -8)
          ..quadraticBezierTo(-yg - 6, 16, -yg - 2, 30)
          ..quadraticBezierTo(-yg + 4, 26, -yg + 6, 32)
          ..lineTo(yg - 6, 32)
          ..quadraticBezierTo(yg - 4, 26, yg + 2, 30)
          ..quadraticBezierTo(yg + 6, 16, yg + 2, -8)
          ..close();
        _sekil(c, arka, shade(s.hairColor, 0.06));
      default:
        break;
    }

    // ---- Kulaklar ----
    for (final x in [-yg, yg]) {
      final kulak = Path()..addOval(Rect.fromCenter(center: Offset(x, 3), width: 8, height: 10));
      _sekil(c, kulak, x > 0 ? tenGolge : ten);
      c.drawArc(Rect.fromCenter(center: Offset(x * 1.0, 3), width: 4, height: 5.5),
          x > 0 ? -1.2 : 1.9, 2.4, false, _cizgi(shade(ten, 0.2), 1));
    }
    if (s.headAccessory == HeadAccessory.earring) {
      c.drawCircle(Offset(-yg, 9.5), 1.9, _dolgu(const Color(0xFFF2C94C)));
      c.drawCircle(Offset(-yg, 9.5), 1.9, _cizgi(kAvatarOutline, 0.8));
    }

    // ---- Yüz: düz ten + sağ-alt gölge hilali ----
    c.save();
    c.clipPath(kafa);
    c.drawPath(kafa, _dolgu(tenGolge));
    c.drawPath(kafa.shift(const Offset(-3.2, -1.8)), _dolgu(ten));

    // Yanak allığı
    final allik = _dolgu(const Color(0xFFFF6F7D).withValues(alpha: 0.18));
    c.drawCircle(const Offset(-11, 9), 3.6, allik);
    c.drawCircle(const Offset(11, 9), 3.6, allik);

    // Çiller
    if (s.freckles) {
      final cil = _dolgu(shade(ten, 0.22).withValues(alpha: 0.75));
      for (final o in const [
        Offset(-13, 6.5), Offset(-10.5, 8), Offset(-12.5, 9.5), Offset(-9, 6.2),
        Offset(13, 6.5), Offset(10.5, 8), Offset(12.5, 9.5), Offset(9, 6.2),
        Offset(-2, 5.5), Offset(2, 5.5),
      ]) {
        c.drawCircle(o, 0.65, cil);
      }
    }

    // Sakal / kirli sakal (kafaya kırpılı)
    switch (s.facialHair) {
      case FacialHair.stubble:
        c.drawPath(
            Path()..addOval(Rect.fromCenter(center: const Offset(0, 19), width: 36, height: 22)),
            _dolgu(s.hairColor.withValues(alpha: 0.22)));
      case FacialHair.beard:
        final sakal = Path()
          ..moveTo(-yg - 2, 0)
          ..lineTo(-yg + 3, 0)
          ..quadraticBezierTo(-12, 16, 0, 16.5)
          ..quadraticBezierTo(12, 16, yg - 3, 0)
          ..lineTo(yg + 2, 0)
          ..lineTo(yg + 2, 30)
          ..lineTo(-yg - 2, 30)
          ..close();
        c.drawPath(sakal, _dolgu(s.hairColor));
      default:
        break;
    }

    // Saç bandı (kafaya kırpılı)
    if (s.headAccessory == HeadAccessory.headband) {
      final bant = Path.combine(PathOperation.difference, _takke(-9.5, -16), _takke(-4.5, -11));
      c.drawPath(bant, _dolgu(const Color(0xFFF4F4F6)));
      c.drawPath(bant, _cizgi(kAvatarOutline, 1));
    }
    c.restore();

    // Kafa konturu
    c.drawPath(kafa, _cizgi(kAvatarOutline, _kontur));

    // ---- Saç (önde) ----
    _onSac(c, s, kafa, yg);

    // ---- Kaşlar ----
    final kas = brows ?? s.brows;
    final kasKalin = kas == BrowStyle.thick ? 2.8 : 2.0;
    final kasRenk = _cizgi(shade(s.hairColor, s.hairColor.computeLuminance() > 0.5 ? 0.35 : 0.05), kasKalin);
    for (final yon in [-1.0, 1.0]) {
      final ic = Offset(yon * 4, kas == BrowStyle.angled ? -3.2 : -5.6);
      final dis = Offset(yon * 12.5, kas == BrowStyle.angled ? -6.8 : -5.4);
      c.drawPath(
          Path()
            ..moveTo(ic.dx, ic.dy)
            ..quadraticBezierTo(yon * 8, kas == BrowStyle.soft ? -7.4 : -6.6, dis.dx, dis.dy),
          kasRenk);
    }

    // ---- Gözler ----
    for (final x in [-8.0, 8.0]) {
      _goz(c, s, Offset(x, 1.5), ten);
    }
    if (s.headAccessory == HeadAccessory.eyeBlack) {
      for (final x in [-8.0, 8.0]) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 6.8), width: 6.5, height: 1.8),
            const Radius.circular(1)), _dolgu(const Color(0xFF1A1A1A)));
      }
    }

    // ---- Burun ----
    c.drawPath(
        Path()
          ..moveTo(0.8, 4.5)
          ..quadraticBezierTo(3, 9.4, -0.8, 9.8),
        _cizgi(shade(ten, 0.24), 1.3));

    // ---- Bıyık ----
    if (s.facialHair == FacialHair.mustache || s.facialHair == FacialHair.beard) {
      final biyik = Path()
        ..moveTo(-6.5, 12.4)
        ..quadraticBezierTo(0, 8.6, 6.5, 12.4)
        ..quadraticBezierTo(0, 11.4, -6.5, 12.4)
        ..close();
      c.drawPath(biyik, _dolgu(s.hairColor));
      c.drawPath(biyik, _cizgi(kAvatarOutline, 0.8));
    }

    // ---- Ağız ----
    _agiz(c, mouth ?? s.mouth, s.facialHair == FacialHair.beard);
  }

  static void _goz(Canvas c, AvatarSpec s, Offset m, Color ten) {
    final koyu = Color.lerp(s.eyeColor, const Color(0xFF14121A), 0.55)!;
    switch (s.eyes) {
      case EyeStyle.dot:
        c.drawOval(Rect.fromCenter(center: m, width: 4.4, height: 5.6), _dolgu(koyu));
        c.drawCircle(m + const Offset(0.9, -1.2), 0.95, _dolgu(Colors.white));
      case EyeStyle.almond:
        final beyaz = Path()..addOval(Rect.fromCenter(center: m, width: 7.4, height: 4.8));
        c.drawPath(beyaz, _dolgu(Colors.white));
        c.save();
        c.clipPath(beyaz);
        c.drawCircle(m, 2.3, _dolgu(s.eyeColor));
        c.drawCircle(m, 1.15, _dolgu(const Color(0xFF111111)));
        c.restore();
        c.drawCircle(m + const Offset(0.8, -0.9), 0.7, _dolgu(Colors.white));
        c.drawArc(Rect.fromCenter(center: m, width: 7.4, height: 4.8), math.pi * 1.05, math.pi * 0.9,
            false, _cizgi(kAvatarOutline, 1.3));
      case EyeStyle.sleepy:
        c.drawOval(Rect.fromCenter(center: m, width: 4.6, height: 5), _dolgu(koyu));
        c.drawCircle(m + const Offset(0.9, 0.6), 0.8, _dolgu(Colors.white));
        // Üst göz kapağı
        c.drawRect(Rect.fromLTWH(m.dx - 3, m.dy - 3.4, 6, 3.0), _dolgu(ten));
        c.drawLine(m + const Offset(-3, -0.4), m + const Offset(3, -0.4), _cizgi(kAvatarOutline, 1.3));
    }
  }

  static void _agiz(Canvas c, MouthStyle m, bool sakalli) {
    final cizgi = _cizgi(const Color(0xFF3A1E22), 1.6);
    final y = sakalli ? 14.6 : 14.0;
    switch (m) {
      case MouthStyle.smile:
        c.drawPath(
            Path()
              ..moveTo(-5, y - 1)
              ..quadraticBezierTo(0, y + 3.6, 5, y - 1),
            cizgi);
      case MouthStyle.grin:
        final agiz = Path()
          ..moveTo(-6, y - 1.5)
          ..quadraticBezierTo(0, y + 7, 6, y - 1.5)
          ..close();
        c.drawPath(agiz, _dolgu(const Color(0xFF5A1F27)));
        c.save();
        c.clipPath(agiz);
        c.drawRect(Rect.fromLTWH(-7, y - 2, 14, 2.6), _dolgu(Colors.white));
        c.drawCircle(Offset(0, y + 5), 3, _dolgu(const Color(0xFFE5737F)));
        c.restore();
        c.drawPath(agiz, _cizgi(kAvatarOutline, 1.2));
      case MouthStyle.serious:
        c.drawLine(Offset(-4, y + 0.5), Offset(4, y + 0.5), cizgi);
      case MouthStyle.smirk:
        c.drawPath(
            Path()
              ..moveTo(-4.5, y + 0.6)
              ..quadraticBezierTo(2, y + 2, 5.5, y - 1.8),
            cizgi);
    }
  }

  static void _onSac(Canvas c, AvatarSpec s, Path kafa, double yg) {
    Path takke(double yan, double orta) =>
        Path.combine(PathOperation.intersect, kafa, _takke(yan, orta));

    final renk = s.hairColor;
    final Path? sac = switch (s.hair) {
      HairStyle.bald => null,
      HairStyle.buzz => takke(-5, -15),
      HairStyle.crop => _birlesim([
          takke(-3, -13),
          Path()..addOval(Rect.fromCenter(center: const Offset(0, -20), width: yg * 2 + 1, height: 12)),
        ]),
      HairStyle.sidePart => _birlesim([
          takke(-2, -13),
          Path()..addOval(Rect.fromCenter(center: const Offset(1, -20), width: yg * 2 + 1, height: 12)),
          Path()
            ..moveTo(yg - 2, -19)
            ..cubicTo(yg - 4, -9, -2, -9, -yg, -3)
            ..lineTo(-yg + 1, -13)
            ..cubicTo(-8, -26, 8, -28, yg - 2, -19)
            ..close(),
        ]),
      HairStyle.curlyTop => _birlesim([
          takke(-3, -12),
          for (var i = 0; i <= 6; i++)
            Path()
              ..addOval(Rect.fromCircle(
                  center: Offset(math.cos(math.pi * (1.08 + i * 0.14)) * (yg - 1),
                      -7 + math.sin(math.pi * (1.08 + i * 0.14)) * 17),
                  radius: 7)),
        ]),
      HairStyle.afro => takke(-2, -12),
      HairStyle.mohawk => _birlesim([
          Path.combine(PathOperation.intersect, takke(-4, -14),
              Path()..addRect(const Rect.fromLTRB(-5.5, -40, 5.5, 0))),
          Path()
            ..moveTo(-5.5, -14)
            ..lineTo(-6.5, -25)
            ..lineTo(-3.5, -31)
            ..lineTo(-0.5, -26)
            ..lineTo(1.5, -35)
            ..lineTo(3.8, -27)
            ..lineTo(7, -31)
            ..lineTo(5.5, -14)
            ..close(),
        ]),
      HairStyle.bun => _birlesim([
          takke(-3, -12),
          Path()..addOval(Rect.fromCenter(center: const Offset(0, -19), width: yg * 2 - 2, height: 11)),
          Path()..addOval(Rect.fromCircle(center: const Offset(0, -28), radius: 7.5)),
        ]),
      HairStyle.longWavy => _birlesim([
          takke(4, -11),
          Path()..addOval(Rect.fromCenter(center: const Offset(0, -19), width: yg * 2 + 3, height: 13)),
        ]),
      HairStyle.cornrows => takke(-3, -14),
    };

    // İbiğin yanları kazınmış: soluk takke
    if (s.hair == HairStyle.mohawk) {
      c.save();
      c.clipPath(kafa);
      c.drawPath(_takke(-4, -14), _dolgu(renk.withValues(alpha: 0.30)));
      c.restore();
    }
    if (sac == null) {
      // Saçsız: tepe parlaması
      c.drawOval(Rect.fromCenter(center: const Offset(-7, -15), width: 9, height: 4.5),
          _dolgu(Colors.white.withValues(alpha: 0.22)));
      return;
    }

    if (s.hair == HairStyle.buzz) {
      c.drawPath(sac, _dolgu(renk.withValues(alpha: 0.78)));
      return;
    }

    _sekil(c, sac, renk);

    // Saç gölgesi (sağ taraf) ve parlama (sol üst)
    c.drawPath(Path.combine(PathOperation.difference, sac, sac.shift(const Offset(-2.6, -2.2))),
        _dolgu(shade(renk, 0.08)));
    c.drawPath(sac, _cizgi(kAvatarOutline, _kontur));
    c.drawArc(Rect.fromCenter(center: const Offset(-4, -17), width: 18, height: 9), math.pi * 1.1,
        math.pi * 0.35, false, _cizgi(tint(renk, 0.18).withValues(alpha: 0.9), 1.6));

    if (s.hair == HairStyle.cornrows) {
      c.save();
      c.clipPath(sac);
      final cizgi = _cizgi(shade(renk, 0.12), 1.2);
      for (var x = -14.0; x <= 14; x += 5.5) {
        c.drawLine(Offset(x * 0.8, -24), Offset(x, -3), cizgi);
      }
      c.restore();
    }
  }

  // -------------------------------------------------------------------
  // GÖĞÜS PORTRESİ (100 x 100 birim kutu)
  // -------------------------------------------------------------------
  static void bust(Canvas c, AvatarSpec s, {MouthStyle? mouth, BrowStyle? brows}) {
    final omuzGenislik = 1.0 + (s.build.widthFactor - 1) * 0.6;

    // ---- Boyun ----
    c.drawRect(const Rect.fromLTRB(44, 58, 56, 80), _dolgu(shade(s.skin.color, 0.10)));
    c.drawLine(const Offset(44, 60), const Offset(44, 76), _cizgi(kAvatarOutline, _kontur));
    c.drawLine(const Offset(56, 60), const Offset(56, 76), _cizgi(kAvatarOutline, _kontur));

    // ---- Forma ----
    c.save();
    c.translate(50, 0);
    c.scale(omuzGenislik, 1);
    c.translate(-50, 0);
    final forma = Path()
      ..moveTo(5, 101)
      ..cubicTo(7, 85, 17, 78, 35, 75.5)
      ..lineTo(43.5, 73.5)
      ..quadraticBezierTo(50, 81, 56.5, 73.5)
      ..lineTo(65, 75.5)
      ..cubicTo(83, 78, 93, 85, 95, 101)
      ..close();
    c.drawPath(forma, _dolgu(s.jersey));
    c.drawPath(Path.combine(PathOperation.difference, forma, forma.shift(const Offset(-7, -2.5))),
        _dolgu(shade(s.jersey, 0.09)));
    c.save();
    c.clipPath(forma);
    // Omuz şeritleri
    final serit = _cizgi(s.jerseyTrim, 2.4);
    c.drawPath(Path()..moveTo(27, 77)..quadraticBezierTo(17, 84, 13, 101), serit);
    c.drawPath(Path()..moveTo(73, 77)..quadraticBezierTo(83, 84, 87, 101), serit);
    c.restore();
    c.drawPath(forma, _cizgi(kAvatarOutline, _kontur));
    // Yaka
    c.drawPath(
        Path()
          ..moveTo(43, 74)
          ..quadraticBezierTo(50, 83.5, 57, 74),
        _cizgi(s.jerseyTrim, 3.2));
    c.restore();

    // Göğüs numarası
    final tp = TextPainter(
      text: TextSpan(
        text: '${s.shirtNumber}',
        style: TextStyle(
          fontFamily: 'BarlowCondensed',
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: s.jerseyTrim,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(66 - tp.width / 2, 86));

    // ---- Kafa ----
    c.save();
    c.translate(50, 42);
    head(c, s, mouth: mouth, brows: brows);
    c.restore();
  }
}

/// Göğüs portresi ressamı (kart ve detay ekranı)
class AvatarBustPainter extends CustomPainter {
  final AvatarSpec spec;
  final MouthStyle? mouth;

  const AvatarBustPainter(this.spec, {this.mouth});

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * k) / 2, size.height - 100 * k);
    canvas.scale(k);
    AvatarDraw.bust(canvas, spec, mouth: mouth);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AvatarBustPainter old) => old.spec != spec || old.mouth != mouth;
}

/// Kare kutuda göğüs portresi
class AvatarPortrait extends StatelessWidget {
  final AvatarSpec spec;
  final double size;
  final MouthStyle? mouth;

  const AvatarPortrait({super.key, required this.spec, this.size = 120, this.mouth});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(size: Size.square(size), painter: AvatarBustPainter(spec, mouth: mouth)),
      );
}
