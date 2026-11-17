import 'package:flutter/material.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import 'v21_player_card.dart';

/// V2.1 KART ARKA YÜZÜ (referans Arena rakip kartı, Paket Mührü, alt menü
/// KARTLAR): mor çapraz çizgili zemin, altın halkalı "?" madalyonu.
///
/// Oyuncu kartıyla aynı oranı kullanır ([V21PlayerCard.baseWidth] ×
/// [V21PlayerCard.baseHeight]); eğiklik (referansta ~4°) çağıranın işidir.
class V21CardBack extends StatelessWidget {
  final double width;

  /// Ekran okuyucu metni ("Rakip kartı, gizli")
  final String semanticsLabel;

  const V21CardBack({super.key, this.width = V21PlayerCard.baseWidth, this.semanticsLabel = 'Gizli kart'});

  @override
  Widget build(BuildContext context) {
    final k = width / V21PlayerCard.baseWidth;
    final h = V21PlayerCard.baseHeight * k;
    final medal = 76 * k;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        width: width,
        height: h,
        padding: EdgeInsets.all(3 * k),
        decoration: BoxDecoration(
          color: V21Colors.ink,
          borderRadius: BorderRadius.circular(16 * k),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 10 * k, offset: Offset(0, 5 * k)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13 * k),
          child: CustomPaint(
            painter: _BackPainter(k),
            child: Center(
              child: Container(
                width: medal,
                height: medal,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3A1E8A),
                  border: Border.all(color: const Color(0xFFFFC832), width: 4 * k),
                ),
                alignment: Alignment.center,
                child: Text(
                  '?',
                  style: V21Type.title(44 * k, color: const Color(0xFFFFC832), shadows: V21Type.inkShadow(k)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  final double k;
  const _BackPainter(this.k);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7E4EE0), Color(0xFF5A30BE), Color(0xFF4422A0)],
        ).createShader(rect),
    );
    // Çapraz açık şeritler (referans: ~14 px aralık, %8 beyaz)
    final stripe = Paint()
      ..color = const Color(0x16FFFFFF)
      ..strokeWidth = 10 * k;
    for (var x = -size.height; x < size.width + size.height; x += 30 * k) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) => old.k != k;
}
