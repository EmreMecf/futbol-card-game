import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/avatar2d/avatar_painter.dart';
import '../../../../../shared/widgets/avatar2d/avatar_spec.dart';
import 'figure_rig.dart';

/// Arena figürünü çizer. Kafa, kart portresiyle AYNI fonksiyondan
/// ([AvatarDraw.head]) gelir; karakter karttan sahaya geçtiğinde yüzü
/// değişmez.
///
/// Çizim sırası (arkadan öne): gölge, uzak kol, uzak bacak, şort,
/// gövde, yakın bacak, yakın kol, boyun + kafa, top. Kafa kollardan
/// sonra çizilir: büyük kafalı stilde kalkan kollar yüzü örtmesin.
class FigureDraw {
  const FigureDraw._();

  static const Color boot = Color(0xFF1C1F26);
  static const double _kontur = 1.4;

  /// Kafanın gövdeye oranı (chibi: büyük kafa)
  static const double headScale = 0.62;

  /// [origin]: figürün yerdeki ayak hizası (kalçanın 30 birim altı).
  /// [scale]: birim başına piksel. [facingRight] false ise aynalanır.
  static void paint(
    Canvas c,
    AvatarSpec s,
    Pose p, {
    required Offset origin,
    required double scale,
    bool facingRight = true,
    MouthStyle? mouth,
    bool drawBall = true,
    double opacity = 1,
  }) {
    final g = FigureGeometry.of(p);
    c.save();
    c.translate(origin.dx, origin.dy);
    c.scale(facingRight ? scale : -scale, scale);
    c.translate(0, -30);

    if (opacity < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }

    // ---- Yer gölgesi ----
    final ziplama = (-p.y).clamp(0.0, 20.0) / 20;
    c.drawOval(
      Rect.fromCenter(center: Offset(g.hip.dx + 2, 30.5), width: 32 * (1 - ziplama * 0.45), height: 6),
      Paint()..color = Colors.black.withValues(alpha: 0.32 * (1 - ziplama * 0.5)),
    );

    final kalinlik = s.build.widthFactor;
    final ten = s.skin.color;
    final tenG = shade(ten, 0.10);

    // ---- Uzak kol ----
    _uzuv(c, g.shoulder, g.elbowB, 6.2 * kalinlik, shade(s.jersey, 0.12));
    _uzuv(c, g.elbowB, g.handB, 5.0 * kalinlik, tenG);

    // ---- Uzak bacak ----
    _bacak(c, s, g.hip, g.kneeB, g.footB, g.shinAngleB, kalinlik, uzak: true);

    // ---- Şort ----
    c.save();
    c.translate(g.hip.dx, g.hip.dy);
    c.rotate(p.torso * 0.5);
    final sort = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 2), width: 17 * kalinlik, height: 10), const Radius.circular(3.5));
    c.drawRRect(sort, Paint()..color = s.shorts);
    c.drawRRect(sort, _cizgi(kAvatarOutline, _kontur));
    c.restore();

    // ---- Gövde (forma) ----
    c.save();
    c.translate(g.hip.dx, g.hip.dy);
    c.rotate(p.torso);
    final gw = 16 * kalinlik;
    final govde = RRect.fromRectAndRadius(
        Rect.fromLTWH(-gw / 2, -FigureGeometry.torsoLen - 1, gw, FigureGeometry.torsoLen + 4),
        Radius.circular(gw * 0.42));
    c.drawRRect(govde, Paint()..color = s.jersey);
    c.save();
    c.clipRRect(govde);
    // Gölge (arka taraf) ve yan şerit
    c.drawRect(Rect.fromLTWH(-gw / 2, -40, gw * 0.28, 50), Paint()..color = shade(s.jersey, 0.09));
    c.drawLine(Offset(gw * 0.22, -FigureGeometry.torsoLen + 1), Offset(gw * 0.22, 2),
        Paint()
          ..color = s.jerseyTrim
          ..strokeWidth = 1.8);
    c.restore();
    c.drawRRect(govde, _cizgi(kAvatarOutline, _kontur));
    c.restore();

    // ---- Yakın bacak ----
    _bacak(c, s, g.hip, g.kneeF, g.footF, g.shinAngleF, kalinlik);

    // ---- Yakın kol ----
    _uzuv(c, g.shoulder, g.elbowF, 6.2 * kalinlik, s.jersey);
    _uzuv(c, g.elbowF, g.handF, 5.0 * kalinlik, ten);
    if (s.wristband != null) {
      final b = Offset.lerp(g.elbowF, g.handF, 0.72)!;
      final yon = g.handF - g.elbowF;
      final n = yon / math.max(0.001, yon.distance);
      c.drawLine(b - n * 1.3, b + n * 1.3,
          Paint()
            ..color = s.wristband!
            ..strokeWidth = 5.6 * kalinlik
            ..strokeCap = StrokeCap.butt);
    }

    // ---- Boyun + kafa (EN ÜSTTE: kalkan kollar yüzü kapatmaz) ----
    _uzuv(c, g.neck, Offset.lerp(g.neck, g.headCenter, 0.5)!, 5.5, tenG);
    c.save();
    c.translate(g.headCenter.dx, g.headCenter.dy);
    c.rotate(p.torso * 0.35 + p.head);
    c.scale(headScale);
    // Aynalanan figürde yüz yine izleyiciye bakar; sadece yönü değişir
    AvatarDraw.head(c, s, mouth: mouth);
    c.restore();

    // ---- Top ----
    if (drawBall && p.ballAlpha > 0.01) {
      ballAt(c, g.ball, p.ballAlpha);
    }

    if (opacity < 1) c.restore();
    c.restore();
  }

  /// Futbol topu (figür biriminde, r ~4.3)
  static void ballAt(Canvas c, Offset m, [double alpha = 1]) {
    const r = 4.3;
    c.drawCircle(m, r, Paint()..color = Colors.white.withValues(alpha: alpha));
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: m, radius: r)));
    final koyu = Paint()..color = const Color(0xFF22252C).withValues(alpha: alpha);
    final besgen = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final o = m + Offset(math.cos(a), math.sin(a)) * 1.7;
      i == 0 ? besgen.moveTo(o.dx, o.dy) : besgen.lineTo(o.dx, o.dy);
    }
    c.drawPath(besgen..close(), koyu);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      c.drawCircle(m + Offset(math.cos(a), math.sin(a)) * 4.6, 1.5, koyu);
    }
    c.restore();
    c.drawCircle(m, r, _cizgi(kAvatarOutline.withValues(alpha: alpha), 1.1));
  }

  static Paint _cizgi(Color renk, double w) => Paint()
    ..color = renk
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Konturlu yuvarlak uçlu uzuv
  static void _uzuv(Canvas c, Offset a, Offset b, double w, Color renk) {
    c.drawLine(a, b, _cizgi(kAvatarOutline, w + _kontur * 2));
    c.drawLine(a, b, _cizgi(renk, w));
  }

  static void _bacak(Canvas c, AvatarSpec s, Offset kalca, Offset diz, Offset ayak, double baldirAcisi,
      double kalinlik, {bool uzak = false}) {
    final ten = uzak ? shade(s.skin.color, 0.10) : s.skin.color;
    final corap = uzak ? shade(s.jersey, 0.12) : s.jersey;
    // Uyluk: üst yarısı şort altında kalır
    _uzuv(c, kalca, diz, 6.6 * kalinlik, ten);
    // Baldır: çorap
    _uzuv(c, diz, ayak, 6.0 * kalinlik, corap);
    // Çorap bandı
    final bant = Offset.lerp(diz, ayak, 0.18)!;
    c.drawCircle(bant, 3.0 * kalinlik, Paint()..color = s.jerseyTrim);
    // Krampon: baldıra dik, ileri doğru
    final ileri = Offset(math.cos(baldirAcisi), -math.sin(baldirAcisi));
    _uzuv(c, ayak - ileri * 1.0, ayak + ileri * 5.5, 5.4, uzak ? const Color(0xFF14161B) : boot);
  }
}

/// Tek figürü kutuya çizen ressam (önizleme ve testler için)
class FigurePainter extends CustomPainter {
  final AvatarSpec spec;
  final Pose pose;
  final bool facingRight;
  final MouthStyle? mouth;

  const FigurePainter(this.spec, this.pose, {this.facingRight = true, this.mouth});

  @override
  void paint(Canvas canvas, Size size) {
    // Figür ~95 birim yüksek; kutuya sığdır
    final k = size.height / 100;
    FigureDraw.paint(canvas, spec, pose,
        origin: Offset(size.width / 2, size.height * 0.94), scale: k, facingRight: facingRight, mouth: mouth);
  }

  @override
  bool shouldRepaint(FigurePainter old) =>
      old.pose != pose || old.spec != spec || old.facingRight != facingRight || old.mouth != mouth;
}
