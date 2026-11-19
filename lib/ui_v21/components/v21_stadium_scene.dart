import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gece stadyumu: gök, projektörler, tribün, reklam şeridi ve çim.
/// Tamamen kodla çizilir; görselde karakter ya da yazı yoktur.
class V21StadiumScene extends StatelessWidget {
  /// Çim çizgisinin yüksekliğe oranı
  final double horizon;
  const V21StadiumScene({super.key, this.horizon = 0.56});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(painter: _StadiumPainter(horizon), size: Size.infinite),
    ),
  );
}

class _StadiumPainter extends CustomPainter {
  final double horizon;
  const _StadiumPainter(this.horizon);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = h * horizon;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF100B4F), Color(0xFF2A1596), Color(0xFF5A1FB8)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, line)),
    );

    // Tribün
    final standTop = math.max(line * 0.62, line - h * 0.13);
    canvas.drawRect(Rect.fromLTRB(0, standTop, w, line), Paint()..color = const Color(0xFF1B1464));
    const crowd = [Color(0xFFFF5C8A), Color(0xFFFFC94D), Color(0xFF4FC3FF), Color(0xFFB678FF), Color(0xFFFF8A4D)];
    final rnd = math.Random(7);
    final dot = Paint();
    final step = math.max(5.0, w / 70);
    for (var y = standTop + step; y < line - step; y += step * 0.9) {
      for (var x = rnd.nextDouble() * step; x < w; x += step) {
        dot.color = crowd[rnd.nextInt(crowd.length)].withValues(alpha: 0.75);
        canvas.drawCircle(Offset(x, y), step * 0.36, dot);
      }
    }

    // Çatı ışık şeridi
    canvas.drawRect(
      Rect.fromLTWH(0, standTop - 5, w, 5),
      Paint()
        ..color = const Color(0xFF58D8FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
    );

    // Reklam şeridi
    final board = h * 0.022;
    const boards = [Color(0xFF2E7BFF), Color(0xFF8A3FE0), Color(0xFFE03FA8)];
    final bw = w / 9;
    for (var i = 0; i < 9; i++) {
      canvas.drawRect(Rect.fromLTWH(i * bw, line - board, bw, board), Paint()..color = boards[i % 3]);
    }

    // Çim
    final grass = Rect.fromLTRB(0, line, w, h);
    canvas.drawRect(
      grass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3FAE3A), Color(0xFF1E7A2C), Color(0xFF0F4A22)],
        ).createShader(grass),
    );
    final stripe = Paint()..color = const Color(0x1AFFFFFF);
    final sh = (h - line) / 6;
    for (var i = 0; i < 6; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, line + i * sh, w, sh), stripe);
    }

    // Projektörler
    for (final left in [true, false]) {
      final cx = left ? w * 0.12 : w * 0.88;
      final cy = line * 0.2;
      final r = math.min(w, h) * 0.05;
      final beam = Path()
        ..moveTo(cx - r, cy)
        ..lineTo(cx + r, cy)
        ..lineTo(left ? cx + w * 0.42 : cx - w * 0.14, line)
        ..lineTo(left ? cx + w * 0.14 : cx - w * 0.42, line)
        ..close();
      canvas.drawPath(beam, Paint()..color = const Color(0x1F9FE4FF));
      canvas.drawCircle(
        Offset(cx, cy),
        r * 1.7,
        Paint()
          ..color = const Color(0x8858C8FF)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
      );
      final panel = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      canvas.drawRRect(
        RRect.fromRectAndRadius(panel, Radius.circular(r * 0.25)),
        Paint()..color = const Color(0xFF26307A),
      );
      final bulb = Paint()..color = const Color(0xFFEAF8FF);
      for (var i = -1; i <= 1; i++) {
        for (var j = -1; j <= 1; j++) {
          canvas.drawCircle(Offset(cx + i * r * 0.58, cy + j * r * 0.58), r * 0.22, bulb);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_StadiumPainter old) => old.horizon != horizon;
}
