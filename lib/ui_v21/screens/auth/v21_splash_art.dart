import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

import '../../ui_v21.dart';

/// V2.1 YÜKLEME EKRANI.
///
/// Önceden 380×679 piksellik tek bir resim tam ekrana gerilirdi; telefonda
/// yaklaşık 3 kat büyütüldüğü için çok bulanıktı. Artık sahne kodla
/// çizilir ve her ekranda keskindir:
///
///   * zemin: gece stadyumu (ışıklar, tribün, çimen) — vektör
///   * üstte "FUTBOL / CARD ARENA" logosu — yazı
///   * ortada yelpaze gibi açılmış 3 efsane kart — kart portreleri kendi
///     çözünürlüklerinde gösterilir
///   * altta oyunla ilgili bir İPUCU + yükleme çubuğu
///
/// Yalnız görüntü: süre ve yönlendirme `SplashView`'de. [progress] 0→1
/// çubuğu doldurur ve kartları açar; kart animasyonları kapalıysa çağıran
/// 1 verir. [tip] gösterilecek ipucunun sırası ([tips]).
class V21SplashArt extends StatelessWidget {
  final double progress;
  final int tip;
  const V21SplashArt({super.key, required this.progress, this.tip = 0});

  /// Yerel açılış ekranıyla aynı zemin rengi (beyaz parlama olmasın)
  static const Color zemin = Color(0xFF0F1130);

  /// Yükleme ekranındaki oyun ipuçları (her açılışta biri gösterilir)
  static const List<String> tips = [
    'Efsane kartlar, gücü ne olursa olsun alttaki dört nadirliği yener.',
    'Kadron 4-4-2 dizilir: 1 kaleci, 4 defans, 4 orta saha ve 2 forvet.',
    'Aynı futbolcunun kopyalarını Gelişim\'de kullanarak seviye atlat.',
    'Sandıkların süresini başlat; anahtarla beklemeden açabilirsin.',
    'Alt menüde sağa-sola kaydırarak sayfalar arasında hızla geç.',
    'Her gün ilk galibiyetin ve günlük sandık ekstra ödül getirir.',
    'Maç sonunda kartlar el değiştirir; en değerli kartlarını koru.',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final ipucu = tips[tip % tips.length];
    return Semantics(
      label: 'Futbol Card Arena yükleniyor. İpucu: $ipucu',
      excludeSemantics: true,
      child: ColoredBox(
        color: zemin,
        child: LayoutBuilder(
          builder: (context, box) {
            final k = V21Scale.forSize(box.biggest).s;
            // Kart yelpazesi ekrana göre: telefonda genişliğin ~%36'sı
            final kartW = math.min(box.maxWidth * 0.36, box.maxHeight * 0.2).clamp(96.0, 220.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _StadiumPainter()),
                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: box.maxHeight * 0.05),
                      V21Logo(scale: k * 0.95),
                      const Spacer(),
                      _CardFan(width: kartW, open: t),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22 * k),
                        child: _TipPanel(text: ipucu, scale: k),
                      ),
                      SizedBox(height: 16 * k),
                      _LoadingBar(value: t, scale: k),
                      SizedBox(height: 18 * k),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Yelpaze gibi açılan 3 efsane kart (adları kurgusal, portreler kartlardaki
/// 550 karakterden; maskot Efsane Kaptan değildir)
class _CardFan extends StatelessWidget {
  final double width;
  final double open;
  const _CardFan({required this.width, required this.open});

  static const _kartlar = [
    ('Taren Volsk', CardPosition.goalkeeper, CardTier.diamond, 95),
    ('Nerio Valtan', CardPosition.midfielder, CardTier.legend, 99),
    ('Aren Solmar', CardPosition.forward, CardTier.gold, 98),
  ];

  @override
  Widget build(BuildContext context) {
    final h = width * 1.42;
    Widget kart(int i, double aci, double dx) {
      final (ad, mevki, seviye, guc) = _kartlar[i];
      return Transform.translate(
        offset: Offset(dx * open, (1 - open) * 18 + (i == 1 ? -10 : 6)),
        child: Transform.rotate(
          angle: aci * open,
          child: V21PlayerCard(name: ad, position: mevki, tier: seviye, power: guc, width: width),
        ),
      );
    }

    return SizedBox(
      height: h + 30,
      width: width * 2.6,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Kartların arkasında ışık halesi
          Container(
            width: width * 2.2,
            height: width * 2.2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x66FFD86B), Color(0x00FFD86B)]),
            ),
          ),
          kart(0, -0.22, -width * 0.62),
          kart(2, 0.22, width * 0.62),
          kart(1, 0, 0),
        ],
      ),
    );
  }
}

