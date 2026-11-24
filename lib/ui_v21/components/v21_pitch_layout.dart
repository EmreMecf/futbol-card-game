import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

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
/// Değerler referans HTML'deki `formations['4-4-2']` dizisinden birebir
/// (x%, y%): ST 36/14, 64/14; MID 15/38, 38/39, 62/39, 85/38;
/// DEF 14/69, 38/69, 62/69, 86/69; GK 50/90. y=0 üst (forvetler).
const Map<int, Offset> kSlotPositions = {
  // Forvetler
  9: Offset(0.36, 0.14),
  10: Offset(0.64, 0.14),
  // Orta saha
  5: Offset(0.15, 0.38),
  6: Offset(0.38, 0.39),
  7: Offset(0.62, 0.39),
  8: Offset(0.85, 0.38),
  // Defans
  1: Offset(0.14, 0.69),
  2: Offset(0.38, 0.69),
  3: Offset(0.62, 0.69),
  4: Offset(0.86, 0.69),
  // Kaleci
  0: Offset(0.50, 0.90),
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

