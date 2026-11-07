import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/ref_tokens.dart';
import '../avatar2d/avatar_painter.dart';
import '../avatar2d/avatar_spec.dart';
import '../ref/ref_glyphs.dart';

/// Referans nadirlik renkleri: .rarity-* { --rarity; --halo }
class RefRarity {
  final Color color;
  final Color halo;
  final String name;
  const RefRarity(this.color, this.halo, this.name);

  static RefRarity of(CardTier t) => switch (t) {
        CardTier.bronze => const RefRarity(Color(0xFFBF8766), Color(0x77704026), 'Bronz'),
        CardTier.silver => const RefRarity(Color(0xFFB8CEDB), Color(0x558AA0C6), 'Gümüş'),
        CardTier.gold => const RefRarity(Color(0xFFF3CE70), Color(0x65B58A2A), 'Altın'),
        CardTier.diamond => const RefRarity(Color(0xFF72DFFF), Color(0x850D9BC6), 'Elmas'),
        CardTier.legend => const RefRarity(Color(0xFFD18AFF), Color(0x958C37CB), 'Efsane'),
      };
}

/// Kartın iki ölçüsü — ikisi de referansta var.
enum RefCardLayout {
  /// .collectible (koleksiyon ızgarası): 390px telefonda 176.5 x 188
  grid(176.5, 188),

  /// .revealcard (detay ve paket açılışı): 205 x 295
  reveal(205, 295);

  final double baseWidth;
  final double baseHeight;
  const RefCardLayout(this.baseWidth, this.baseHeight);

  double get aspectRatio => baseWidth / baseHeight;
}

/// ORTAK OYUNCU KARTI — referans `.collectible`.
///
/// Uygulamadaki BÜTÜN kartlar bu bileşenden çizilir (koleksiyon, detay,
/// kadro, maç eli, paket). [PremiumPlayerCard] artık bunun ince bir
/// sarmalayıcısıdır.
///
/// YAPI (referans HTML):
///   üstte güç (Barlow 900 31px) + mevki (Nunito 900 11px)
///   ortada 2D karakter yüzü (referanstaki emoji yerine; karaktere özel)
///   altta ad (Barlow 800 18px) + "✦ NADİRLİK ✦" (9px, nadirlik rengi)
/// Zemin: radial-gradient(circle at 55% 36%, halo, transparent 65%) +
/// linear-gradient(150deg,#182a42,#0d1326 84%); 2px nadirlik çerçevesi.
///
/// Bütün ölçüler [width] / taban genişlik oranında ölçeklenir.
class RefPlayerCard extends StatefulWidget {
  final String name;
  final CardPosition position;
  final CardTier tier;
  final int power;

  /// Karakter tanımı. Null ise [seed]'den deterministik üretilir.
  final AvatarSpec? spec;

  /// Yüz üretimi için kalıcı kimlik (kartın `cardId`'si)
  final String seed;

  /// Forma rengi için (kulüp adı)
  final String? kitSeed;

  /// Onaylı görsel (http/https). Varsa yüz yerine o gösterilir.
  final String? imageUrl;

  final double width;
  final RefCardLayout layout;

  final bool isFavorite;
  final bool isProtected;
  final bool isLocked;
  final bool isPlayed;
  final bool isSelected;

  /// Hareketli nadirlik efektleri (Efsane ışığı, Altın/Elmas parıltısı)
  final bool animate;
  final VoidCallback? onTap;

  const RefPlayerCard({
    super.key,
    required this.name,
    required this.position,
    required this.tier,
    required this.power,
    required this.seed,
    this.spec,
    this.kitSeed,
    this.imageUrl,
    this.width = 176.5,
    this.layout = RefCardLayout.grid,
    this.isFavorite = false,
    this.isProtected = false,
    this.isLocked = false,
    this.isPlayed = false,
    this.isSelected = false,
    this.animate = false,
    this.onTap,
  });

  double get height => width / layout.aspectRatio;

  /// Kartın çizdiği yüz
  AvatarSpec get resolvedSpec => spec ?? AvatarSpec.generate(seed, kitSeed: kitSeed);

  @override
  State<RefPlayerCard> createState() => _RefPlayerCardState();
}

class _RefPlayerCardState extends State<RefPlayerCard> with SingleTickerProviderStateMixin {
  AnimationController? _isik;
  bool _uzerinde = false;
  bool _basili = false;

