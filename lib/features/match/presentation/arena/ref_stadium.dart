import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/cosmetics/cosmetic_art.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';

/// Referans `.arena-stage` paneli: skor başlığı + stadyum.
///
/// .arena-stage { border:1px solid #476b81; border-radius:16px; padding:9px;
///   background:linear-gradient(150deg,#1a3d49,#08182b); box-shadow:inset 0 0 40px #0005 }
class RefArenaStage extends StatelessWidget {
  final Widget? head;
  final Widget stadium;

  const RefArenaStage({super.key, this.head, required this.stadium});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF476B81)),
      gradient: const LinearGradient(
        begin: Alignment(-0.5, -0.87),
        end: Alignment(0.5, 0.87),
        colors: [Color(0xFF1A3D49), Color(0xFF08182B)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (head != null) ...[
          Padding(padding: const EdgeInsets.fromLTRB(2, 3, 2, 8), child: head),
        ],
        stadium,
      ],
    ),
  );
}

/// .arena-head: "🔵 SEN / ad"  ·  .score "0 – 0"  ·  "RAKİP 🔴 / ad"
class RefArenaHead extends StatelessWidget {
  final String myName;
  final String opponentName;
  final int myScore;
  final int opponentScore;

  const RefArenaHead({
    super.key,
    required this.myName,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
  });

  @override
  Widget build(BuildContext context) {
    Widget taraf(String baslik, String ad, Color nokta, bool sag) => Expanded(
      child: Column(
        crossAxisAlignment: sag
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!sag) ...[_Nokta(nokta), const SizedBox(width: 4)],
              Text(baslik, style: Ref.bodyText(11, weight: FontWeight.w900)),
              if (sag) ...[const SizedBox(width: 4), _Nokta(nokta)],
            ],
          ),
          Text(
            ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ref.bodyText(10, color: Ref.muted, weight: FontWeight.w900),
          ),
        ],
      ),
    );

    return Row(
      children: [
        taraf('SEN', myName, Ref.blue, false),
        // .score { font:Barlow 28px; background:#070e1f; padding:0 15px;
        //   border:1px solid #55708a; border-radius:7px; line-height:1.15 }
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF070E1F),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF55708A)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            // Skor değişince "pop" (galibiyet vurgusu 500-800 ms)
            transitionBuilder: (c, a) => ScaleTransition(
              scale: Tween(
                begin: 1.6,
                end: 1.0,
              ).animate(CurvedAnimation(parent: a, curve: Ref.popCurve)),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: Text(
              '$myScore – $opponentScore',
              key: ValueKey('$myScore-$opponentScore'),
              style: Ref.heading(28, weight: FontWeight.w800, height: 1.15),
              semanticsLabel: 'Skor: sen $myScore, rakip $opponentScore',
            ),
          ),
        ),
        taraf('RAKİP', opponentName, Ref.red, true),
      ],
    );
  }
}

class _Nokta extends StatelessWidget {
  final Color c;
  const _Nokta(this.c);

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: c,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
    ),
  );
}

/// Referans `.stadium`: perspektifli saha, projektörler, oyuncu noktaları,
/// sallanan top ve alt yazı.
///
/// .stadium { height:230px; perspective:430px;
///   background:radial-gradient(ellipse at center,#225968 0%,#0d2337 45%,#030a13 95%) }
/// .pitch3d { top:17px; left:16%; width:68%; height:185px;
///   transform:rotateX(43deg) rotateZ(-8deg) }
/// .football { animation: bob 1.7s alternate } / .flash .football { shot .65s }
///
/// [flashKey] değişince şut animasyonu oynar ve saha parlar (tur sonucu).
class RefStadium extends StatefulWidget {
  final String caption;
  final double height;
  final Object? flashKey;

  /// Ekonomi V2 (FAZ 6): arena kozmetiği (ör. arena_rainy_night). Yalnız
  /// oyuncunun KENDİ ekranında; rakip kendi seçtiğini görür.
  final String? skin;

  const RefStadium({
    super.key,
    required this.caption,
    this.height = 230,
    this.flashKey,
    this.skin,
  });

  @override
  State<RefStadium> createState() => _RefStadiumState();
}

