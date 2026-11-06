import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// 2.5B ARENA — gece stadyumu, tribün, LED panolar ve perspektifli saha.
///
/// ===================================================================
/// TEKNİK KARAR (FAZ 1 raporu, MD bölüm 5)
/// ===================================================================
/// Gerçek 3B motor (Unity, flutter_scene) yerine Flutter'ın kendi
/// tuvali (CustomPainter) + elle yazılmış perspektif:
///   * Yeni bağımlılık yok, uygulama boyutu büyümüyor
///   * Arenamız bir simülasyon değil: sunucunun verdiği sonucu 2 saniyelik
///     senaryolu bir sahnede oynatıyor; oyun döngüsüne/fiziğe gerek yok
///   * 3B model dosyamız yok (kart görselleri bile henüz yok)
///
/// Bu, CSS perspektifinin eşdeğeri DEĞİL: saha çizgileri, oyuncular ve
/// top aynı [ArenaProjection] ile hesaplanıyor; uzaktaki oyuncu küçük ve
/// yukarıda, yakındaki büyük ve aşağıda çiziliyor.
///
/// GENİŞLETİLEBİLİRLİK: Gerçek 3B'ye geçilmek istenirse değişecek iki
/// sınıf [ArenaBackdrop] ve çatışma sahnesinin ressamı. Maç ekranı ve
/// ViewModel sadece "sahneyi oynat / bitti" diye konuşuyor.

// ====================================================================
// PERSPEKTİF
// ====================================================================
/// Saha koordinatlarını (u, v) ekran koordinatına çevirir.
///
///   u: 0 = sol çizgi, 1 = sağ çizgi
///   v: 0 = UZAK kale çizgisi (rakip tarafı), 1 = YAKIN kale çizgisi (benim)
///
/// Uzaklık doğrusal değil: v'nin üssü alınarak uzak taraf sıkıştırılıyor.
/// Gerçek bir kameranın gördüğü gibi; uzaktaki çim şeritleri dar, yakındakiler
/// geniş görünüyor.
class ArenaProjection {
  final Size size;

  const ArenaProjection(this.size);

  /// Sahanın uzak kenarının ekrandaki yüksekliği (tribünün hemen altı)
  double get topY => size.height * 0.30;

  /// Yakın kenar ekranın biraz dışında: kamera sahanın içinden bakıyor
  double get bottomY => size.height * 1.04;

  /// Uzak kenarın genişliği (ekran oranı)
  static const double _uzakGenislik = 0.56;

  /// Yakın kenarın genişliği (ekrandan taşar)
  static const double _yakinGenislik = 1.55;

  /// Derinlik eğrisi: 1'den büyük -> uzak taraf sıkışır
  static const double _derinlikUssu = 1.6;

  double _y(double v) =>
      topY + (bottomY - topY) * math.pow(v.clamp(0.0, 1.2), _derinlikUssu);

  /// v derinliğindeki sahanın ekran genişliği
  double widthAt(double v) {
    final t = (_y(v) - topY) / (bottomY - topY);
    return size.width * (_uzakGenislik + (_yakinGenislik - _uzakGenislik) * t);
  }

  Offset project(double u, double v) {
    final y = _y(v);
    final w = widthAt(v);
    final sol = (size.width - w) / 2;
    return Offset(sol + w * u, y);
  }

  /// Bu derinlikteki nesnenin ölçeği (yakın = büyük)
  double scaleAt(double v) => widthAt(v) / (size.width * _yakinGenislik);
}

// ====================================================================
// ZEMİN WIDGET'I
// ====================================================================
class ArenaBackdrop extends StatelessWidget {
  /// Saha ne kadar parlak çizilsin (0-1). Kartlar üstteyken biraz
  /// sönük tutmak okunurluğu artırıyor.
  final double intensity;

  const ArenaBackdrop({super.key, this.intensity = 0.75});

  @override
  Widget build(BuildContext context) {
    // Zemin STATİK: bir kez çizilip katmanında kalıyor. Üstteki kartlar,
    // sayaç ve el her saniye değişse bile bu ressam tekrar çalışmıyor.
    return RepaintBoundary(
      child: CustomPaint(
        painter: ArenaPainter(intensity: intensity),
        size: Size.infinite,
      ),
    );
  }
}

class ArenaPainter extends CustomPainter {
  final double intensity;

  ArenaPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final p = ArenaProjection(size);
    final alan = Offset.zero & size;

    // ---- 1) GECE GÖKYÜZÜ ----
    canvas.drawRect(
      alan,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF03060D), Color(0xFF0A1424), Color(0xFF06101C)],
          stops: [0, 0.28, 1],
        ).createShader(alan),
    );

    _tribun(canvas, size, p);
    _ledPano(canvas, size, p);
    _saha(canvas, size, p);
    _projektorler(canvas, size);

    // ---- VİNYET: göz ortadaki masaya kilitlensin ----
    canvas.drawRect(
      alan,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.15),
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
          stops: const [0.55, 1],
        ).createShader(alan),
    );
  }

  // ------------------------------------------------------------------
  // TRİBÜN: koyu basamaklar + seyirci noktaları
  // ------------------------------------------------------------------
  void _tribun(Canvas canvas, Size size, ArenaProjection p) {
    final ust = size.height * 0.07;
    final alt = p.topY - size.height * 0.02;

    final tribun = Path()
      ..moveTo(0, ust + size.height * 0.04)
      ..quadraticBezierTo(
        size.width / 2,
        ust - size.height * 0.03,
        size.width,
        ust + size.height * 0.04,
      )
      ..lineTo(size.width, alt)
      ..lineTo(0, alt)
      ..close();

    canvas.drawPath(
      tribun,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1A2C), Color(0xFF15233A)],
        ).createShader(tribun.getBounds()),
    );

    // Seyirciler: SABİT tohumlu rastgele noktalar. Her çizimde aynı
    // yerde durmalı; yoksa ekran her yeniden çizildiğinde kalabalık
    // "kaynar" gibi titrerdi.
    final r = math.Random(7);
    final nokta = Paint();
    const renkler = [
      Color(0xFF2B3A55),
      Color(0xFF334766),
      Color(0xFF3B2F4A),
      Color(0xFF1F5045),
    ];
    final adet = (size.width * 1.2).clamp(200, 900).toInt();
    for (var i = 0; i < adet; i++) {
      final x = r.nextDouble() * size.width;
      final yOran = r.nextDouble();
      final y =
          ust + size.height * 0.03 + (alt - ust - size.height * 0.03) * yOran;
      nokta.color = renkler[r.nextInt(renkler.length)].withValues(
        alpha: 0.55 + 0.45 * yOran,
      );
      canvas.drawCircle(Offset(x, y), 1.1 + 1.2 * yOran, nokta);
    }
  }

  // ------------------------------------------------------------------
  // LED PANOLAR: sahanın uzak kenarında parlayan şerit
  // ------------------------------------------------------------------
  void _ledPano(Canvas canvas, Size size, ArenaProjection p) {
    final sol = p.project(0, 0);
    final sag = p.project(1, 0);
    final yukseklik = size.height * 0.018;
    final pano = Rect.fromLTRB(
      sol.dx - size.width * 0.12,
      sol.dy - yukseklik - 2,
      sag.dx + size.width * 0.12,
      sol.dy - 2,
    );

    canvas.drawRect(
      pano,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.emerald.withValues(alpha: 0.85 * intensity),
            AppColors.cyan.withValues(alpha: 0.85 * intensity),
            AppColors.victoryGold.withValues(alpha: 0.85 * intensity),
            AppColors.emerald.withValues(alpha: 0.85 * intensity),
          ],
        ).createShader(pano),
    );
    // Panonun çime yansıyan ışığı
    canvas.drawRect(
      Rect.fromLTRB(
        pano.left,
        pano.bottom,
        pano.right,
        pano.bottom + size.height * 0.03,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.cyan.withValues(alpha: 0.18 * intensity),
            Colors.transparent,
          ],
        ).createShader(pano),
    );
  }

  // ------------------------------------------------------------------
  // SAHA: perspektifli çim şeritleri ve çizgiler
  // ------------------------------------------------------------------
  void _saha(Canvas canvas, Size size, ArenaProjection p) {
    Path dortgen(double v0, double v1) {
      final a = p.project(0, v0), b = p.project(1, v0);
      final c = p.project(1, v1), d = p.project(0, v1);
      return Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close();
    }

    // Çim şeritleri: eşit SAHA aralığında, perspektifte daralıyor
    const seritSayisi = 12;
    final koyu = Color.lerp(
      const Color(0xFF0B2A1E),
      const Color(0xFF14533A),
      intensity,
    )!;
    final acik = Color.lerp(
      const Color(0xFF0E3325),
      const Color(0xFF1A6346),
      intensity,
    )!;
    for (var i = 0; i < seritSayisi; i++) {
      canvas.drawPath(
        dortgen(i / seritSayisi, (i + 1) / seritSayisi),
        Paint()..color = i.isEven ? koyu : acik,
      );
    }

    // Uzak taraf sisli: derinlik hissi
    final sis = dortgen(0, 0.45);
    canvas.drawPath(
      sis,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A1424).withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ).createShader(sis.getBounds()),
    );

    // ---- Çizgiler ----
    final cizgi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.30 * intensity + 0.1);

    void hat(double u0, double v0, double u1, double v1) =>
        canvas.drawLine(p.project(u0, v0), p.project(u1, v1), cizgi);

    // Kenar çizgileri ve orta saha
    canvas.drawPath(dortgen(0, 1), cizgi);
    hat(0, 0.5, 1, 0.5);

    // Orta yuvarlak: perspektifte YATIK elips (noktaları tek tek
    // projekte et).
    //
    // Yarıçaplar gerçek ölçüden: 9,15 m yarıçap, saha 68 m eninde ->
    // u'da 0,135. Derinlik yarıçapı bilerek daha küçük: telefon dikey
    // tutulduğu için saha ekranda gerçek oranından çok daha UZUN
    // duruyor. Gerçek oranla çizildiğinde daire dik bir yumurtaya
    // dönüyordu; göz bunu "yukarıdan bakılan saha" olarak değil "bozuk
    // daire" olarak okuyordu.
    final daire = Path();
    for (var i = 0; i <= 48; i++) {
      final a = i / 48 * 2 * math.pi;
      final pt = p.project(
        0.5 + 0.135 * math.cos(a),
        0.5 + 0.045 * math.sin(a),
      );
      i == 0 ? daire.moveTo(pt.dx, pt.dy) : daire.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(daire, cizgi);
    canvas.drawCircle(p.project(0.5, 0.5), 2.5, Paint()..color = cizgi.color);

    // Ceza sahaları (uzak ve yakın)
    for (final (v0, v1) in [(0.0, 0.16), (1.0, 0.84)]) {
      hat(0.22, v0, 0.22, v1);
      hat(0.78, v0, 0.78, v1);
      hat(0.22, v1, 0.78, v1);
      // Kale sahası
      final kv = v0 + (v1 - v0) * 0.4;
      hat(0.38, v0, 0.38, kv);
      hat(0.62, v0, 0.62, kv);
      hat(0.38, kv, 0.62, kv);
    }

    // Uzak kale (yakın kale ekranın dışında kalıyor)
    final k1 = p.project(0.44, 0), k2 = p.project(0.56, 0);
    final kaleYuksekligi = size.height * 0.022;
    canvas.drawRect(
      Rect.fromLTRB(k1.dx, k1.dy - kaleYuksekligi, k2.dx, k1.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  // ------------------------------------------------------------------
  // PROJEKTÖRLER: köşelerde parlak lamba + yumuşak huzme
  // ------------------------------------------------------------------
  void _projektorler(Canvas canvas, Size size) {
    for (final x in [size.width * 0.08, size.width * 0.92]) {
      final lamba = Offset(x, size.height * 0.035);

      // Huzme: degrade (blur yok — bkz. SpotlightBackdrop performans notu)
      final hedef = Offset(size.width / 2, size.height * 0.6);
      final huzme = Path()
        ..moveTo(lamba.dx - 6, lamba.dy)
        ..lineTo(lamba.dx + 6, lamba.dy)
        ..lineTo(hedef.dx + size.width * 0.22, hedef.dy)
        ..lineTo(hedef.dx - size.width * 0.22, hedef.dy)
        ..close();
      canvas.drawPath(
        huzme,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.10 * intensity),
              Colors.transparent,
            ],
          ).createShader(huzme.getBounds()),
      );

      // Lamba parlaması
      canvas.drawCircle(
        lamba,
        size.width * 0.09,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  const Color(0xFFE6FBFF).withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(center: lamba, radius: size.width * 0.09),
              ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: lamba, width: size.width * 0.12, height: 4),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(ArenaPainter eski) => eski.intensity != intensity;
}