  bool get _hareketli =>
      widget.animate && GameFeedback.cardAnimationsEnabled && widget.tier.index >= CardTier.gold.index;

  @override
  void initState() {
    super.initState();
    _kur();
  }

  @override
  void didUpdateWidget(RefPlayerCard old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate || old.tier != widget.tier) _kur();
  }

  void _kur() {
    if (_hareketli) {
      _isik ??= AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.tier == CardTier.legend ? 4200 : 5200),
      )..repeat();
    } else {
      _isik?.dispose();
      _isik = null;
    }
  }

  @override
  void dispose() {
    _isik?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    final k = w / widget.layout.baseWidth;
    final r = RefRarity.of(widget.tier);
    final reveal = widget.layout == RefCardLayout.reveal;
    final yaricap = 14 * k;
    final cerceve = math.max(1.5, 2 * k);

    final Widget icerik = Padding(
      padding: EdgeInsets.all(9 * k),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- güç + mevki ----
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.power}',
                  textScaler: TextScaler.noScaling,
                  style: Ref.heading(31 * k, weight: FontWeight.w900, height: 0.8).copyWith(letterSpacing: 0)),
              SizedBox(height: 4 * k),
              Text(widget.position.code,
                  textScaler: TextScaler.noScaling,
                  style: reveal
                      ? Ref.bodyText(14 * k, color: Ref.text, height: 1.2)
                      : Ref.bodyText(11 * k, weight: FontWeight.w900, height: 1.25)),
            ],
          ),
          // ---- karakter ----
          Expanded(child: Center(child: _portre(k, reveal))),
          // ---- ad + nadirlik ----
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(widget.name,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.center,
                    style: Ref.heading((reveal ? 25 : 18) * k, height: 1).copyWith(letterSpacing: 0)),
              ),
              SizedBox(height: 2 * k),
              _NadirlikSatiri(rarity: r, k: k, sparkles: !reveal),
            ],
          ),
        ],
      ),
    );

    // Rozetler
    final rozetler = <Widget>[
      if (widget.isProtected)
        _Rozet(k: k, renk: const Color(0xFF29CC7A), ikon: Icons.shield, ipucu: 'Bu kart korumada.')
      else if (widget.isFavorite)
        _Rozet(k: k, renk: Ref.red, ikon: Icons.favorite_rounded, ipucu: 'Favori'),
      if (widget.isLocked) _Rozet(k: k, renk: const Color(0xFFF59E0B), ikon: Icons.lock, ipucu: 'Devam eden maçta kilitli.'),
    ];

    Widget kart = SizedBox(
      width: w,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(yaricap),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _ZeminRessami(r, widget.tier, k)),
            icerik,
            if (rozetler.isNotEmpty)
              Positioned(
                top: 7 * k,
                right: 7 * k,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final z in rozetler) Padding(padding: EdgeInsets.only(bottom: 4 * k), child: z),
                ]),
              ),
            if (widget.isPlayed || widget.isLocked)
              const IgnorePointer(child: ColoredBox(color: Color(0x8C000000))),
          ],
        ),
      ),
    );

    // Çerçeve (+ hareketli ışık) en üstte
    kart = Stack(
      clipBehavior: Clip.none,
      children: [
        kart,
        Positioned.fill(
          child: IgnorePointer(
            child: _isik == null
                ? CustomPaint(painter: _CerceveRessami(r, widget.tier, yaricap, cerceve, 0, false))
                : AnimatedBuilder(
                    animation: _isik!,
                    builder: (_, _) =>
                        CustomPaint(painter: _CerceveRessami(r, widget.tier, yaricap, cerceve, _isik!.value, true)),
                  ),
          ),
        ),
      ],
    );

    // box-shadow: inset 0 0 23px #fff1, 0 4px 14px #0008 (+ seçim)
    kart = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(yaricap),
        boxShadow: [
          BoxShadow(color: const Color(0x88000000), blurRadius: 14 * k, offset: Offset(0, 4 * k)),
          if (widget.tier == CardTier.legend)
            BoxShadow(color: r.color.withValues(alpha: 0.25), blurRadius: 16 * k),
          if (widget.isSelected)
            BoxShadow(color: Ref.accent.withValues(alpha: 0.7), blurRadius: 14 * k, spreadRadius: 2 * k),
        ],
      ),
      child: kart,
    );

    if (widget.isSelected) {
      kart = Stack(clipBehavior: Clip.none, children: [
        kart,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(yaricap),
                border: Border.all(color: Ref.accent, width: math.max(2, 3 * k)),
              ),
            ),
          ),
        ),
      ]);
    }

    // .collectible:hover { transform:translateY(-3px); filter:brightness(1.13) }
    // transition .18s
    final yukari = (_uzerinde || _basili) && widget.onTap != null;
    kart = AnimatedContainer(
      duration: Ref.cardHover,
      transform: Matrix4.translationValues(0, yukari ? -3 : 0, 0),
      child: yukari
            ? ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  1.13, 0, 0, 0, 0, //
                  0, 1.13, 0, 0, 0, //
                  0, 0, 1.13, 0, 0, //
                  0, 0, 0, 1, 0,
                ]),
                child: kart,
              )
            : kart,
    );

    if (widget.onTap != null) {
      kart = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _uzerinde = true),
        onExit: (_) => setState(() => _uzerinde = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _basili = true),
          onTapCancel: () => setState(() => _basili = false),
          onTapUp: (_) => setState(() => _basili = false),
          onTap: widget.onTap,
          child: kart,
        ),
      );
    }

    return Semantics(
      label: '${widget.name}, ${widget.position.label}, ${r.name}, güç ${widget.power}'
          '${widget.isFavorite ? ', favori' : ''}${widget.isLocked ? ', kilitli' : ''}',
      button: widget.onTap != null,
      excludeSemantics: true,
      child: RepaintBoundary(child: kart),
    );
  }

  /// .portrait { font-size:61px; line-height:1.2; filter:drop-shadow(0 9px 7px #0009) }
  /// Detayda 100px. Emoji yerine karaktere özel 2D göğüs portresi.
  Widget _portre(double k, bool reveal) {
    // Orta alan: ızgarada ~96px, detayda ~190px (referans emoji 61/100px
    // ama emoji kutuyu tamamen doldurur; yüz aynı ağırlıkta görünsün)
    final boyut = (reveal ? 144.0 : 86.0) * k;
    final url = widget.imageUrl;
    Widget yuz;
    if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
      yuz = CachedNetworkImage(
        imageUrl: url,
        width: boyut,
        height: boyut,
        fit: BoxFit.contain,
        placeholder: (_, _) => AvatarPortrait(spec: widget.resolvedSpec, size: boyut, headshot: true),
        errorWidget: (_, _, _) => AvatarPortrait(spec: widget.resolvedSpec, size: boyut, headshot: true),
      );
    } else {
      // Omuzlar alt kenarda yumuşakça kaybolur: ad satırı temiz zemine otursun
      yuz = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
          stops: [0, 0.8, 1],
        ).createShader(r),
        child: AvatarPortrait(spec: widget.resolvedSpec, size: boyut, headshot: true),
      );
    }
    // drop-shadow: aynı şeklin kararmış, bulanık ve 9px aşağı kaydırılmış
    // kopyası. "Kart animasyonları" kapalıysa (düşük performans ayarı)
    // bulanıklık çizilmez.
    if (!GameFeedback.cardAnimationsEnabled) return SizedBox(width: boyut, height: boyut, child: yuz);
    return SizedBox(
      width: boyut,
      height: boyut,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 9 * k,
            width: boyut,
            height: boyut,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 3.5 * k, sigmaY: 3.5 * k),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0x99000000), BlendMode.srcIn),
                child: yuz,
              ),
            ),
          ),
          yuz,
        ],
      ),
    );
  }
}

