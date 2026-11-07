import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Referanstaki SEMBOL karakterleri (⌂ ▣ ♟ ⚔ ▤ ☻ ✦ ▶ →).
///
/// NEDEN ÇİZİYORUZ?
/// Bunlar oyunun yazı tiplerinde (Barlow Condensed, Nunito) yok. Tarayıcı
/// referansı Windows'un Segoe UI Symbol'ünden çiziyor; Android ve web'de
/// aynı yazı tipi yok ve "kutu" görünür (FAZ 6'da ✦ ve → için yaşandı).
/// Şekiller referanstaki karakterlerin görünüşüne göre vektörle çizildi:
/// her platformda aynı ve keskin.
enum RefGlyph { home, cards, pawn, swords, shop, smile, sparkle, play, arrowRight, search }

class RefGlyphIcon extends StatelessWidget {
  final RefGlyph glyph;
  final double size;
  final Color color;

  const RefGlyphIcon(this.glyph, {super.key, this.size = 19, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _GlyphPainter(glyph, color)),
      );
}

class _GlyphPainter extends CustomPainter {
  final RefGlyph g;
  final Color c;
  const _GlyphPainter(this.g, this.c);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final dolgu = Paint()..color = c;
    final cizgi = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.085)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Offset p(double x, double y) => Offset(x * w, y * w);

    switch (g) {
      case RefGlyph.home: // ⌂
        canvas.drawPath(
            Path()
              ..moveTo(p(0.2, 0.86).dx, p(0.2, 0.86).dy)
              ..lineTo(p(0.2, 0.48).dx, p(0.2, 0.48).dy)
              ..lineTo(p(0.5, 0.2).dx, p(0.5, 0.2).dy)
              ..lineTo(p(0.8, 0.48).dx, p(0.8, 0.48).dy)
              ..lineTo(p(0.8, 0.86).dx, p(0.8, 0.86).dy)
              ..close(),
            cizgi);
      case RefGlyph.cards: // ▣
        canvas.drawRect(Rect.fromLTRB(w * 0.16, w * 0.16, w * 0.84, w * 0.84), cizgi);
        canvas.drawRect(Rect.fromLTRB(w * 0.33, w * 0.33, w * 0.67, w * 0.67), dolgu);
      case RefGlyph.shop: // ▤
        canvas.drawRect(Rect.fromLTRB(w * 0.16, w * 0.16, w * 0.84, w * 0.84), cizgi);
        for (final y in [0.38, 0.5, 0.62]) {
          canvas.drawLine(p(0.16, y), p(0.84, y), cizgi..strokeWidth = math.max(1, w * 0.06));
        }
      case RefGlyph.pawn: // ♟
        canvas.drawCircle(p(0.5, 0.26), w * 0.13, dolgu);
        canvas.drawPath(
            Path()
              ..moveTo(p(0.4, 0.4).dx, p(0.4, 0.4).dy)
              ..lineTo(p(0.6, 0.4).dx, p(0.6, 0.4).dy)
              ..quadraticBezierTo(p(0.62, 0.62).dx, p(0.62, 0.62).dy, p(0.74, 0.76).dx, p(0.74, 0.76).dy)
              ..lineTo(p(0.26, 0.76).dx, p(0.26, 0.76).dy)
              ..quadraticBezierTo(p(0.38, 0.62).dx, p(0.38, 0.62).dy, p(0.4, 0.4).dx, p(0.4, 0.4).dy)
              ..close(),
            dolgu);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.2, w * 0.76, w * 0.8, w * 0.88), Radius.circular(w * 0.04)),
            dolgu);
      case RefGlyph.swords: // ⚔
        final k = cizgi..strokeWidth = math.max(1.2, w * 0.08);
        canvas.drawLine(p(0.18, 0.18), p(0.82, 0.82), k);
        canvas.drawLine(p(0.82, 0.18), p(0.18, 0.82), k);
        // Kabzalar
        canvas.drawLine(p(0.62, 0.84), p(0.84, 0.62), k);
        canvas.drawLine(p(0.38, 0.84), p(0.16, 0.62), k);
      case RefGlyph.smile: // ☻
        final bos = Paint()..blendMode = BlendMode.clear;
        canvas.saveLayer(Offset.zero & s, Paint());
        canvas.drawCircle(p(0.5, 0.5), w * 0.36, dolgu);
        canvas.drawCircle(p(0.38, 0.42), w * 0.05, bos);
        canvas.drawCircle(p(0.62, 0.42), w * 0.05, bos);
        canvas.drawArc(Rect.fromCenter(center: p(0.5, 0.52), width: w * 0.36, height: w * 0.28), 0.3, math.pi - 0.6,
            false, Paint()
              ..blendMode = BlendMode.clear
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.07);
        canvas.restore();
      case RefGlyph.sparkle: // ✦
        final m = p(0.5, 0.5);
        final r = w * 0.48, ic = w * 0.13;
        final yol = Path();
        for (var i = 0; i < 8; i++) {
          final a = -math.pi / 2 + i * math.pi / 4;
          final o = m + Offset(math.cos(a), math.sin(a)) * (i.isEven ? r : ic);
          i == 0 ? yol.moveTo(o.dx, o.dy) : yol.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(yol..close(), dolgu);
      case RefGlyph.play: // ▶
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.2, w * 0.12)
              ..lineTo(w * 0.9, w * 0.5)
              ..lineTo(w * 0.2, w * 0.88)
              ..close(),
            dolgu);
      case RefGlyph.arrowRight: // →
        final k = cizgi..strokeWidth = math.max(1.2, w * 0.09);
        canvas.drawLine(p(0.12, 0.52), p(0.86, 0.52), k);
        canvas.drawLine(p(0.6, 0.28), p(0.86, 0.52), k);
        canvas.drawLine(p(0.6, 0.76), p(0.86, 0.52), k);
      case RefGlyph.search:
        final k = cizgi..strokeWidth = math.max(1.2, w * 0.1);
        canvas.drawCircle(p(0.42, 0.42), w * 0.24, k);
        canvas.drawLine(p(0.6, 0.6), p(0.85, 0.85), k);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.g != g || old.c != c;
}

/// Renkli emoji (🏆 🛡️ 🃏 🎯 ...). Referans bunları emoji olarak kullanıyor.
class Em extends StatelessWidget {
  final String emoji;
  final double size;
  final double height;
  const Em(this.emoji, {super.key, required this.size, this.height = 1.2});

  @override
  Widget build(BuildContext context) => Text(
        emoji,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size,
          height: height,
          fontFamilyFallback: const ['Segoe UI Emoji', 'Noto Color Emoji', 'Apple Color Emoji'],
        ),
      );
}

/// Altın sikke (referansta 🪙; bu emoji Windows'ta bile kutu çiziliyor,
/// o yüzden çizim)
class CoinGlyph extends StatelessWidget {
  final double size;
  const CoinGlyph({super.key, this.size = 11});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CoinPainter()),
      );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final m = s.center(Offset.zero);
    final r = s.width / 2;
    c.drawCircle(m, r, Paint()..color = const Color(0xFFB7791F));
    c.drawCircle(m - Offset(0, r * 0.08), r * 0.86, Paint()..color = const Color(0xFFF8C665));
    c.drawCircle(m - Offset(0, r * 0.08), r * 0.52,
        Paint()
          ..color = const Color(0xFFD99A2B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16);
  }

  @override
  bool shouldRepaint(_CoinPainter old) => false;
}