class _TipPanel extends StatelessWidget {
  final String text;
  final double scale;
  const _TipPanel({required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        key: const Key('yukleme-ipucu'),
        padding: EdgeInsets.fromLTRB(14 * k, 10 * k, 14 * k, 11 * k),
        decoration: BoxDecoration(
          color: const Color(0xCC1E1150),
          borderRadius: BorderRadius.circular(16 * k),
          border: Border.all(color: V21Colors.goldEdge.withValues(alpha: 0.75), width: 2 * k),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 34 * k,
              height: 34 * k,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: V21Colors.goldTop,
                border: Border.all(color: V21Colors.ink, width: 2.5 * k),
              ),
              child: Icon(Icons.lightbulb_rounded, size: 20 * k, color: V21Colors.ink),
            ),
            SizedBox(width: 10 * k),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('İPUCU', style: V21Type.title(12 * k, color: V21Colors.goldTop, letterSpacing: 1.2)),
                  SizedBox(height: 2 * k),
                  Text(
                    text,
                    style: V21Type.label(13 * k, weight: FontWeight.w700, color: Colors.white, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  final double value;
  final double scale;
  const _LoadingBar({required this.value, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return SizedBox(
      width: 240 * k,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('YÜKLENİYOR', style: V21Type.title(15 * k, letterSpacing: 1.4, shadows: V21Type.inkShadow(k))),
          SizedBox(height: 6 * k),
          Container(
            height: 12 * k,
            padding: EdgeInsets.all(2 * k),
            decoration: BoxDecoration(
              color: V21Colors.trackDark,
              borderRadius: BorderRadius.circular(7 * k),
              border: Border.all(color: V21Colors.goldEdge.withValues(alpha: 0.8)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                key: const Key('yukleme-cubugu'),
                widthFactor: value,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [V21Colors.goldBottom, V21Colors.goldTop]),
                    borderRadius: BorderRadius.circular(5 * k),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gece stadyumu: mor gökyüzü, iki projektör ve ışık hüzmeleri, tribün
/// ışıkları, çizgili çimen ve orta saha çizgileri. Tamamen vektör.
class _StadiumPainter extends CustomPainter {
  const _StadiumPainter();

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final ufuk = h * 0.6;

    // Gökyüzü
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0F4A), Color(0xFF3B1E8C), Color(0xFF5B2FB0)],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, ufuk)),
    );

    // Projektör hüzmeleri
    for (final x in [w * 0.12, w * 0.88]) {
      final kaynak = Offset(x, h * 0.16);
      final huzme = Path()
        ..moveTo(kaynak.dx, kaynak.dy)
        ..lineTo(w * 0.5 - (x < w / 2 ? w * 0.05 : -w * 0.05) - w * 0.22, ufuk)
        ..lineTo(w * 0.5 - (x < w / 2 ? w * 0.05 : -w * 0.05) + w * 0.22, ufuk)
        ..close();
      c.drawPath(
        huzme,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
          ).createShader(Rect.fromLTRB(0, kaynak.dy, w, ufuk)),
      );
      // Direk ve ışık paneli
      c.drawLine(Offset(x, h * 0.16), Offset(x, ufuk), Paint()
        ..color = const Color(0xFF2A1A66)
        ..strokeWidth = w * 0.012);
      final panel = RRect.fromRectAndRadius(
        Rect.fromCenter(center: kaynak, width: w * 0.16, height: w * 0.1),
        Radius.circular(w * 0.015),
      );
      c.drawCircle(kaynak, w * 0.16, Paint()
        ..shader = const RadialGradient(colors: [Color(0x88CFE8FF), Color(0x00CFE8FF)])
            .createShader(Rect.fromCircle(center: kaynak, radius: w * 0.16)));
      c.drawRRect(panel, Paint()..color = const Color(0xFF241552));
      final r = w * 0.012;
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 3; j++) {
          c.drawCircle(
            Offset(panel.left + panel.width * (0.17 + i * 0.22), panel.top + panel.height * (0.22 + j * 0.28)),
            r,
            Paint()..color = const Color(0xFFF2F8FF),
          );
        }
      }
    }

    // Tribün (koyu şerit + renkli seyirci ışıkları)
    final tribun = Rect.fromLTRB(0, ufuk - h * 0.09, w, ufuk);
    c.drawRect(tribun, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2B1866), Color(0xFF1B0F45)],
      ).createShader(tribun));
    final rnd = math.Random(7);
    const renkler = [Color(0xFFFFC832), Color(0xFF5FD8FF), Color(0xFFFF5A7A), Color(0xFFFFFFFF), Color(0xFFC77DFF)];
    for (var i = 0; i < 140; i++) {
      c.drawCircle(
        Offset(rnd.nextDouble() * w, tribun.top + rnd.nextDouble() * tribun.height * 0.9),
        0.8 + rnd.nextDouble() * 1.4,
        Paint()..color = renkler[i % renkler.length].withValues(alpha: 0.35 + rnd.nextDouble() * 0.5),
      );
    }
    // Reklam panosu çizgisi
    c.drawRect(Rect.fromLTRB(0, ufuk - 4, w, ufuk), Paint()..color = const Color(0xFF7A4BFF));

    // Çimen
    final cim = Rect.fromLTRB(0, ufuk, w, h);
    c.drawRect(cim, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2E9E3E), Color(0xFF15602A), Color(0xFF0D2E1F)],
        stops: [0, 0.6, 1],
      ).createShader(cim));
    // Biçilmiş şeritler (perspektifli)
    final serit = Paint()..color = const Color(0x14FFFFFF);
    for (var i = 0; i < 7; i++) {
      if (i.isOdd) continue;
      final y0 = ufuk + (h - ufuk) * math.pow(i / 7, 1.4);
      final y1 = ufuk + (h - ufuk) * math.pow((i + 1) / 7, 1.4);
      c.drawRect(Rect.fromLTRB(0, y0, w, y1), serit);
    }
    // Orta saha çizgisi ve yuvarlağı
    final cizgi = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 2;
    final merkez = Offset(w / 2, ufuk + (h - ufuk) * 0.42);
    c.drawOval(Rect.fromCenter(center: merkez, width: w * 0.62, height: (h - ufuk) * 0.34), cizgi);
    c.drawLine(Offset(0, merkez.dy), Offset(w, merkez.dy), cizgi);

    // Kenarlarda karartma (odak ortada)
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.0,
          colors: [Color(0x00000000), Color(0x88070320)],
          stops: [0.55, 1],
        ).createShader(Offset.zero & s),
    );
  }

  @override
  bool shouldRepaint(_StadiumPainter oldDelegate) => false;
}

/// "FUTBOL / CARD ARENA" logosu (referans giriş ekranı: beyaz + altın,
/// kalın mürekkep gölgesi). Giriş ekranı da kullanabilir.
class V21Logo extends StatelessWidget {
  final double scale;
  const V21Logo({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('FUTBOL', style: V21Type.title(58 * k, height: 1, shadows: V21Type.inkShadow(k * 1.4))),
          V21HeroTitle('CARD ARENA', size: 46 * k),
        ],
      ),
    );
  }
}
