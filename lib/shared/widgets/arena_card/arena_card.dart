import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/feedback/game_feedback.dart';
import '../avatar2d/avatar_painter.dart';
import '../avatar2d/avatar_spec.dart';
import 'rarity_style.dart';

/// 2D ARENA KARTI — yeni görsel yönün kart bileşeni.
///
/// ===================================================================
/// YUVA (SLOT) DÜZENİ — her boyutta aynı
/// ===================================================================
///   ┌──────────────────────┐
///   │ 83          ◆        │  Güç (büyük) + nadirlik taşı
///   │ FV                   │  Mevki etiketi (vurgu zeminli)
///   │      (portre)        │  2D stilize karakter (göğüs portresi)
///   │                      │
///   │──────────────────────│  Vurgu çizgisi
///   │   KAELEN BRISVOY     │  Ad (sığmazsa küçülür, kesilmez)
///   │     Hızlı Kanat      │  Alt satır (oyun tarzı / kulüp)
///   └──────────────────────┘
///
/// Boyut sınıfları (genişliğe göre):
///   * küçük  (< 130 px): el / koleksiyon ızgarası. Alt satır ve
///     nadirlik yazısı gizlenir; güç, mevki, yüz, ad kalır.
///   * normal (130-219 px): kadro, paket.
///   * vitrin (>= 220 px): detay, açılış. Alt satır büyür.
///
/// Portre yoksa ([spec] null) gri siluet + "PORTRE YOK" görünür:
/// eksik görsel tamamlanmış gibi gösterilmez.
///
/// Mevcut [PremiumPlayerCard] DEĞİŞMEDİ; maç ve koleksiyon onu
/// kullanmaya devam ediyor. Geçiş planı: docs/GORSEL_YON_2D.md.
class ArenaCard extends StatefulWidget {
  final AvatarSpec? spec;
  final String name;
  final CardPosition position;
  final CardTier tier;
  final int power;

  /// Adın altındaki satır (oyun tarzı veya kulüp). Null ise nadirlik adı.
  final String? subtitle;

  final double width;

  /// Efekt animasyonları (parlama, dönen çerçeve). Listelerde kapalı
  /// tutulmalı; ayarlardan "Kart animasyonları" kapalıysa zaten durur.
  final bool animate;

  /// Yüz ifadesi (arena sonrası sevinç vb.). Null ise karakterin kendi ifadesi.
  final MouthStyle? mouth;

  final VoidCallback? onTap;

  const ArenaCard({
    super.key,
    required this.spec,
    required this.name,
    required this.position,
    required this.tier,
    required this.power,
    this.subtitle,
    this.width = 180,
    this.animate = true,
    this.mouth,
    this.onTap,
  });

  /// FIFA kartlarına yakın oran; mevcut ızgaralarla uyumlu
  static const double aspectRatio = 0.70;

  double get height => width / aspectRatio;

  @override
  State<ArenaCard> createState() => _ArenaCardState();
}

class _ArenaCardState extends State<ArenaCard> with SingleTickerProviderStateMixin {
  AnimationController? _efekt;

  RarityStyle get _stil => RarityStyle.of(widget.tier);

  bool get _hareketli =>
      widget.animate &&
      GameFeedback.cardAnimationsEnabled &&
      _stil.effect.index >= RarityEffect.shine.index;

  Duration get _periyot => switch (_stil.effect) {
        RarityEffect.holo => const Duration(seconds: 6),
        RarityEffect.prism => const Duration(milliseconds: 3400),
        _ => const Duration(milliseconds: 4600),
      };

  @override
  void initState() {
    super.initState();
    _ayarla();
  }

  @override
  void didUpdateWidget(ArenaCard old) {
    super.didUpdateWidget(old);
    if (old.tier != widget.tier || old.animate != widget.animate) _ayarla();
  }

  void _ayarla() {
    if (_hareketli) {
      _efekt ??= AnimationController(vsync: this);
      _efekt!
        ..duration = _periyot
        ..repeat();
    } else {
      _efekt?.dispose();
      _efekt = null;
    }
  }

