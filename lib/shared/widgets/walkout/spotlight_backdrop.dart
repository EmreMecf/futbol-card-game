import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WALKOUT SAHNESİNİN ZEMİNİ — kararan ekran ve stadyum spot ışıkları.
///
/// -------------------------------------------------------------------
/// PERFORMANS: NEDEN BLUR YOK?
/// -------------------------------------------------------------------
/// "Işık huzmesi" denince akla ilk `ImageFilter.blur` gelir. Ama blur
/// GPU'da ekranı okuyup tekrar yazan pahalı bir işlemdir; tam ekran
/// bir blur'u her karede çalıştırmak orta seviye telefonlarda 60 FPS'i
/// tek başına düşürür.
///
/// Bunun yerine YUMUŞAK DEGRADELER kullanıyoruz. Degrade, GPU'nun
/// doğal olarak yaptığı bir iştir ve pratikte bedavadır. Işık
/// huzmesinin kenarındaki yumuşaklık, kenara doğru saydamlaşan bir
/// `LinearGradient` ile elde ediliyor — göz farkı anlamıyor, kare
/// süresi anlıyor.
class SpotlightBackdrop extends StatelessWidget {
  /// Işıkların açılma ilerlemesi (0 = kapalı/karanlık, 1 = tam açık)
  final double progress;

  /// Işıkların yavaş salınımı için sürekli artan bir değer (0-1 döngü).
  /// Sahne durduğunda bile ışıkların canlı görünmesini sağlar.
  final double sway;

  /// Işık rengi — kartın seviyesinden gelir (Legend altın, Diamond mavi)
  final Color color;

  const SpotlightBackdrop({
    super.key,
    required this.progress,
    required this.sway,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: zemin kendi katmanında kalsın. Üstündeki kart
    // veya konfeti değiştiğinde bu painter tekrar çalışmasın.
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SpotlightPainter(
          progress: progress,
          sway: sway,
          color: color,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final double progress;
  final double sway;
  final Color color;

  _SpotlightPainter({
    required this.progress,
    required this.sway,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ---- 1) KARARAN EKRAN ----
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF04070F),
    );

    if (progress <= 0.01) return;

    // ---- 2) IŞIK HUZMELERİ ----
    // İki huzme, üst köşelerden sahnenin ortasına doğru iniyor.
    // Salınım, huzmelerin ucunu yatayda hafifçe gezdiriyor.
    final salinim = math.sin(sway * math.pi * 2) * w * 0.06;

    _huzme(
      canvas,
      tepe: Offset(w * 0.12, -h * 0.05),
      merkez: Offset(w * 0.46 + salinim, h * 0.62),
      genislik: w * 0.42,
      siddet: progress,
    );

    _huzme(
      canvas,
      tepe: Offset(w * 0.88, -h * 0.05),
      merkez: Offset(w * 0.54 - salinim, h * 0.62),
      genislik: w * 0.42,
      siddet: progress,
    );

    // ---- 3) SAHNE ZEMİNİNDEKİ IŞIK HAVUZU ----
    // Huzmelerin "yere vurduğu" yer. Sahneye derinlik veren asıl şey bu;
    // olmadığında huzmeler boşlukta asılı duruyormuş gibi görünüyor.
    final havuzMerkezi = Offset(w * 0.5, h * 0.52);
    final havuzYaricapi = w * 0.75;

    canvas.drawCircle(
      havuzMerkezi,
      havuzYaricapi,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.30 * progress),
            color.withValues(alpha: 0.10 * progress),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCircle(center: havuzMerkezi, radius: havuzYaricapi),
        ),
    );

    // ---- 4) KENAR KARARTMASI (vinyet) ----
    // Gözü ekranın ortasına kilitler. Işık ne kadar parlarsa vinyet de
    // o kadar güçleniyor; aksi halde parlaklık ekrana yayılıp
    // "spot ışığı" hissini kaybettiriyor.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55 * progress),
          ],
          stops: const [0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  /// Tek bir ışık huzmesi: tepeden aşağı açılan, kenarları saydamlaşan
  /// bir dörtgen.
  void _huzme(
    Canvas canvas, {
    required Offset tepe,
    required Offset merkez,
    required double genislik,
    required double siddet,
  }) {
    final yol = Path()
      ..moveTo(tepe.dx - 14, tepe.dy)
      ..lineTo(tepe.dx + 14, tepe.dy)
      ..lineTo(merkez.dx + genislik / 2, merkez.dy)
      ..lineTo(merkez.dx - genislik / 2, merkez.dy)
      ..close();

    canvas.drawPath(
      yol,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.34 * siddet),
            color.withValues(alpha: 0.10 * siddet),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(yol.getBounds()),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter eski) =>
      eski.progress != progress ||
      eski.sway != sway ||
      eski.color != color;
}
