import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';

/// V2.1 VEKTÖR ÖDÜL GÖRSELLERİ: sandık ve eşyalar.
///
/// Eski sandık PNG'si 68×53 pikseldi; telefonda 3 kat büyütülünce
/// pikselleniyordu. Bu çizimler kodla çizilir: her boyutta ve her ekran
/// yoğunluğunda keskindir, nadirlik rengine göre ayrışır.
///
/// Stil oyunun geri kalanıyla aynı: kalın mürekkep (koyu mor) kontur,
/// parlak üst ışık, metalde açık→koyu geçiş, ahşapta sıcak kahve.

/// Nadirlik metal paleti: (parlak, ana, koyu, mücevher)
class V21TierPalette {
  final Color light;
  final Color base;
  final Color dark;
  final Color gem;
  const V21TierPalette(this.light, this.base, this.dark, this.gem);

  static const bronze = V21TierPalette(Color(0xFFFFD6B0), Color(0xFFD98A4E), Color(0xFF7E3F17), Color(0xFF3DD15A));
  static const silver = V21TierPalette(Color(0xFFFFFFFF), Color(0xFFC6D3E0), Color(0xFF5E6F88), Color(0xFF5FD8FF));
  static const gold = V21TierPalette(Color(0xFFFFF4A8), Color(0xFFFFC832), Color(0xFFB0690C), Color(0xFF3F8CFF));
  static const diamond = V21TierPalette(Color(0xFFE8FFFF), Color(0xFF5FD8FF), Color(0xFF16709E), Color(0xFFFFFFFF));
  static const legend = V21TierPalette(Color(0xFFF7DDFF), Color(0xFFC77DFF), Color(0xFF5E2299), Color(0xFFFFD23F));

  /// 'bronze' | 'silver' | 'gold' | 'diamond' | 'legend' (bilinmeyen → altın)
  static V21TierPalette of(String? tier) => switch (tier) {
    'bronze' => bronze,
    'silver' => silver,
    'diamond' => diamond,
    'legend' => legend,
    _ => gold,
  };

  /// Sandık/nadirlik vurgu renginden palet
  static V21TierPalette ofAccent(Color accent) => switch (accent) {
    V21Colors.rarityBronze => bronze,
    V21Colors.raritySilver => silver,
    V21Colors.rarityDiamond => diamond,
    V21Colors.rarityLegend => legend,
    _ => gold,
  };
}

/// Eşya slug'ındaki nadirlik ("joker_bronze" → "bronze"), yoksa null
String? v21ItemTier(String slug) {
  for (final t in const ['bronze', 'silver', 'gold', 'diamond', 'legend']) {
    if (slug.endsWith('_$t')) return t;
  }
  return null;
}

// =====================================================================
// SANDIK
// =====================================================================

/// Vektör sandık. En/boy oranı sabit (1 : 0.82); [width] ya da [height]
/// verilmezse kapsayıcıya sığar.
class V21ChestArt extends StatelessWidget {
  final V21TierPalette palette;
  final double? width;
  final double? height;

  /// Kapak hafif aralık ve içeriden ışık sızar (açılmaya hazır)
  final bool glowing;

  const V21ChestArt({super.key, this.palette = V21TierPalette.gold, this.width, this.height, this.glowing = false});

  V21ChestArt.tier(String? tier, {Key? key, double? width, double? height, bool glowing = false})
    : this(key: key, palette: V21TierPalette.of(tier), width: width, height: height, glowing: glowing);

  V21ChestArt.accent(Color accent, {Key? key, double? width, double? height, bool glowing = false})
    : this(key: key, palette: V21TierPalette.ofAccent(accent), width: width, height: height, glowing: glowing);

  static const double aspect = 1 / 0.82;