class _RefStadiumState extends State<RefStadium> with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _sut;

  bool get _hareket => GameFeedback.cardAnimationsEnabled;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _sut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (_hareket) _bob.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RefStadium old) {
    super.didUpdateWidget(old);
    if (old.flashKey != widget.flashKey &&
        widget.flashKey != null &&
        _hareket) {
      _sut.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    _sut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sahne = _sahne(context);
    if (widget.skin != 'arena_rainy_night') return sahne;
    return Stack(children: [
      sahne,
      Positioned.fill(
        child: ClipRRect(borderRadius: BorderRadius.circular(9), child: const RainyNightOverlay()),
      ),
    ]);
  }

  Widget _sahne(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, k) {
            final w = k.maxWidth;
            final h = widget.height;
            // PERFORMANS (FAZ 9 ölçümü: maç hazırlığı ~43 FPS): eskiden
            // her karede BÜTÜN stadyum (perspektifli saha, renk filtresi,
            // bulanık projektörler, gölgeli yazı) yeniden kuruluyordu;
            // oysa sürekli hareket eden yalnız top. Artık:
            //   * durağan katman bir kez çizilir (RepaintBoundary)
            //   * saha parlaklığı yalnız şut anında (_sut) değişir ve renk
            //     filtresi yalnız o an açılır (her karede ek katman yok)
            //   * her karede yalnız top çizilir
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: _StadyumZemini()),
                        ),
                        // Projektörler (.flood)
                        const Positioned(left: 15, top: 4, child: _Projektor()),
                        const Positioned(
                          right: 15,
                          top: 4,
                          child: _Projektor(),
                        ),
                        // Perspektifli saha
                        Positioned(
                          left: w * 0.16,
                          top: 17,
                          width: w * 0.68,
                          height: 185,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 1 / 430)
                              ..rotateX(
                                -43 * math.pi / 180,
                              ) // Flutter: işaret CSS'in tersi (uzak kenar daralsın)
                              ..rotateZ(-8 * math.pi / 180),
                            child: AnimatedBuilder(
                              animation: _sut,
                              child: const _Saha3d(),
                              builder: (context, saha) {
                                final parlak = _sut.isAnimating
                                    ? 1 - (_sut.value - 0.5).abs() * 2
                                    : 0.0;
                                if (parlak <= 0) return saha!;
                                return ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                    _parlaklik(1 + 0.35 * parlak),
                                  ),
                                  child: saha,
                                );
                              },
                            ),
                          ),
                        ),
                        // Oyuncu noktaları (.player-dot)
                        for (final (sol, sag, ust, no, kirmizi) in const [
                          (0.32, null, 0.39, '7', false),
                          (0.37, null, 0.65, '9', false),
                          (0.28, null, 0.80, '3', false),
                          (null, 0.32, 0.38, '4', true),
                          (null, 0.37, 0.67, '8', true),
                          (null, 0.27, 0.79, '6', true),
                        ])
                          Positioned(
                            left: sol == null ? null : w * sol,
                            right: sag == null ? null : w * sag,
                            top: h * ust,
                            child: _OyuncuNoktasi(no, kirmizi: kirmizi),
                          ),
                        // .turf-caption { bottom:8px; font:900 17px Barlow; text-shadow:0 2px 6px #000 }
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Text(
                            widget.caption,
                            textAlign: TextAlign.center,
                            style: Ref.heading(17, weight: FontWeight.w900)
                                .copyWith(
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Top (.football top:51% left:49%; bob ±13px/±4px) — her karede
                // yalnız bu katman çizilir
                Positioned(
                  left: w * 0.49,
                  top: h * 0.51,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_bob, _sut]),
                      child: const RefDropShadow(
                        color: Color(0xFF000000),
                        offset: Offset(0, 4),
                        blur: 5,
                        child: Em('⚽', size: 24, height: 1),
                      ),
                      builder: (context, top) => Transform.translate(
                        offset: _topKonumu(),
                        child: Transform.scale(
                          scale: _sut.isAnimating
                              ? 1 - 0.5 * Curves.easeOut.transform(_sut.value)
                              : 1,
                          child: top,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Offset _topKonumu() {
    if (_sut.isAnimating) {
      // @keyframes shot: 0 → (70,-19) @55% → (110,-35)
      final t = Curves.easeOut.transform(_sut.value);
      return t < 0.55
          ? Offset.lerp(Offset.zero, const Offset(70, -19), t / 0.55)!
          : Offset.lerp(
              const Offset(70, -19),
              const Offset(110, -35),
              (t - 0.55) / 0.45,
            )!;
    }
    // @keyframes bob: translate(-13px,-4px) → translate(13px,4px), ease-in-out
    final t = Curves.easeInOut.transform(_bob.value);
    return Offset(-13 + 26 * t, -4 + 8 * t);
  }

  static List<double> _parlaklik(double b) => [
    b, 0, 0, 0, 0, //
    0, b, 0, 0, 0, //
    0, 0, b, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

class _StadyumZemini extends CustomPainter {
  const _StadyumZemini();

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    // radial-gradient(ellipse at center, #225968 0%, #0d2337 45%, #030a13 95%)
    c.save();
    c.translate(s.width / 2, s.height / 2);
    c.scale(s.width / s.height, 1);
    final yr = s.height / 2 * math.sqrt2;
    c.drawCircle(
      Offset.zero,
      yr * 1.05,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF225968), Color(0xFF0D2337), Color(0xFF030A13)],
          stops: [0, 0.45, 0.95],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: yr)),
    );
    c.restore();
    // :before — radial-gradient(ellipse at 50% 8%, #eafaff3d, transparent 28%)
    final ust = Offset(s.width / 2, s.height * 0.08);
    c.drawOval(
      Rect.fromCenter(
        center: ust,
        width: s.width * 0.9,
        height: s.height * 0.6,
      ),
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0x3DEAFAFF), Color(0x00EAFAFF)],
              stops: [0, 0.6],
            ).createShader(
              Rect.fromCenter(
                center: ust,
                width: s.width * 0.9,
                height: s.height * 0.6,
              ),
            ),
    );
    // repeating-linear-gradient(90deg, transparent 0 19px, #ffffff05 20px 21px)
    final cizgi = Paint()..color = const Color(0x05FFFFFF);
    for (var x = 20.0; x < s.width; x += 21) {
      c.drawRect(Rect.fromLTWH(x, 0, 1, s.height), cizgi);
    }
    c.drawRect(r, Paint()..color = Colors.transparent);
  }

  @override
  bool shouldRepaint(_StadyumZemini old) => false;
}

