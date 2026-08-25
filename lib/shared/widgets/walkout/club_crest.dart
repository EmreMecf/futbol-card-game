import 'dart:math' as math;

import 'package:flutter/material.dart';

/// KULÜP ARMASI — kulüp adından TÜRETİLEN prosedürel arma.
///
/// -------------------------------------------------------------------
/// NEDEN ÜRETİLİYOR?
/// -------------------------------------------------------------------
/// Kartlar kurgusal kulüplere ait (lisans sorunu olmasın diye).
/// Kurgusal 20+ kulüp için 20+ logo dosyası çizdirmek, henüz kart
/// görselleri bile hazır değilken yanlış sıradaki bir iş olurdu.
///
/// Bunun yerine arma kulüp ADINDAN türetiliyor:
///   * Renkler adın karma değerinden (hash) seçiliyor,
///   * Ortadaki harfler adın baş harfleri,
///   * Kalkan biçimi ve şeritler yine karma değerden.
///
/// Sonuç DETERMİNİSTİK: "Anadolu SK" her zaman aynı armayı üretir.
/// Oyuncu bir süre sonra kulüpleri armalarından tanımaya başlar —
/// gerçek logolar geldiğinde bu sınıfı değiştirmek yeterli olacak.
class ClubCrest extends StatelessWidget {
  final String? clubName;
  final double size;

  const ClubCrest({super.key, required this.clubName, this.size = 130});

  @override
  Widget build(BuildContext context) {
    final ad = (clubName ?? '').trim();
    final tohum = _tohum(ad);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size * 1.12,
          child: CustomPaint(
            painter: _CrestPainter(
              tohum: tohum,
              basHarfler: _basHarfler(ad),
            ),
          ),
        ),
        SizedBox(height: size * 0.09),
        SizedBox(
          width: size * 1.9,
          child: Text(
            ad.isEmpty ? 'SERBEST OYUNCU' : ad.toUpperCase(),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              height: 1.25,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
            ),
          ),
        ),
      ],
    );
  }

  /// Ad -> sabit bir sayı. Aynı ad hep aynı armayı verir.
  static int _tohum(String ad) {
    if (ad.isEmpty) return 0;
    var h = 7;
    for (final kod in ad.codeUnits) {
      h = (h * 31 + kod) & 0x7FFFFFFF;
    }
    return h;
  }

  /// "Anadolu SK" -> "AS", "Milano Nero" -> "MN", "Ajax" -> "AJ"
  static String _basHarfler(String ad) {
    if (ad.isEmpty) return '?';

    final parcalar =
        ad.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (parcalar.length >= 2) {
      return (parcalar[0][0] + parcalar[1][0]).toUpperCase();
    }
    return parcalar[0]
        .substring(0, math.min(2, parcalar[0].length))
        .toUpperCase();
  }
}

class _CrestPainter extends CustomPainter {
  final int tohum;
  final String basHarfler;

  _CrestPainter({required this.tohum, required this.basHarfler});

  /// Armalarda gerçekten kullanılan, birbirine karışmayan renkler.
  /// Rastgele RGB üretseydik çamurlu ve birbirine benzeyen tonlar
  /// çıkardı; elle seçilmiş bir palet her zaman daha iyi görünür.
  static const _palet = [
    [Color(0xFF9B1B30), Color(0xFF3D0A12)], // bordo
    [Color(0xFF0B5FA5), Color(0xFF06294A)], // lacivert
    [Color(0xFF12694A), Color(0xFF06301F)], // yeşil
    [Color(0xFF6A2C91), Color(0xFF2C0F40)], // mor
    [Color(0xFFB4761A), Color(0xFF50310A)], // hardal
    [Color(0xFF1F2933), Color(0xFF0A0F14)], // antrasit
    [Color(0xFFB33A1F), Color(0xFF4A1508)], // kiremit
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final renkler = _palet[tohum % _palet.length];
    final seritTipi = (tohum ~/ 7) % 3;

    // ---- KALKAN BİÇİMİ ----
    final kalkan = _kalkanYolu(size);

    // Dış hat (metalik kenar)
    canvas.drawPath(
      kalkan,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.055
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3E3B8), Color(0xFF8C7233), Color(0xFFF3E3B8)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipPath(kalkan);

    // ---- ZEMİN ----
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: renkler,
        ).createShader(Offset.zero & size),
    );

    // ---- ŞERİTLER ----
    final seritBoya = Paint()..color = Colors.white.withValues(alpha: 0.16);

    switch (seritTipi) {
      case 0: // dikey çubuklar
        for (var i = 1; i < 5; i += 2) {
          canvas.drawRect(
            Rect.fromLTWH(size.width * i / 5, 0, size.width / 5, size.height),
            seritBoya,
          );
        }
      case 1: // çapraz bant
        final yol = Path()
          ..moveTo(0, size.height * 0.62)
          ..lineTo(size.width, size.height * 0.18)
          ..lineTo(size.width, size.height * 0.40)
          ..lineTo(0, size.height * 0.84)
          ..close();
        canvas.drawPath(yol, seritBoya);
      case 2: // yatay bant
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.44, size.width, size.height * 0.16),
          seritBoya,
        );
    }

    // ---- ÜST PARLAKLIK ----
    // Armaya "cilalı metal" hissi veren tek ayrıntı bu.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.restore();

    // ---- BAŞ HARFLER ----
    final metin = TextPainter(
      text: TextSpan(
        text: basHarfler,
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.40,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    metin.paint(
      canvas,
      Offset(
        (size.width - metin.width) / 2,
        size.height * 0.42 - metin.height / 2,
      ),
    );
  }

  /// Klasik kalkan silueti: üstü düz, altı sivri.
  Path _kalkanYolu(Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.10;

    return Path()
      ..moveTo(r, h * 0.03)
      ..lineTo(w - r, h * 0.03)
      ..quadraticBezierTo(w * 0.97, h * 0.03, w * 0.97, h * 0.16)
      ..lineTo(w * 0.97, h * 0.55)
      // Alt yanaklardan sivri uca
      ..cubicTo(w * 0.97, h * 0.80, w * 0.72, h * 0.94, w * 0.5, h * 0.99)
      ..cubicTo(w * 0.28, h * 0.94, w * 0.03, h * 0.80, w * 0.03, h * 0.55)
      ..lineTo(w * 0.03, h * 0.16)
      ..quadraticBezierTo(w * 0.03, h * 0.03, r, h * 0.03)
      ..close();
  }

  @override
  bool shouldRepaint(_CrestPainter eski) =>
      eski.tohum != tohum || eski.basHarfler != basHarfler;
}