  @override
  Widget build(BuildContext context) {
    Widget art = AspectRatio(
      aspectRatio: aspect,
      child: CustomPaint(painter: _ChestPainter(palette, glowing)),
    );
    if (width != null || height != null) {
      art = SizedBox(
        width: width ?? height! * aspect,
        height: height ?? width! / aspect,
        child: art,
      );
    } else {
      art = FittedBox(fit: BoxFit.contain, child: SizedBox(width: 100, height: 100 / aspect, child: art));
    }
    return ExcludeSemantics(child: art);
  }
}

class _ChestPainter extends CustomPainter {
  final V21TierPalette p;
  final bool glowing;
  _ChestPainter(this.p, this.glowing);

  static const _ink = V21Colors.ink;
  static const _woodLight = Color(0xFFB9743A);
  static const _wood = Color(0xFF8C4E22);
  static const _woodDark = Color(0xFF552A0E);

  @override
  void paint(Canvas c, Size s) {
    // 100 × 82 birimlik tasarım alanı
    final u = s.width / 100;
    c.save();
    c.scale(u);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = _ink
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    Paint metal(Rect r, {bool vertical = false}) => Paint()
      ..shader = LinearGradient(
        begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
        end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
        colors: [p.light, p.base, p.dark],
        stops: const [0, 0.45, 1],
      ).createShader(r);

    // Gölge
    c.drawOval(const Rect.fromLTWH(10, 72, 80, 9), Paint()..color = const Color(0x55000000));

    // Hazır sandıkta arkadan ışık
    if (glowing) {
      c.drawCircle(
        const Offset(50, 36),
        44,
        Paint()
          ..shader = RadialGradient(
            colors: [p.light.withValues(alpha: 0.75), p.base.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: const Offset(50, 36), radius: 44)),
      );
    }

    // ---- GÖVDE ----
    const body = Rect.fromLTRB(9, 37, 91, 76);
    final bodyR = RRect.fromRectAndCorners(
      body,
      bottomLeft: const Radius.circular(7),
      bottomRight: const Radius.circular(7),
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
    );
    c.drawRRect(
      bodyR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_wood, _woodDark],
        ).createShader(body),
    );
    // Tahta aralıkları
    final plank = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 1.4;
    c.drawLine(const Offset(10, 50), const Offset(90, 50), plank);
    c.drawLine(const Offset(10, 63), const Offset(90, 63), plank);
    c.drawRRect(bodyR, stroke);

    // ---- KAPAK ----
    final lid = Path()
      ..moveTo(7, 39)
      ..lineTo(7, 24)
      ..cubicTo(7, 4, 93, 4, 93, 24)
      ..lineTo(93, 39)
      ..close();
    const lidRect = Rect.fromLTRB(7, 6, 93, 39);
    c.drawPath(
      lid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_woodLight, _wood],
        ).createShader(lidRect),
    );
    final lidPlank = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    c.drawPath(Path()
      ..moveTo(8, 26)
      ..cubicTo(14, 13, 86, 13, 92, 26), lidPlank);
    // Kapak parlaklığı
    c.drawPath(
      Path()
        ..moveTo(14, 20)
        ..cubicTo(22, 9, 60, 7, 74, 10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4
        ..color = const Color(0x55FFFFFF),
    );
    c.drawPath(lid, stroke);

    // ---- METAL KUŞAKLAR ----
    void band(double x) {
      final top = Path()
        ..moveTo(x, 39)
        ..lineTo(x, 12.5)
        ..lineTo(x + 9, 9.5)
        ..lineTo(x + 9, 39)
        ..close();
      final r = Rect.fromLTRB(x, 9, x + 9, 76);
      c.drawPath(top, metal(r, vertical: true));
      c.drawPath(top, stroke);
      final low = RRect.fromRectAndRadius(Rect.fromLTRB(x, 39, x + 9, 76), const Radius.circular(1.5));
      c.drawRRect(low, metal(r, vertical: true));
      c.drawRRect(low, stroke);
      for (final y in [17.0, 31.0, 47.0, 68.0]) {
        c.drawCircle(Offset(x + 4.5, y), 1.6, Paint()..color = p.dark);
        c.drawCircle(Offset(x + 4.1, y - 0.5), 0.7, Paint()..color = p.light);
      }
    }

    band(15);
    band(76);

    // Kapak ağzı (yatay kuşak)
    final rim = RRect.fromRectAndRadius(const Rect.fromLTRB(5, 34, 95, 42.5), const Radius.circular(3));
    c.drawRRect(rim, metal(rim.outerRect));
    c.drawRRect(rim, stroke);
    if (glowing) {
      c.drawRect(const Rect.fromLTRB(28, 40.5, 72, 42), Paint()..color = p.light);
    }

    // Alt kenar
    final foot = RRect.fromRectAndRadius(const Rect.fromLTRB(7, 70, 93, 77), const Radius.circular(3));
    c.drawRRect(foot, metal(foot.outerRect));
    c.drawRRect(foot, stroke);

    // ---- KİLİT + MÜCEVHER ----
    final lock = RRect.fromRectAndRadius(const Rect.fromLTRB(38, 28, 62, 55), const Radius.circular(5));
    c.drawRRect(lock, metal(lock.outerRect));
    c.drawRRect(lock, stroke);
    final gem = Path()
      ..moveTo(50, 32)
      ..lineTo(57, 39.5)
      ..lineTo(50, 49)
      ..lineTo(43, 39.5)
      ..close();
    c.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(p.gem, Colors.white, 0.6)!, p.gem, Color.lerp(p.gem, Colors.black, 0.35)!],
        ).createShader(const Rect.fromLTRB(43, 32, 57, 49)),
    );
    c.drawPath(
      Path()
        ..moveTo(43, 39.5)
        ..lineTo(57, 39.5),
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1,
    );
    c.drawPath(gem, stroke..strokeWidth = 2.2);
    c.drawCircle(const Offset(47.5, 36.5), 1.3, Paint()..color = Colors.white);

    c.restore();
  }

  @override
  bool shouldRepaint(_ChestPainter old) => old.p != p || old.glowing != glowing;
}