/// .flood { width:90px; height:3px; background:#fff;
///   box-shadow:0 0 9px 5px #c5f8ff, 0 0 55px 12px #6aebff80 }
class _Projektor extends StatelessWidget {
  const _Projektor();

  // BoxShadow'un büyük yayılımı burada sert kutu olarak çiziliyordu;
  // aynı ışık elle çizilir: geniş hale + bulanık parlaklık + beyaz çekirdek.
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 90,
    height: 3,
    child: CustomPaint(painter: _ProjektorCizim()),
  );
}

class _ProjektorCizim extends CustomPainter {
  const _ProjektorCizim();

  @override
  void paint(Canvas c, Size s) {
    final m = s.center(Offset.zero);
    // 0 0 55px 12px #6aebff80 — geniş, yumuşak hale
    final hale = Rect.fromCenter(center: m, width: s.width + 110, height: 70);
    c.drawOval(
      hale,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x806AEBFF), Color(0x006AEBFF)],
        ).createShader(hale),
    );
    // 0 0 9px 5px #c5f8ff — çekirdeğin çevresindeki parlaklık
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: m, width: s.width + 10, height: 13),
        const Radius.circular(6),
      ),
      Paint()
        ..color = const Color(0xCCC5F8FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
    );
    // background:#fff
    c.drawRect(Offset.zero & s, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ProjektorCizim old) => false;
}

/// .pitch3d { background:repeating-linear-gradient(0deg,#176348 0 23px,#1d704f 23px 46px);
///   border:2px solid #c4ffdf80; box-shadow:0 16px 38px #000a, 0 0 28px #18ba83aa }
class _Saha3d extends StatelessWidget {
  const _Saha3d();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0x80C4FFDF), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0xAA000000),
          blurRadius: 38,
          offset: Offset(0, 16),
        ),
        BoxShadow(color: Color(0xAA18BA83), blurRadius: 28),
      ],
    ),
    child: const CustomPaint(painter: _Saha3dCizim()),
  );
}

class _Saha3dCizim extends CustomPainter {
  const _Saha3dCizim();

  @override
  void paint(Canvas c, Size s) {
    final a = Paint()..color = const Color(0xFF176348);
    final b = Paint()..color = const Color(0xFF1D704F);
    var i = 0;
    for (var y = s.height; y > -23; y -= 23) {
      c.drawRect(Rect.fromLTRB(0, y - 23, s.width, y), i.isEven ? a : b);
      i++;
    }
    final cizgi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x9CD7FFE1);
    // :before orta çizgi, :after 50px orta yuvarlak
    c.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), cizgi);
    c.drawCircle(s.center(Offset.zero), 25, cizgi);
    // .pitch-box 58x95, top:44px; sol kutunun solu, sağ kutunun sağı açık
    c.drawPath(
      Path()
        ..moveTo(0, 44)
        ..lineTo(58, 44)
        ..lineTo(58, 139)
        ..lineTo(0, 139),
      cizgi,
    );
    c.drawPath(
      Path()
        ..moveTo(s.width, 44)
        ..lineTo(s.width - 58, 44)
        ..lineTo(s.width - 58, 139)
        ..lineTo(s.width, 139),
      cizgi,
    );
  }

  @override
  bool shouldRepaint(_Saha3dCizim old) => false;
}

/// .player-dot { 23x23; border:2px solid #d3f0ff; border-radius:50%;
///   background:linear-gradient(145deg,#6ed0ff,#0872d4); box-shadow:0 4px 10px #0008;
///   font-size:10px; font-weight:900 } .redside { #ff999f → #bd173b; border #ffe1e1 }
class _OyuncuNoktasi extends StatelessWidget {
  final String no;
  final bool kirmizi;
  const _OyuncuNoktasi(this.no, {required this.kirmizi});

  @override
  Widget build(BuildContext context) => Container(
    width: 23,
    height: 23,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: kirmizi ? const Color(0xFFFFE1E1) : const Color(0xFFD3F0FF),
        width: 2,
      ),
      gradient: LinearGradient(
        begin: const Alignment(-0.57, -0.82),
        end: const Alignment(0.57, 0.82),
        colors: kirmizi
            ? const [Color(0xFFFF999F), Color(0xFFBD173B)]
            : const [Color(0xFF6ED0FF), Color(0xFF0872D4)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x88000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Text(
      no,
      style: Ref.bodyText(10, weight: FontWeight.w900, height: 1),
    ),
  );
}
