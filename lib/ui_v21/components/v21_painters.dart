import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/v21_colors.dart';

/// V2.1'in vektör simgeleri. Referanstaki küçük simgeler (para, yıldız,
/// kart, artı) kırpma yerine vektör çizilir: her yoğunlukta keskin kalır.

/// Altın para (kaynak hapı)
class V21CoinIcon extends StatelessWidget {
  final double size;
  const V21CoinIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [V21Colors.coinLight, V21Colors.coin, V21Colors.coinDark],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = const Color(0x66B86A00),
    );
    // Parlama
    canvas.drawCircle(c.translate(-r * 0.3, -r * 0.32), r * 0.22, Paint()..color = const Color(0xAAFFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Altın yıldız (alt menü SEZON)
class V21StarIcon extends StatelessWidget {
  final double size;
  final Color color;
  const V21StarIcon({super.key, this.size = 30, this.color = V21Colors.coin});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _StarPainter(color));
}

class _StarPainter extends CustomPainter {
  final Color color;
  const _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.48;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path.shift(Offset(0, outer * 0.08)), Paint()..color = const Color(0x55000000));
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, const Color(0xFFFFFFFF), 0.45)!,
            color,
            Color.lerp(color, const Color(0xFF9A4A00), 0.35)!,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}

/// Eğik mor kart ve "?" (alt menü KARTLAR)
class V21CardStackIcon extends StatelessWidget {
  final double size;
  const V21CardStackIcon({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size * 0.8, size), painter: const _CardIconPainter());
}

class _CardIconPainter extends CustomPainter {
  const _CardIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.12);
    final rect = Rect.fromCenter(center: Offset.zero, width: size.width * 0.86, height: size.height * 0.92);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.12));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5BEA), Color(0xFF5A2DB8)],
        ).createShader(rect),
    );
    // Çapraz çizgiler
    canvas.save();
    canvas.clipRRect(rr);
    final stripe = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = size.width * 0.1;
    for (var x = -size.height; x < size.height; x += size.width * 0.32) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, -size.height), stripe);
    }
    canvas.restore();
    // "?" madalyonu
    final r = size.width * 0.24;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.06
        ..color = V21Colors.coin,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(color: V21Colors.coin, fontSize: r * 1.3, fontWeight: FontWeight.w900, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Kesikli yuvarlak dikdörtgen (boş sandık yuvası)
class V21DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  const V21DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 2,
    this.dash = 6,
    this.gap = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    for (final metric in (Path()..addRRect(rr)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant V21DashedRRectPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth;
}

/// Lig kalkanı: üst köşeleri yuvarlak, alt kenarı geniş "U"
class V21ShieldClipper extends CustomClipper<Path> {
  const V21ShieldClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.2;
    return Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h * 0.58)
      // Referans: alt kenar geniş "U" (sivri değil)
      ..cubicTo(w, h * 0.9, w * 0.78, h, w * 0.5, h)
      ..cubicTo(w * 0.22, h, 0, h * 0.9, 0, h * 0.58)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
