import 'dart:math' as math;

import 'package:flutter/material.dart';

/// KONFETİ PATLAMASI
///
/// -------------------------------------------------------------------
/// MİMARİ KARAR: 1 WIDGET, 120 PARÇACIK
/// -------------------------------------------------------------------
/// Konfetiyi yazmanın kolay yolu her parçacığı ayrı bir `Positioned`
/// widget'ı yapmaktır. Bu yol 60 FPS'i öldürür: 120 widget demek her
/// karede 120 kez build + layout + paint demek. Flutter'ın layout'u
/// widget sayısıyla doğrusal büyür.
///
/// Burada TEK bir `CustomPainter` var. Parçacıklar sadece birer sayı
/// demeti; her karede yapılan iş 120 kez `canvas.drawRect`. Layout
/// aşaması hiç çalışmıyor. Aradaki fark orta seviye bir telefonda
/// takılan animasyon ile akıcı animasyon farkıdır.
///
/// -------------------------------------------------------------------
/// FİZİK: HER KARE HESAPLANMIYOR
/// -------------------------------------------------------------------
/// Parçacığın konumu bir önceki kareden türetilmiyor (birikimli hata
/// ve kare atlarsa bozulma olurdu). Bunun yerine kapalı formül:
///
///     konum = başlangıç + hız * t + 0.5 * yerçekimi * t²
///
/// `t` animasyonun ilerlemesi. Bu sayede animasyon ileri sarılabilir,
/// duraklatılabilir, kare atlanabilir — sonuç hep aynı kalır.
class ConfettiOverlay extends StatefulWidget {
  /// Patlama tetiklendi mi?
  final bool active;

  /// Parçacık renkleri (kartın seviye temasından gelir)
  final List<Color> colors;

  /// Parçacık sayısı. 120 üstü göze bir şey katmıyor, kare süresine
  /// katıyor.
  final int particleCount;