  @override
  void dispose() {
    _efekt?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    final s = _stil;
    final kucuk = w < 130;
    final vitrin = w >= 220;
    final r = w * 0.075;

    final ic = Stack(
      fit: StackFit.expand,
      children: [
        // ---- Zemin ----
        CustomPaint(painter: _ZeminRessami(s, r)),

        // ---- Portre ----
        Positioned(
          left: w * 0.04,
          right: w * 0.04,
          top: h * 0.10,
          bottom: h * 0.235,
          child: widget.spec == null
              ? _PortreYok(width: w, style: s)
              : FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  child: AvatarPortrait(spec: widget.spec!, size: 200, mouth: widget.mouth),
                ),
        ),

        // ---- İsim plakası ----
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: h * (kucuk ? 0.24 : 0.27),
          child: _IsimPlakasi(
            name: widget.name,
            subtitle: kucuk ? null : (widget.subtitle ?? s.label),
            style: s,
            width: w,
            showcase: vitrin,
          ),
        ),

        // ---- Güç + mevki ----
        Positioned(
          left: w * 0.075,
          top: w * 0.05,
          child: _GucBlogu(power: widget.power, position: widget.position, style: s, width: w),
        ),

        // ---- Nadirlik taşı ----
        Positioned(
          right: w * 0.075,
          top: w * 0.085,
          child: _NadirlikTasi(style: s, width: w, showLabel: !kucuk),
        ),

        // ---- Çerçeve ve efektler (en üstte) ----
        IgnorePointer(
          child: _efekt == null
              ? CustomPaint(painter: _CerceveRessami(s, r, 0, false))
              : AnimatedBuilder(
                  animation: _efekt!,
                  builder: (_, _) => CustomPaint(painter: _CerceveRessami(s, r, _efekt!.value, true)),
                ),
        ),
      ],
    );

    Widget kart = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: w * 0.06, offset: Offset(0, w * 0.03)),
          if (s.glow > 0)
            BoxShadow(color: s.accent.withValues(alpha: 0.45), blurRadius: w * s.glow * 1.6, spreadRadius: w * s.glow * 0.1),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(r), child: ic),
    );

    if (widget.onTap != null) kart = GestureDetector(onTap: widget.onTap, child: kart);
    return Semantics(
      label: '${widget.name}, ${widget.position.label}, ${s.label.toLowerCase()}, güç ${widget.power}',
      child: RepaintBoundary(child: kart),
    );
  }
}

// =====================================================================
// SLOTLAR
// =====================================================================
class _GucBlogu extends StatelessWidget {
  final int power;
  final CardPosition position;
  final RarityStyle style;
  final double width;

  const _GucBlogu({required this.power, required this.position, required this.style, required this.width});

  @override
  Widget build(BuildContext context) {
    final w = width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$power',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: w * 0.25,
            height: 0.95,
            fontWeight: FontWeight.w900,
            color: style.accentLight,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: w * 0.03, offset: Offset(0, w * 0.008))],
          ),
        ),
        SizedBox(height: w * 0.008),
        Container(
          padding: EdgeInsets.symmetric(horizontal: w * 0.035, vertical: w * 0.006),
          decoration: BoxDecoration(
            color: style.accent,
            borderRadius: BorderRadius.circular(w * 0.025),
          ),
          child: Text(
            position.shortLabel,
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: w * 0.075,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: w * 0.004,
              color: RarityStyle.onAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _NadirlikTasi extends StatelessWidget {
  final RarityStyle style;
  final double width;
  final bool showLabel;

  const _NadirlikTasi({required this.style, required this.width, required this.showLabel});

  @override
  Widget build(BuildContext context) {
    final w = width;
    // Taşın köşe sayısı nadirlikle artar: renk körlüğünde de ayırt edilir
    final kenar = 3 + style.tier.index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: Size.square(w * 0.10), painter: _TasRessami(style, kenar)),
        if (showLabel) ...[
          SizedBox(height: w * 0.012),
          Text(
            style.label,
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: w * 0.048,
              fontWeight: FontWeight.w800,
              letterSpacing: w * 0.004,
              color: style.accent.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}

class _IsimPlakasi extends StatelessWidget {
  final String name;
  final String? subtitle;
  final RarityStyle style;
  final double width;
  final bool showcase;

  const _IsimPlakasi({
    required this.name,
    required this.subtitle,
    required this.style,
    required this.width,
    required this.showcase,
  });

  @override
  Widget build(BuildContext context) {
    final w = width;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            RarityStyle.backgroundBottom.withValues(alpha: 0.88),
            RarityStyle.backgroundBottom,
          ],
        ),
      ),
      child: Column(
        children: [
          // Vurgu çizgisi: ortada parlak, kenarlarda sönük
          Container(
            height: math.max(1.5, w * 0.01),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                style.accent.withValues(alpha: 0),
                style.accent,
                style.accent.withValues(alpha: 0),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.07),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: w * 0.11,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: w * 0.003,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: w * (showcase ? 0.058 : 0.062),
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                          color: style.accent.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortreYok extends StatelessWidget {
  final double width;
  final RarityStyle style;
  const _PortreYok({required this.width, required this.style});

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.person, size: width * 0.6, color: Colors.white.withValues(alpha: 0.12)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: width * 0.012),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(width * 0.03),
            ),
            child: Text(
              'PORTRE YOK',
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: width * 0.055,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: style.accentLight,
              ),
            ),
          ),
        ],
      );
}

// =====================================================================
// RESSAMLAR
// =====================================================================
class _ZeminRessami extends CustomPainter {
  final RarityStyle s;
  final double r;
  const _ZeminRessami(this.s, this.r);