// =====================================================================
// EŞYALAR
// =====================================================================

/// Vektör eşya görseli: nadirlik renginde rozet + kategoriye özel çizim.
///
/// Joker parça → yüzeyli kristal parça, Ustalık kitabı → kitap,
/// Sandık anahtarı → anahtar, Enerji içeceği → kutu, İndirim → etiket.
/// Diğer kategoriler oyun ikonuyla aynı rozet üzerinde gösterilir.
class V21ItemArt extends StatelessWidget {
  final String category;

  /// 'bronze'..'legend'; null ise kategori rengi kullanılır
  final String? tier;
  final double size;

  /// Çizimi olmayan kategoriler için yedek ikon ve renk
  final IconData fallbackIcon;
  final Color fallbackColor;

  const V21ItemArt({
    super.key,
    required this.category,
    this.tier,
    required this.size,
    this.fallbackIcon = Icons.inventory_2_rounded,
    this.fallbackColor = const Color(0xFF8E7FBE),
  });

  bool get _drawn => const {'joker', 'mastery_book', 'chest_key', 'energy_drink', 'level_discount'}.contains(category);

  V21TierPalette get _palette {
    if (tier != null) return V21TierPalette.of(tier);
    return switch (category) {
      'chest_key' => V21TierPalette.gold,
      'energy_drink' => const V21TierPalette(Color(0xFFFFE0A8), Color(0xFFFF9500), Color(0xFFA34B00), Colors.white),
      'level_discount' => const V21TierPalette(Color(0xFFFFC2CA), Color(0xFFFF5A6E), Color(0xFF9E1B30), Colors.white),
      _ => V21TierPalette(
        Color.lerp(fallbackColor, Colors.white, 0.55)!,
        fallbackColor,
        Color.lerp(fallbackColor, Colors.black, 0.45)!,
        Colors.white,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final pal = _palette;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _BadgePainter(pal)),
            if (_drawn)
              CustomPaint(painter: _EmblemPainter(category, pal))
            else
              Center(
                child: Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(0, size * 0.025),
                      child: Icon(fallbackIcon, size: size * 0.52, color: V21Colors.ink),
                    ),
                    Icon(fallbackIcon, size: size * 0.52, color: Colors.white),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rozet zemini: yuvarlatılmış kare, nadirlik renginde parlak geçiş,
/// kalın mürekkep kontur, iç kenar ışığı, köşede parıltı.
class _BadgePainter extends CustomPainter {
  final V21TierPalette p;
  _BadgePainter(this.p);

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 100;
    c.save();
    c.scale(u);
    const r = Rect.fromLTWH(4, 4, 92, 92);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(22));
    c.drawRRect(rr.shift(const Offset(0, 3)), Paint()..color = const Color(0x66000000));
    c.drawRRect(
      rr,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.45),
          radius: 1.05,
          colors: [p.light, p.base, p.dark],
          stops: const [0, 0.5, 1],
        ).createShader(r),
    );
    // Işın deseni (hafif)
    final ray = Paint()..color = const Color(0x14FFFFFF);
    c.save();
    c.clipRRect(rr);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawPath(
        Path()
          ..moveTo(50, 50)
          ..lineTo(50 + 90 * math.cos(a - 0.12), 50 + 90 * math.sin(a - 0.12))
          ..lineTo(50 + 90 * math.cos(a + 0.12), 50 + 90 * math.sin(a + 0.12))
          ..close(),
        ray,
      );
    }
    c.restore();
    c.drawRRect(
      rr.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x40FFFFFF),
    );
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = V21Colors.ink,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.p != p;
}