  const ConfettiOverlay({
    super.key,
    required this.active,
    required this.colors,
    this.particleCount = 120,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  /// DİKKAT — `late final ... = AnimationController(...)` YAZILMAMALI.
  ///
  /// `late` alanlar İLK ERİŞİMDE kurulur. Konfeti kapalıyken
  /// `initState` içinde controller'a hiç dokunulmuyor; ilk erişim
  /// `dispose()` içindeki `_kontrolcu.dispose()` satırı oluyordu.
  /// Yani controller (ve Ticker'ı) widget YOK EDİLİRKEN yaratılıyordu:
  ///
  ///   "Looking up a deactivated widget's ancestor is unsafe."
  ///   "An animation is still running even after the widget tree was
  ///    disposed."
  ///
  /// Ticker, TickerMode'u bulmak için ağaçta yukarı bakar; ağaç o anda
  /// dağılmış durumda olduğu için hem hata veriyor hem de asla
  /// durdurulamayan bir ticker geride kalıyordu.
  ///
  /// Çözüm: controller'ı initState içinde AÇIKÇA kur.
  late final AnimationController _kontrolcu;

  late final List<_Parcacik> _parcaciklar;

  @override
  void initState() {
    super.initState();

    _kontrolcu = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Parçacıklar BİR KEZ üretiliyor. Her karede rastgele sayı üretmek
    // hem pahalı hem de parçacıkların titremesine yol açardı.
    final rastgele = math.Random(42);
    _parcaciklar = List.generate(
      widget.particleCount,
      (i) => _Parcacik.uret(rastgele, widget.colors),
    );

    if (widget.active) _kontrolcu.forward();
  }

  @override
  void didUpdateWidget(ConfettiOverlay eski) {
    super.didUpdateWidget(eski);
    if (widget.active && !eski.active) {
      _kontrolcu.forward(from: 0);
    }
  }

  @override
  void dispose() {
    // Ticker'ı bırakmak ŞART. Bırakılmazsa animasyon bittikten sonra
    // bile her karede uyanan bir ticker kalır ve pilden yer.
    _kontrolcu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _kontrolcu,
          builder: (context, _) {
            // Animasyon bitince painter'ı tamamen kaldırıyoruz;
            // boş bir katmanı çizmeye devam etmenin anlamı yok.
            if (_kontrolcu.isCompleted) return const SizedBox.shrink();

            return CustomPaint(
              painter: _ConfettiPainter(
                parcaciklar: _parcaciklar,
                t: _kontrolcu.value,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

/// Tek bir konfeti parçası. Tüm alanlar `final`: animasyon boyunca
/// hiçbiri değişmiyor, sadece `t` ile okunuyorlar.
class _Parcacik {
  /// Başlangıç konumu (ekran oranı: 0-1)
  final double x0;
  final double y0;

  /// Hız (ekran oranı / saniye)
  final double vx;
  final double vy;

  final Color renk;

  /// Parçanın boyu (piksel)
  final double boy;
  final double en;

  /// Dönme hızı ve başlangıç açısı
  final double donusHizi;
  final double baslangicAcisi;

  /// Yuvarlak mı, dikdörtgen mi?
  final bool yuvarlak;

  const _Parcacik({
    required this.x0,
    required this.y0,
    required this.vx,
    required this.vy,
    required this.renk,
    required this.boy,
    required this.en,
    required this.donusHizi,
    required this.baslangicAcisi,
    required this.yuvarlak,
  });

  factory _Parcacik.uret(math.Random r, List<Color> renkler) {
    // Patlama kartın ALTINDAN yukarı doğru. Yukarıdan aşağı düşen
    // konfeti "kutlama" değil "yağmur" gibi duruyor; yukarı fışkırıp
    // sonra yerçekimiyle düşen konfeti patlama hissi veriyor.
    final aci = -math.pi / 2 + (r.nextDouble() - 0.5) * 1.7;
    final hiz = 0.75 + r.nextDouble() * 0.85;

    return _Parcacik(
      x0: 0.5 + (r.nextDouble() - 0.5) * 0.22,
      y0: 0.72 + (r.nextDouble() - 0.5) * 0.06,
      vx: math.cos(aci) * hiz,
      vy: math.sin(aci) * hiz,
      renk: renkler[r.nextInt(renkler.length)],
      boy: 7 + r.nextDouble() * 9,
      en: 3.5 + r.nextDouble() * 4,
      donusHizi: (r.nextDouble() - 0.5) * 14,
      baslangicAcisi: r.nextDouble() * math.pi * 2,
      yuvarlak: r.nextDouble() < 0.25,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Parcacik> parcaciklar;

  /// Animasyon ilerlemesi 0-1
  final double t;

  /// Yerçekimi (ekran oranı / saniye²)
  static const double _yercekimi = 1.55;

  _ConfettiPainter({required this.parcaciklar, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // Tek bir Paint nesnesi yeniden kullanılıyor. Her parçacık için
    // yeni Paint yaratmak 120 nesne/kare demek olurdu.
    final boya = Paint()..style = PaintingStyle.fill;

    // Sona doğru sönümleme: konfetiler birden kaybolmasın
    final genelSaydamlik = t > 0.75 ? (1 - (t - 0.75) / 0.25) : 1.0;

    for (final p in parcaciklar) {
      final x = (p.x0 + p.vx * t) * size.width;
      final y = (p.y0 + p.vy * t + 0.5 * _yercekimi * t * t) * size.height;

      // Ekrandan çıkanı çizme (drawRect ucuz ama bedava değil)
      if (y > size.height + 30 || x < -30 || x > size.width + 30) continue;

      boya.color = p.renk.withValues(alpha: genelSaydamlik);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.baslangicAcisi + p.donusHizi * t);

      if (p.yuvarlak) {
        canvas.drawCircle(Offset.zero, p.en * 0.7, boya);
      } else {
        // Dikey ölçekleme, kağıt parçasının dönerken inceldiği yanılsaması
        final incelme = math.cos(p.baslangicAcisi + p.donusHizi * t * 1.6);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.en,
            height: p.boy * incelme.abs().clamp(0.25, 1.0),
          ),
          boya,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter eski) => eski.t != t;
}