  @override
  void paint(Canvas c, Size size) {
    final rect = Offset.zero & size;
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [s.backgroundTop, RarityStyle.backgroundBottom],
        ).createShader(rect),
    );
    // Portrenin arkasında yumuşak vurgu ışığı
    c.drawCircle(
      Offset(size.width / 2, size.height * 0.42),
      size.width * 0.55,
      Paint()
        ..shader = RadialGradient(colors: [
          s.accent.withValues(alpha: 0.26),
          s.accent.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.42), radius: size.width * 0.55)),
    );

    // Elmas: kesik yüzey çizgileri. Efsane: ince çapraz desen.
    if (s.effect == RarityEffect.prism || s.effect == RarityEffect.holo) {
      final p = Paint()
        ..color = s.accent.withValues(alpha: 0.10)
        ..strokeWidth = math.max(1, size.width * 0.004);
      final adim = size.width * (s.effect == RarityEffect.prism ? 0.22 : 0.12);
      for (var x = -size.height; x < size.width + size.height; x += adim) {
        c.drawLine(Offset(x, 0), Offset(x + size.height * 0.6, size.height), p);
        if (s.effect == RarityEffect.prism) {
          c.drawLine(Offset(x + size.height * 0.6, 0), Offset(x, size.height), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ZeminRessami old) => old.s != s;
}

class _CerceveRessami extends CustomPainter {
  final RarityStyle s;
  final double r;

  /// Efekt zamanı (0..1, döngüsel)
  final double t;
  final bool animated;

  const _CerceveRessami(this.s, this.r, this.t, this.animated);

  @override
  void paint(Canvas c, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;

    // ---- Gümüş ve üstü: üst parlaklık ----
    if (s.effect != RarityEffect.none) {
      c.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: const Alignment(0.2, 0.1),
            colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }

    // ---- Altın / elmas / efsane: geçen parlama şeridi ----
    if (animated && s.effect.index >= RarityEffect.shine.index) {
      // Şerit periyodun ilk %35'inde geçer, kalanında bekler
      final ilerleme = (t / 0.35).clamp(0.0, 1.0);
      if (ilerleme > 0 && ilerleme < 1) {
        final x = -w * 0.6 + (w * 2.2) * ilerleme;
        final serit = Rect.fromLTWH(x - w * 0.25, 0, w * 0.5, size.height);
        c.save();
        c.translate(x, size.height / 2);
        c.rotate(0.35);
        c.translate(-x, -size.height / 2);
        c.drawRect(
          serit.inflate(size.height * 0.3),
          Paint()
            ..shader = LinearGradient(colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: s.effect == RarityEffect.holo ? 0.20 : 0.15),
              Colors.white.withValues(alpha: 0),
            ]).createShader(serit),
        );
        c.restore();
      }
    }

    // ---- Efsane: renk kayan zemin örtüsü ----
    if (s.effect == RarityEffect.holo) {
      c.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment(-1 + 2 * t, -1),
            end: Alignment(1 + 2 * t, 1),
            colors: const [Color(0x00FF6BD6), Color(0x14FF6BD6), Color(0x144CC9F0), Color(0x00FFC72C)],
            tileMode: TileMode.mirror,
          ).createShader(rect),
      );
    }

    // ---- Çerçeve ----
    final kalinlik = math.max(2.0, w * 0.024);
    final dis = RRect.fromRectAndRadius(rect.deflate(kalinlik / 2), Radius.circular(r - kalinlik / 2));
    final Shader cerceveBoyasi = s.effect == RarityEffect.holo
        ? SweepGradient(
            colors: s.frame,
            transform: GradientRotation(t * 2 * math.pi),
          ).createShader(rect)
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: s.frame,
          ).createShader(rect);
    c.drawRRect(
      dis,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kalinlik
        ..shader = cerceveBoyasi,
    );
    // İç ince çizgi
    final icCizgi = RRect.fromRectAndRadius(
        rect.deflate(kalinlik * 1.9), Radius.circular(math.max(0, r - kalinlik * 1.9)));
    c.drawRRect(
      icCizgi,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.005)
        ..color = s.accent.withValues(alpha: 0.30),
    );
  }

  @override
  bool shouldRepaint(_CerceveRessami old) => old.t != t || old.s != s || old.animated != animated;
}

/// Nadirlik taşı: köşe sayısı nadirlikle artar (3 → 7)
class _TasRessami extends CustomPainter {
  final RarityStyle s;
  final int kenar;
  const _TasRessami(this.s, this.kenar);

  @override
  void paint(Canvas c, Size size) {
    final m = size.center(Offset.zero);
    final r = size.width / 2;
    final p = Path();
    for (var i = 0; i < kenar; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / kenar;
      final o = m + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    p.close();
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: s.frame,
        ).createShader(Offset.zero & size),
    );
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, size.width * 0.08)
        ..color = Colors.black.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_TasRessami old) => old.s != s || old.kenar != kenar;
}
