import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Ana sayfa üst bölgesinin gece göğü: mor bulutlar + iki köşede stadyum
/// projektörü (referans home.png 0..170). Vektör çizilir; kahraman görseli
/// 146. pikselden itibaren bunun üstüne yumuşak geçişle biner.
///
/// Boyut 390×170 tasarım tuvalindedir; [scale] ile ölçeklenir.
class V21StadiumSky extends StatelessWidget {
  final double scale;
  const V21StadiumSky({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(child: CustomPaint(painter: _SkyPainter(scale))),
  );
}

class _SkyPainter extends CustomPainter {
  final double k;
  const _SkyPainter(this.k);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Gök: referans x=3 sütunu #100B4F (0) → #150F76 (75) → #221A9C (105)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF100B4F), Color(0xFF120D64), Color(0xFF1C1690), Color(0xFF1B2AA6)],
          stops: [0, 0.38, 0.66, 1],
        ).createShader(Offset.zero & size),
    );
    // Mor bulutlar (sol orta, sağ üst)
    void cloud(Offset c, double r, Color color) => canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    cloud(Offset(30 * k, 80 * k), 70 * k, const Color(0x996A2BC0));
    cloud(Offset(95 * k, 55 * k), 45 * k, const Color(0x55702BC8));
    cloud(Offset(w - 40 * k, 45 * k), 80 * k, const Color(0x996A2BC0));
    cloud(Offset(w - 10 * k, 105 * k), 50 * k, const Color(0x664A2AB8));

    // Projektörler (sol / sağ alt köşe)
    _floodlight(canvas, Offset(26 * k, h - 22 * k), -0.62);
    _floodlight(canvas, Offset(w - 26 * k, h - 22 * k), 0.62);
  }

  void _floodlight(Canvas canvas, Offset c, double angle) {
    // Işık hâlesi
    canvas.drawCircle(
      c,
      78 * k,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xCC9FD8FF), Color(0x553D8BFF), Color(0x003D8BFF)],
          stops: [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: c, radius: 78 * k)),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final panel = Rect.fromCenter(center: Offset.zero, width: 64 * k, height: 44 * k);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, Radius.circular(6 * k)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5FB2FF), Color(0xFF2559D8)],
        ).createShader(panel),
    );
    final bulb = Paint()..color = const Color(0xFFF4F9FF);
    final glow = Paint()
      ..color = const Color(0x88FFFFFF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * k);
    const cols = 5, rows = 3;
    for (var r = 0; r < rows; r++) {
      for (var col = 0; col < cols; col++) {
        final p = Offset((col - (cols - 1) / 2) * 11.5 * k, (r - (rows - 1) / 2) * 12 * k);
        canvas.drawCircle(p, 5.2 * k, glow);
        canvas.drawCircle(p, 4.4 * k, bulb);
      }
    }
    canvas.restore();
    // Direk
    final dir = Offset(math.sin(angle), math.cos(angle));
    canvas.drawLine(
      c + dir * 20 * k,
      c + dir * 60 * k,
      Paint()
        ..color = const Color(0xFF2A3FB5)
        ..strokeWidth = 5 * k,
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.k != k;
}