class _EmblemPainter extends CustomPainter {
  final String category;
  final V21TierPalette p;
  _EmblemPainter(this.category, this.p);

  static const _ink = V21Colors.ink;

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.4
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _ink;

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 100;
    c.save();
    c.scale(u);
    switch (category) {
      case 'joker':
        _joker(c);
      case 'mastery_book':
        _book(c);
      case 'chest_key':
        _key(c);
      case 'energy_drink':
        _can(c);
      case 'level_discount':
        _tag(c);
    }
    c.restore();
  }

  /// JOKER PARÇA: yüzeyli kristal parça + yıldız damgası + parıltı
  void _joker(Canvas c) {
    // Kristal her nadirlikte beyaza yakın parlar; renk yüzeylerden gelir
    final outer = Path()
      ..moveTo(50, 13)
      ..lineTo(77, 33)
      ..lineTo(70, 78)
      ..lineTo(50, 88)
      ..lineTo(30, 78)
      ..lineTo(23, 33)
      ..close();
    c.drawPath(outer.shift(const Offset(0, 3)), Paint()..color = const Color(0x55000000));
    final faces = <(List<Offset>, Color)>[
      ([const Offset(50, 13), const Offset(77, 33), const Offset(50, 40)], Color.lerp(p.light, Colors.white, 0.4)!),
      ([const Offset(50, 13), const Offset(50, 40), const Offset(23, 33)], p.light),
      ([const Offset(23, 33), const Offset(50, 40), const Offset(30, 78)], p.base),
      ([const Offset(77, 33), const Offset(70, 78), const Offset(50, 40)], Color.lerp(p.base, p.dark, 0.45)!),
      ([const Offset(50, 40), const Offset(70, 78), const Offset(50, 88)], p.dark),
      ([const Offset(50, 40), const Offset(50, 88), const Offset(30, 78)], Color.lerp(p.base, p.dark, 0.2)!),
    ];
    for (final (pts, col) in faces) {
      c.drawPath(Path()..addPolygon(pts, true), Paint()..color = col);
    }
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x55FFFFFF);
    for (final e in const [Offset(50, 13), Offset(77, 33), Offset(23, 33), Offset(30, 78), Offset(70, 78), Offset(50, 88)]) {
      c.drawLine(const Offset(50, 40), e, facet);
    }
    c.drawPath(outer, _stroke);

    // Yıldız damgası (joker = her futbolcunun yerine geçer)
    final star = _starPath(const Offset(50, 54), 11, 4.8);
    c.drawPath(star, Paint()..color = Colors.white);
    c.drawPath(star, _stroke..strokeWidth = 2.4);

    // Parıltılar
    _sparkle(c, const Offset(31, 22), 6);
    _sparkle(c, const Offset(78, 64), 4.5);
  }

  /// USTALIK KİTABI: nadirlik renginde kapak, sayfalar, yıldızlı amblem
  void _book(Canvas c) {
    final cover = RRect.fromRectAndRadius(const Rect.fromLTRB(22, 16, 76, 84), const Radius.circular(6));
    c.drawRRect(cover.shift(const Offset(0, 3)), Paint()..color = const Color(0x55000000));
    // Sayfalar (sağda görünen beyaz blok)
    final pages = RRect.fromRectAndRadius(const Rect.fromLTRB(30, 20, 80, 82), const Radius.circular(4));
    c.drawRRect(pages, Paint()..color = const Color(0xFFFFF8E6));
    for (final y in [30.0, 40.0, 50.0, 60.0, 70.0]) {
      c.drawLine(Offset(70, y), Offset(78, y), Paint()
        ..color = const Color(0x33000000)
        ..strokeWidth = 1);
    }
    c.drawRRect(pages, _stroke);
    c.drawRRect(
      cover,
      Paint()
        ..shader = LinearGradient(colors: [p.light, p.base, p.dark], stops: const [0, 0.4, 1])
            .createShader(cover.outerRect),
    );
    // Sırt
    c.drawRect(const Rect.fromLTRB(22, 16, 30, 84), Paint()..color = const Color(0x33000000));
    c.drawRRect(cover, _stroke);
    final star = _starPath(const Offset(51, 46), 13, 5.6);
    c.drawPath(star, Paint()..color = Colors.white);
    c.drawPath(star, _stroke..strokeWidth = 2.4);
    c.drawLine(const Offset(36, 68), const Offset(66, 68), _stroke..strokeWidth = 2.6);
    _sparkle(c, const Offset(78, 18), 5);
  }

  /// SANDIK ANAHTARI
  void _key(Canvas c) {
    final metal = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.light, p.base, p.dark],
      ).createShader(const Rect.fromLTRB(16, 16, 84, 84));
    final key = Path()
      ..addOval(Rect.fromCircle(center: const Offset(36, 36), radius: 17))
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(44, 44, 84, 54), const Radius.circular(3)))
      ..addRect(const Rect.fromLTRB(64, 54, 71, 66))
      ..addRect(const Rect.fromLTRB(75, 54, 82, 70));
    c.save();
    c.translate(50, 50);
    c.rotate(math.pi / 4.6);
    c.translate(-50, -50);
    c.drawPath(key.shift(const Offset(0, 3)), Paint()..color = const Color(0x55000000));
    c.drawPath(key, metal);
    c.drawPath(key, _stroke);
    c.drawCircle(const Offset(36, 36), 7, Paint()..color = _ink);
    c.drawCircle(const Offset(36, 36), 4.6, Paint()..color = const Color(0xFF3F8CFF));
    c.restore();
    _sparkle(c, const Offset(74, 24), 6);
  }

  /// ENERJİ İÇECEĞİ: kutu + şimşek
  void _can(Canvas c) {
    final can = RRect.fromRectAndRadius(const Rect.fromLTRB(32, 14, 68, 86), const Radius.circular(8));
    c.drawRRect(can.shift(const Offset(0, 3)), Paint()..color = const Color(0x55000000));
    c.drawRRect(
      can,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF6B7CFF), Color(0xFF3A2BB8), Color(0xFF1E1470)],
          stops: [0, 0.5, 1],
        ).createShader(can.outerRect),
    );
    c.drawRect(const Rect.fromLTRB(33, 22, 67, 25), Paint()..color = const Color(0x66FFFFFF));
    c.drawRect(const Rect.fromLTRB(33, 75, 67, 78), Paint()..color = const Color(0x44000000));
    c.drawRRect(can, _stroke);
    final bolt = Path()
      ..moveTo(54, 30)
      ..lineTo(40, 53)
      ..lineTo(50, 53)
      ..lineTo(45, 72)
      ..lineTo(61, 46)
      ..lineTo(51, 46)
      ..close();
    c.drawPath(bolt, Paint()..color = p.light);
    c.drawPath(bolt, _stroke..strokeWidth = 2.4);
    _sparkle(c, const Offset(76, 22), 5);
  }

  /// GELİŞİM İNDİRİMİ: etiket + yüzde
  void _tag(Canvas c) {
    final tag = Path()
      ..moveTo(20, 30)
      ..lineTo(56, 18)
      ..lineTo(84, 46)
      ..lineTo(52, 84)
      ..lineTo(18, 62)
      ..close();
    c.drawPath(tag.shift(const Offset(0, 3)), Paint()..color = const Color(0x55000000));
    c.drawPath(tag, Paint()..color = const Color(0xFFFFF8E6));
    c.drawPath(tag, _stroke);
    c.drawCircle(const Offset(32, 34), 5, Paint()..color = p.base);
    c.drawCircle(const Offset(32, 34), 5, _stroke..strokeWidth = 2.2);
    final tp = TextPainter(
      text: TextSpan(
        text: '%',
        style: V21Type.title(36, color: p.dark, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(52 - tp.width / 2, 54 - tp.height / 2));
  }

  Path _starPath(Offset o, double r, double ri) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : ri;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(o.dx + rad * math.cos(a), o.dy + rad * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  void _sparkle(Canvas c, Offset o, double r) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.category != category || old.p != p;
}

// =====================================================================
// ELMAS (nadir para birimi simgesi)
// =====================================================================

/// Elmas simgesi: yüzeyli yeşil-camgöbeği mücevher, mürekkep konturlu.
/// Altın simgesinin ([V21CoinIcon]) elmas karşılığı.
class V21GemIcon extends StatelessWidget {
  final double size;
  const V21GemIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: SizedBox.square(dimension: size, child: const CustomPaint(painter: _GemPainter())));
}

class _GemPainter extends CustomPainter {
  const _GemPainter();

  static const _light = Color(0xFFD6FFF1);
  static const _base = Color(0xFF2EE6A8);
  static const _dark = Color(0xFF0C8A73);

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 100;
    c.save();
    c.scale(u);
    // Üst taç + alt sivri: klasik kesim
    const tl = Offset(24, 30), tr = Offset(76, 30), l = Offset(8, 44), r = Offset(92, 44), b = Offset(50, 92);
    const t1 = Offset(36, 14), t2 = Offset(64, 14);
    final outer = Path()..addPolygon([l, t1, t2, r, b], true);
    c.drawPath(outer.shift(const Offset(0, 3)), Paint()..color = const Color(0x55000000));
    final yuzler = <(List<Offset>, Color)>[
      ([l, t1, tl], _light),
      ([t1, t2, tr, tl], Color.lerp(_light, Colors.white, 0.5)!),
      ([t2, r, tr], _base),
      ([l, tl, const Offset(50, 44), b], _base),
      ([tl, tr, const Offset(50, 44)], _light),
      ([tr, r, b, const Offset(50, 44)], _dark),
    ];
    for (final (pts, col) in yuzler) {
      c.drawPath(Path()..addPolygon(pts, true), Paint()..color = col);
    }
    final ince = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x66FFFFFF);
    c.drawLine(l, r, ince);
    c.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..color = V21Colors.ink,
    );
    c.drawCircle(const Offset(36, 26), 4, Paint()..color = Colors.white);
    c.restore();
  }

  @override
  bool shouldRepaint(_GemPainter oldDelegate) => false;
}