/// .rarename { font-size:9px; color:var(--rarity); font-weight:900;
/// text-align:center } — "✦ ALTIN ✦"
class _NadirlikSatiri extends StatelessWidget {
  final RefRarity rarity;
  final double k;
  final bool sparkles;
  const _NadirlikSatiri({required this.rarity, required this.k, required this.sparkles});

  @override
  Widget build(BuildContext context) {
    final yazi = Text(
      sparkles ? rarity.name.toUpperCase() : rarity.name,
      textScaler: TextScaler.noScaling,
      style: Ref.bodyText(9 * k, color: rarity.color, weight: FontWeight.w900, height: 1.3),
    );
    if (!sparkles) return Center(child: yazi);
    final yildiz = RefGlyphIcon(RefGlyph.sparkle, size: 7 * k, color: rarity.color);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [yildiz, SizedBox(width: 3 * k), yazi, SizedBox(width: 3 * k), yildiz],
    );
  }
}

class _Rozet extends StatelessWidget {
  final double k;
  final Color renk;
  final IconData ikon;
  final String ipucu;
  const _Rozet({required this.k, required this.renk, required this.ikon, required this.ipucu});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: ipucu,
        child: Container(
          padding: EdgeInsets.all(4 * k),
          decoration: const BoxDecoration(color: Color(0x8C000000), shape: BoxShape.circle),
          child: Icon(ikon, size: 13 * k, color: renk),
        ),
      );
}

