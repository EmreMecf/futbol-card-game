import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

/// Kimya bağlarının renkleri
class ChemistryColors {
  const ChemistryColors._();

  /// Güçlü bağ (+2): aynı kulüp, ya da aynı ligde aynı uyruk
  static const Color strong = Color(0xFF29CC7A);

  /// Zayıf bağ (+1): aynı uyruk ya da aynı lig
  static const Color weak = Color(0xFFFFC72C);

  /// Bağ yok (0)
  static const Color none = Color(0xFFE5484D);

  static Color of(ChemistryQuality kalite) => switch (kalite) {
        ChemistryQuality.strong => strong,
        ChemistryQuality.weak => weak,
        ChemistryQuality.none => none,
      };
}

/// Formasyondaki slotların ekran üzerindeki konumları (0.0 - 1.0 arası).
///
/// Oran olarak tutuluyor ki saha ne kadar büyük olursa olsun dizilim
/// bozulmasın. y=0 üstte (forvetler), y=1 altta (kaleci).
const Map<int, Offset> kSlotPositions = {
  // Forvetler
  9: Offset(0.34, 0.10),
  10: Offset(0.66, 0.10),
  // Orta saha
  5: Offset(0.13, 0.38),
  6: Offset(0.38, 0.38),
  7: Offset(0.62, 0.38),
  8: Offset(0.87, 0.38),
  // Defans
  1: Offset(0.13, 0.66),
  2: Offset(0.38, 0.66),
  3: Offset(0.62, 0.66),
  4: Offset(0.87, 0.66),
  // Kaleci
  0: Offset(0.50, 0.92),
};

/// Kimya bağlarını çizen ressam.
///
/// NEDEN CustomPainter?
/// 17 bağı 17 ayrı widget'la çizmek hem gereksiz katman yaratır hem de
/// çizgileri kartların ARKASINA almayı zorlaştırır. Tek Canvas'ta
/// çizince hem performanslı hem de katman sırası netleşiyor:
/// önce çizgiler, sonra kartlar.
class ChemistryLinksPainter extends CustomPainter {
  final List<ChemistryLink> links;

  /// Vurgulanan slot (dokunulan kart) — ona bağlı çizgiler kalınlaşır
  final int? highlightedSlot;

  const ChemistryLinksPainter({
    required this.links,
    this.highlightedSlot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final bag in links) {
      final a = kSlotPositions[bag.slotA];
      final b = kSlotPositions[bag.slotB];
      if (a == null || b == null) continue;

      final p1 = Offset(a.dx * size.width, a.dy * size.height);
      final p2 = Offset(b.dx * size.width, b.dy * size.height);

      final vurgulu = highlightedSlot != null && bag.touches(highlightedSlot!);
      final renk = ChemistryColors.of(bag.quality);

      // Bağ yoksa çizgi çok soluk: ekranı kırmızıya boğmasın,
      // ama oyuncu eksik bağlantıyı yine de görebilsin.
      final saydamlik = bag.quality == ChemistryQuality.none
          ? (vurgulu ? 0.55 : 0.18)
          : (vurgulu ? 1.0 : 0.65);

      final boya = Paint()
        ..color = renk.withValues(alpha: saydamlik)
        ..strokeWidth = vurgulu ? 3.2 : 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, boya);

      // Güçlü bağlarda ortada küçük bir parlama
      if (bag.quality == ChemistryQuality.strong) {
        final orta = Offset.lerp(p1, p2, 0.5)!;
        canvas.drawCircle(
          orta,
          vurgulu ? 4.0 : 3.0,
          Paint()..color = renk.withValues(alpha: vurgulu ? 0.9 : 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ChemistryLinksPainter oldDelegate) =>
      oldDelegate.highlightedSlot != highlightedSlot ||
      !_ayniMi(oldDelegate.links, links);

  bool _ayniMi(List<ChemistryLink> a, List<ChemistryLink> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].score != b[i].score ||
          a[i].slotA != b[i].slotA ||
          a[i].slotB != b[i].slotB) {
        return false;
      }
    }
    return true;
  }
}

/// Saha zemini (çim deseni ve çizgiler)
class PitchBackground extends StatelessWidget {
  const PitchBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PitchPainter(),
      size: Size.infinite,
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final alan = Offset.zero & size;

    // Çim degradesi
    canvas.drawRect(
      alan,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E2A1A), Color(0xFF061810)],
        ).createShader(alan),
    );

    // Yatay çim şeritleri
    final serit = Paint()..color = Colors.white.withValues(alpha: 0.022);
    final seritYuksekligi = size.height / 8;
    for (var i = 0; i < 8; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * seritYuksekligi, size.width, seritYuksekligi),
        serit,
      );
    }

    final cizgi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.10);

    // Orta saha çizgisi ve daire
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      cizgi,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.14,
      cizgi,
    );

    // Ceza sahası (alt)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height - size.height * 0.16,
        size.width * 0.56,
        size.height * 0.16,
      ),
      cizgi,
    );
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}
