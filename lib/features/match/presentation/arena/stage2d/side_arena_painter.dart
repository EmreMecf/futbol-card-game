import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SADE 2.5D ARENA — yan görünüm.
///
/// Gerçekçi stadyum DEĞİL; kartlarla aynı evrenden düz renkli bir sahne:
///   * Üst %40: koyu gece gökyüzü, tribün silueti, iki projektör ışığı
///   * Reklam bandı: ince koyu şerit, vurgu çizgisi
///   * Saha: aşağı doğru kalınlaşan çim şeritleri (derinlik hissi),
///     yassı orta yuvarlak, orta çizgi
///
/// Figürler [groundY] hizasında durur. Her şey tek CustomPainter;
/// yeni bağımlılık ya da görsel dosyası yok.
class SideArenaPainter extends CustomPainter {
  /// Sahaya vuran vurgu ışığı (kazananın nadirlik rengi; null = nötr)
  final Color? spotlight;

  /// 0..1 ışık şiddeti (sonuç anında artar)
  final double spotlightStrength;

  /// Spot ışığının yatay konumu (0..1)
  final double spotlightX;

  const SideArenaPainter({this.spotlight, this.spotlightStrength = 0, this.spotlightX = 0.5});

  static double groundY(Size s) => s.height * 0.80;
  static double horizonY(Size s) => s.height * 0.44;

  @override
  void paint(Canvas c, Size s) {
    final ufuk = horizonY(s);

    // ---- Gökyüzü ----
    final gok = Rect.fromLTWH(0, 0, s.width, ufuk);
    c.drawRect(
        gok,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF070B14), Color(0xFF14213A)],
          ).createShader(gok));

    // ---- Projektör ışıkları ----
    for (final x in [0.12, 0.88]) {
      final m = Offset(s.width * x, s.height * 0.06);
      c.drawCircle(
          m,
          s.width * 0.35,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFBFD9FF).withValues(alpha: 0.22),
              const Color(0xFFBFD9FF).withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: m, radius: s.width * 0.35)));
      c.drawCircle(m, s.width * 0.012, Paint()..color = const Color(0xFFEAF3FF));
    }

    // ---- Tribün (üç kat basamak silueti + seyirci noktaları) ----
    final tribunUst = s.height * 0.16;
    for (var kat = 0; kat < 3; kat++) {
      final y0 = tribunUst + kat * (ufuk - tribunUst - s.height * 0.05) / 3;
      final h = (ufuk - tribunUst - s.height * 0.05) / 3;
      final r = Rect.fromLTWH(0, y0, s.width, h);
      c.drawRect(r, Paint()..color = Color.lerp(const Color(0xFF111A2B), const Color(0xFF1A2740), kat / 2)!);
      final rnd = math.Random(7 + kat);
      final nokta = Paint();
      for (var x = 4.0; x < s.width; x += 7 + kat.toDouble()) {
        nokta.color = [
          const Color(0xFF2EC4B6),
          const Color(0xFFD6334A),
          const Color(0xFFF2C94C),
          const Color(0xFF8FA3BF),
        ][rnd.nextInt(4)]
            .withValues(alpha: 0.28 + kat * 0.06);
        c.drawCircle(Offset(x + rnd.nextDouble() * 3, y0 + h * (0.35 + rnd.nextDouble() * 0.3)), 1.4 + kat * 0.3,
            nokta);
      }
    }

    // ---- Reklam bandı ----
    final bant = Rect.fromLTWH(0, ufuk - s.height * 0.05, s.width, s.height * 0.05);
    c.drawRect(bant, Paint()..color = const Color(0xFF0B1120));
    c.drawRect(Rect.fromLTWH(0, bant.top, s.width, 1.5), Paint()..color = const Color(0xFF2EC4B6).withValues(alpha: 0.6));
    for (var x = s.width * 0.06; x < s.width; x += s.width * 0.22) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, bant.top + bant.height * 0.3, s.width * 0.12, bant.height * 0.4), const Radius.circular(2)),
          Paint()..color = Colors.white.withValues(alpha: 0.10));
    }

    // ---- Saha: aşağı doğru kalınlaşan şeritler ----
    final saha = Rect.fromLTWH(0, ufuk, s.width, s.height - ufuk);
    c.drawRect(saha, Paint()..color = const Color(0xFF1E6B3A));
    var y = ufuk;
    var i = 0;
    var kalinlik = s.height * 0.03;
    while (y < s.height) {
      c.drawRect(Rect.fromLTWH(0, y, s.width, kalinlik),
          Paint()..color = i.isEven ? const Color(0xFF2A8048) : const Color(0xFF237340));
      y += kalinlik;
      kalinlik *= 1.32;
      i++;
    }

    // ---- Saha çizgileri ----
    final cizgi = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, s.width * 0.004);
    c.drawLine(Offset(0, ufuk + 2), Offset(s.width, ufuk + 2), cizgi);
    c.drawLine(Offset(s.width / 2, ufuk + 2), Offset(s.width / 2, s.height), cizgi);
    c.drawOval(
        Rect.fromCenter(center: Offset(s.width / 2, groundY(s) - s.height * 0.06), width: s.width * 0.42, height: s.height * 0.20),
        cizgi);

    // ---- Sonuç spot ışığı ----
    if (spotlight != null && spotlightStrength > 0) {
      final m = Offset(s.width * spotlightX, groundY(s) - s.height * 0.1);
      final r = s.width * 0.32;
      c.drawCircle(
          m,
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(colors: [
              spotlight!.withValues(alpha: 0.30 * spotlightStrength),
              spotlight!.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: m, radius: r)));
    }

    // ---- Kenar karartma ----
    final tum = Offset.zero & s;
    c.drawRect(
        tum,
        Paint()
          ..shader = RadialGradient(
            radius: 0.9,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
            stops: const [0.6, 1],
          ).createShader(tum));
  }

  @override
  bool shouldRepaint(SideArenaPainter old) =>
      old.spotlight != spotlight || old.spotlightStrength != spotlightStrength || old.spotlightX != spotlightX;
}