class _ZeminRessami extends CustomPainter {
  final RefRarity r;
  final CardTier tier;
  final double k;
  const _ZeminRessami(this.r, this.tier, this.k);

  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    // linear-gradient(150deg,#182a42,#0d1326 84%)
    c.drawRect(rect, Paint()..shader = Ref.collectibleGradient.createShader(rect));
    // radial-gradient(circle at 55% 36%, var(--halo) 0%, transparent 65%)
    final m = Offset(s.width * 0.55, s.height * 0.36);
    final enUzak = [Offset.zero, Offset(s.width, 0), Offset(0, s.height), Offset(s.width, s.height)]
        .map((p) => (p - m).distance)
        .reduce(math.max);
    final yr = enUzak * 0.65;
    c.drawCircle(
        m,
        yr,
        Paint()
          ..shader = RadialGradient(colors: [r.halo, r.halo.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: m, radius: yr)));

    // Elmas: kristal yüzey çizgileri
    if (tier == CardTier.diamond) {
      final p = Paint()
        ..color = r.color.withValues(alpha: 0.05)
        ..strokeWidth = math.max(0.8, k);
      for (var x = -s.height; x < s.width; x += 34 * k) {
        c.drawLine(Offset(x, 0), Offset(x + s.height * 0.75, s.height), p);
        c.drawLine(Offset(x + s.height * 0.75, 0), Offset(x, s.height), p);
      }
    }
    // Altın: hafif parıltı (sol üst ışık)
    if (tier == CardTier.gold || tier == CardTier.diamond) {
      c.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: const Alignment(0.1, 0.1),
              colors: [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0)],
            ).createShader(rect));
    }

    // box-shadow: inset 0 0 23px #fff1 — iç kenar ışığı
    c.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(14 * k)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 * k
          ..color = const Color(0x11FFFFFF)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * k));
  }

  @override
  bool shouldRepaint(_ZeminRessami old) => old.r != r || old.k != k || old.tier != tier;
}

class _CerceveRessami extends CustomPainter {
  final RefRarity r;
  final CardTier tier;
  final double yaricap;
  final double kalinlik;
  final double t;
  final bool hareketli;

  const _CerceveRessami(this.r, this.tier, this.yaricap, this.kalinlik, this.t, this.hareketli);

  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect.deflate(kalinlik / 2), Radius.circular(yaricap - kalinlik / 2));

    // Altın / Elmas: arada bir geçen ince parıltı şeridi
    if (hareketli && (tier == CardTier.gold || tier == CardTier.diamond)) {
      final ilerleme = (t / 0.3).clamp(0.0, 1.0);
      if (ilerleme > 0 && ilerleme < 1) {
        c.save();
        c.clipRRect(rr);
        final x = -s.width * 0.5 + s.width * 2 * ilerleme;
        final serit = Rect.fromLTWH(x - s.width * 0.18, -s.height * 0.2, s.width * 0.36, s.height * 1.4);
        c.translate(x, s.height / 2);
        c.rotate(0.35);
        c.translate(-x, -s.height / 2);
        c.drawRect(
            serit,
            Paint()
              ..shader = LinearGradient(colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: tier == CardTier.diamond ? 0.16 : 0.12),
                Colors.white.withValues(alpha: 0),
              ]).createShader(serit));
        c.restore();
      }
    }

    final boya = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalinlik;
    if (tier == CardTier.legend) {
      // Efsane: mor-altın çerçeve, kontrollü dönen ışık
      boya.shader = SweepGradient(
        colors: const [Color(0xFFD18AFF), Color(0xFFF8C665), Color(0xFFD18AFF), Color(0xFFA56BFF), Color(0xFFD18AFF)],
        stops: const [0, 0.18, 0.4, 0.7, 1],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(rect);
    } else {
      boya.color = r.color;
    }
    c.drawRRect(rr, boya);
  }

  @override
  bool shouldRepaint(_CerceveRessami old) => old.t != t || old.r != r || old.hareketli != hareketli;
}
